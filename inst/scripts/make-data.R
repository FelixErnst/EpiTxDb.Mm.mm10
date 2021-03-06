# get annotation data
library(AnnotationHub)
library(BSgenome.Mmusculus.UCSC.mm10)
library(EpiTxDb)
library(RSQLite)
library(GenomicRanges)

# get annotation hub
ah <- AnnotationHub()

# get ensembl annotation
edb <- query(ah, c("EnsDb","Mus musculus","99"))[[1]]
seqlevelsStyle(edb) <- "UCSC"
seqlevels <- paste0("chr",c(seq_len(19),"Y","X","M"))

# get transcript annotations from ensemble db
assemble_tx <- function(edb, genome, seqlevels){
  .split_tRNA_by_intron <- function(gr){
    if(length(gr) > 1L){
      stop(".")
    }
    regres <- regmatches(gr$intron,regexec(".*pos ([0-9]+)-([0-9]+):<BR>",gr$intron))
    start <- as.integer(regres[[1L]][2L])
    end <- as.integer(regres[[1L]][3L])
    if(as.logical(strand(gr) == "-")){
      ranges <- IRanges::IRanges(start = c(end(gr)-start+2L,start(gr)),
                                 end = c(end(gr),end(gr)-end))
    } else {
      ranges <- IRanges::IRanges(start = c(start(gr),start(gr)+end),
                                 end = c(start(gr)+start-2L,end(gr)))
    }
    ans <- GenomicRanges::GRanges(seqnames = seqnames(gr),
                                  ranges = ranges,
                                  strand = strand(gr),
                                  mcols(gr))
    mcols(ans) <- mcols(ans)[,colnames(mcols(ans)) != "intron",drop=FALSE]
    ans
  }
  # get exons
  tx <- exonsBy(edb,"tx")
  tx_id <- IRanges::CharacterList(Map(rep,names(tx),lengths(tx)))
  mcols(tx, level="within")[,"tx_id"] <- tx_id
  genome(tx) <- genome
  
  # get tRNA annotation
  FDb.tRNAs <- makeFeatureDbFromUCSC(genome,"tRNAs","tRNAs")
  tRNAs <- features(FDb.tRNAs)
  mcols(tRNAs) <- mcols(tRNAs)[,c("intron"),drop=FALSE]
  mcols(tRNAs)$tx_id <- names(tRNAs)
  names(tRNAs) <- NULL
  tRNAs <- split(tRNAs,mcols(tRNAs)$tx_id)
  # incorporate intron annotations
  has_intron <- !grepl("No.*tRNA introns", mcols(tRNAs,level="within")[,"intron"])
  has_intron <- unlist(unique(has_intron))
  tRNAs[has_intron] <- GenomicRanges::GRangesList(lapply(tRNAs[has_intron],.split_tRNA_by_intron))
  exon_id <- relist(paste(unlist(Map(rep,names(tRNAs),lengths(tRNAs))),
                          unlist(lapply(lengths(tRNAs),seq_len)),
                          sep="_"),
                    PartitioningByEnd(tRNAs))
  mcols(tRNAs, level="within")[,"exon_id"] <- exon_id
  #
  mcols(tx, level="within") <- mcols(tx, level="within")[,c("tx_id","exon_id")]
  mcols(tRNAs, level="within") <- mcols(tRNAs, level="within")[,c("tx_id","exon_id")]
  ans <- c(tx,tRNAs)
  # fix the seqinfo
  ans <- ans[seqnames(ans) %in% seqlevels]
  seqlevels(ans) <- seqlevels
  circ <- isCircular(seqinfo(ans))
  circ[names(circ) == "chrM"] <- TRUE
  isCircular(seqinfo(ans)) <- circ
  #
  ans[lengths(ans) != 0L]
}

tx <- assemble_tx(edb, "mm10", seqlevels)

################################################################################
# functions for import
################################################################################

import.RMBase <- function(bs, organism, genome, type){
  metadata <- data.frame(name = c("Data source","Organism","Genome",
                                  "Coordinates"),
                         value = c("RMBase v2.0","Mus musculus","mm10",
                                   "per Genome"))
  #
  files <- downloadRMBaseFiles(organism, genome, type)
  gr <- getRMBaseDataAsGRanges(files)
  seq <- getSeq(bs, seqlevels(gr))
  seq_rna <- as(seq, "RNAStringSet")
  colnames(mcols(gr)) <- gsub("mod_type","mod",colnames(mcols(gr)))
  # do plus and minus strand separatly, since removeIncompatibleModifications
  # only accepts plus strand
  gr_plus <- 
    Modstrings::removeIncompatibleModifications(gr[strand(gr) == "+"], seq_rna)
  gr_minus <- gr[strand(gr) == "-"]
  strand(gr_minus) <- "+"
  gr_minus <-
    Modstrings::removeIncompatibleModifications(gr_minus, complement(seq_rna))
  strand(gr_minus) <- "-"
  gr <- c(gr_plus,gr_minus)
  gr <- gr[order(seqnames(gr),start(gr),strand(gr))]
  colnames(mcols(gr)) <- gsub("^mod$","mod_type",colnames(mcols(gr)))
  metadata <- EpiTxDb:::.add_sequence_check_to_metadata(metadata)
  #
  mcols(gr)$mod_id <- seq_along(gr)
  makeEpiTxDbFromGRanges(gr, metadata = metadata)
}

import_from_tRNAdb <- function(organism, bs, tx){
  metadata <- data.frame(name = c("Data source","Organism","Genome",
                                  "Coordinates"),
                         value = c("tRNAdb","Mus musculus","mm10",
                                   "per Transcript"))
  #
  seq <- getSeq(bs,tx)
  seq <- relist(unlist(unlist(seq)),
                IRanges::PartitioningByWidth(sum(nchar(seq))))
  seq_rna <- as(seq,"RNAStringSet")
  gr <- gettRNAdbDataAsGRanges(organism, sequences = seq_rna)
  gr <- gr[!duplicated(paste0(as.character(gr),"-",gr$mod_type))]
  # fix an error in the tRNAdb for tRNA Phe at position 27
  # this is the result of a sequence shift for tdbR00000099 entry
  gr <- gr[!any(mcols(gr)$ref == "tdbR00000099")]
  # fix an error in the tRNAdb for tRNA Phe at position 37
  # in the reference at positions 37 a yW is found not an o2yW
  gr <- gr[!any(mcols(gr)$ref == "tdbR00000100") | !start(gr) == 37]
  # fix an error in the tRNAdb for tRNA Phe at position 37
  # xA is the less specific annotation
  gr <- gr[!any(mcols(gr)$ref == "tdbR00000207") | !start(gr) == 37]
  names(gr) <- NULL
  #
  colnames(mcols(gr)) <- gsub("mod_type","mod",colnames(mcols(gr)))
  gr <- Modstrings::removeIncompatibleModifications(gr, seq_rna)
  colnames(mcols(gr)) <- gsub("^mod$","mod_type",colnames(mcols(gr)))
  metadata <- EpiTxDb:::.add_sequence_check_to_metadata(metadata)
  #
  makeEpiTxDbFromGRanges(gr, metadata = metadata)
}

import_from_snoRNAdb <- function(snoRNAdb, orgdb){
  metadata <- data.frame(name = c("Data source","Organism","Genome",
                                  "Coordinates"),
                         value = c("snoRNAdb","Mus musculus","mm10",
                                   "per Transcript"))
  # clean up
  snoRNAdb <- snoRNAdb[!is.na(snoRNAdb$start),]
  # Modifications
  mod_id <- seq_len(nrow(snoRNAdb))
  mod_name <- paste0(snoRNAdb$modification,"_",snoRNAdb$position)
  mod_type <- snoRNAdb$modification
  mod_start <- snoRNAdb$position
  mod_end <- snoRNAdb$position
  
  transcripts <- select(orgdb,as.character(snoRNAdb$key),
                        c("REFSEQ","SYMBOL","ENTREZID"),"SYMBOL")
  
  modifications <- data.frame(mod_id = mod_id,
                              mod_name = mod_name,
                              mod_type = mod_type,
                              mod_start = mod_start,
                              mod_end = mod_end,
                              mod_strand = "+",
                              sn_id = as.integer(transcripts$ENTREZID),
                              sn_name = transcripts$REFSEQ,
                              stringsAsFactors = FALSE)
  
  # Reactions
  gene_fbl <- select(orgdb,keys = "Fbl",
                     columns = c("GENENAME","ENSEMBL","ENTREZID"),
                     keytype = "SYMBOL")
  
  gene_dkc <- select(orgdb,keys = "Dkc1",
                     columns = c("GENENAME","ENSEMBL","ENTREZID"),
                     keytype = "SYMBOL")
  
  rx_rank <- 1L
  mod_type <- snoRNAdb$modification
  genename <- character(length(mod_type))
  ensembl <- character(length(mod_type))
  ensembltrans <- character(length(mod_type))
  entrezid <- character(length(mod_type))
  
  genename[mod_type == "Y"] <- gene_dkc$GENENAME
  genename[mod_type != "Y"] <- gene_fbl$GENENAME
  
  ensembl[mod_type == "Y"] <- gene_dkc$ENSEMBL
  ensembl[mod_type != "Y"] <- gene_fbl$ENSEMBL
  
  entrezid[mod_type == "Y"] <- gene_dkc$ENTREZID
  entrezid[mod_type != "Y"] <- gene_fbl$ENTREZID
  
  reactions <- data.frame(mod_id = mod_id,
                          rx_genename = genename,
                          rx_rank = rx_rank,
                          rx_ensembl = ensembl,
                          rx_ensembltrans = ensembltrans,
                          rx_entrezid = entrezid,
                          stringsAsFactors = FALSE)
  
  # Specifiers
  specifier_genename <- snoRNAdb$guide
  specifier_f <- specifier_genename != "unknown"
  specifier_genename <- strsplit(as.character(specifier_genename),",")[specifier_f]
  specifier_lengths <- lengths(specifier_genename)
  specifier_type <- "snoRNA"
  specifier_mod_id <- unlist(Map(rep,mod_id[specifier_f],specifier_lengths))
  # specifier_entrezid <- mapIds(orgdb,unlist(specifier_genename),"ENTREZID",
  #                              "SYMBOL")
  # specifier_ensembl <- mapIds(orgdb,unlist(specifier_genename),"ENSEMBL",
  #                             "SYMBOL")
  
  specifiers <- data.frame(mod_id = specifier_mod_id,
                           spec_type = specifier_type,
                           spec_genename = unlist(specifier_genename),
                           # spec_ensembl = specifier_ensembl,
                           # spec_entrezid = specifier_entrezid,
                           stringsAsFactors = FALSE)
  # References
  references_id <- strsplit(as.character(snoRNAdb$Ref),"\\.")
  references_f <- lengths(references_id) > 0L
  refDb <- data.frame(ID = c("1","2"),
                      PMID = c("16381836","31566069"))
  references_pmid <- lapply(references_id,
                            function(x){refDb[refDb$ID %in% x,"PMID"]})
  references_lengths <- lengths(references_pmid)
  references_mod_id <- unlist(Map(rep,mod_id[references_f],references_lengths))
  references <- data.frame(mod_id = references_mod_id,
                           ref_type = "PMID",
                           ref = unlist(references_pmid))
  makeEpiTxDb(modifications, reactions, specifiers, references,
              metadata = metadata)
}

# start the import RMBase, snoRNAdb and tRNAdb data
start.import <- function(bs, orgdb, tx){
  snoRNAdb <- read.csv2(system.file("extdata","snoRNAdb.mm10.csv"))
  etdb <- import_from_snoRNAdb(snoRNAdb, orgdb)
  db <- dbConnect(SQLite(), "hub/EpiTxDb.Mm.mm10.snoRNAdb.sqlite")
  sqliteCopyDatabase(etdb$conn, db)
  dbDisconnect(etdb$conn)
  dbDisconnect(db)
  
  etdb <- import_from_tRNAdb("Mus musculus", bs, tx)
  db <- dbConnect(SQLite(), "hub/EpiTxDb.Mm.mm10.tRNAdb.sqlite")
  sqliteCopyDatabase(etdb$conn, db)
  dbDisconnect(etdb$conn)
  dbDisconnect(db)
  
  etdb <- import.RMBase(bs, "mouse", "mm10",
                        listAvailableModFromRMBase("mouse", "mm10"))
  db <- dbConnect(SQLite(), "hub/EpiTxDb.Mm.mm10.RMBase.sqlite")
  sqliteCopyDatabase(etdb$conn, db)
  dbDisconnect(etdb$conn)
  dbDisconnect(db)
  return(TRUE)
}

start.import(BSgenome.Mmusculus.UCSC.mm10, org.Mm.eg.db, tx)
