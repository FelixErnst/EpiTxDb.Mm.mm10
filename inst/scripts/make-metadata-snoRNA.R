
# Base data for all data sets --------------------------------------------------
library(S4Vectors)

df_Base <- DataFrame(
  BiocVersion = "3.11",
  SourceVersion = NA,
  Coordinate_1_based = TRUE,
  Maintainer = "Felix G.M. Ernst <felix.gm.ernst@outlook.com>"
)

RMBaseURL <- "http://rna.sysu.edu.cn/rmbase/"
tRNAdbURL <- "http://trna.bioinf.uni-leipzig.de/"
snoRNAdbURL <- "https://www-snorna.biotoul.fr/"

df <- rbind(
  cbind(df_Base,
        DataFrame(Title = "EpiTxDb snoRNAdb for Mus musculus mm10", 
                  Description = paste0(
                    "Information from the snoRNAdb was downloaded, manually ",
                    "adjusted for changes in recent rRNA sequences from ",
                    "H. sapiens/M. musculus and stored as EpiTxDb database. ",
                    "The information provided match mm10 release ",
                    "sequences modified according to Hebras et al. 2019."),
                  SourceType = "CSV",
                  SourceUrl = snoRNAdbURL,
                  DataProvider = "snoRNAdb",
                  RDataClass = "SQLiteFile", 
                  DispatchClass = "SQLiteFile",
                  RDataPath = "EpiTxDb.Mm.mm10/EpiTxDb.Mm.mm10.snoRNAdb.sqlite")),
  cbind(df_Base,
        DataFrame(Title = "Sequences of snoRNA targets of Mus musculus mm10", 
                  Description = paste0(
                    "Fasta file for snoRNA targets based on genomic sequences ",
                    "for Mus musculus mm10."),
                  SourceType = "FASTA",
                  SourceUrl = "https://www.ncbi.nlm.nih.gov/gene",
                  DataProvider = "NCBI",
                  RDataClass = "FaFile", 
                  DispatchClass = "FaFile",
                  RDataPath = "EpiTxDb.Mm.mm10/snoRNA.targets.mm10.fa"))
)

df$Species <- "Mus musculus"
df$TaxonomyId <- "10090"
df$SourceVersion <- Sys.time()
df$Genome <- "mm10"
df$Tags <- "EpiTxDb:mm10:Modification:Epitranscriptomics"

write.csv(df, file = "inst/extdata/metadata-snoRNA.csv", row.names = FALSE)
