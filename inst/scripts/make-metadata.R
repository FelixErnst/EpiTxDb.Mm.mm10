
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

df <- rbind(
  cbind(df_Base,
        DataFrame(Title = "EpiTxDb RMBase v2.0 for Mus musculus mm10", 
                  Description = paste0(
                    ""), 
                  SourceType = "BED",
                  SourceUrl = RMBaseURL,
                  DataProvider = "RMBase v2.0",
                  RDataClass = "SQLiteFile", 
                  DispatchClass = "SQLiteFile",
                  RDataPath = "EpiTxDb.Mm.mm10/EpiTxDb.Mm.mm10.RMBase.sqlite")),
  cbind(df_Base,
        DataFrame(Title = "EpiTxDb tRNAdb for Mus musculus mm10", 
                  Description = paste0(
                    ""),
                  SourceType = "XML",
                  SourceUrl = tRNAdbURL,
                  DataProvider = "tRNAdb",
                  RDataClass = "SQLiteFile", 
                  DispatchClass = "SQLiteFile",
                  RDataPath = "EpiTxDb.Mm.mm10/EpiTxDb.Mm.mm10.tRNAdb.sqlite"))
)

df$Species <- "Mus musculus"
df$TaxonomyId <- "10090"
df$SourceVersion <- Sys.time()
df$Genome <- "mm10"
df$Tags <- "EpiTxDb:mm10:Modification:Epitranscriptomics"

write.csv(df, file = "inst/extdata/metadata.csv", row.names = FALSE)
