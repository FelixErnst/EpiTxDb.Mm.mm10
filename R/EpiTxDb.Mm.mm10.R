#' @title Annotation package for \code{EpiTxDb} objects
#'
#' @author Felix G M Ernst [aut]
#'
#' @description
#' This package loads one or more \code{EpiTxDb} objects. Such \code{EpiTxDb}
#' objects are an R interface to prefabricated databases contained by this
#' package.
#' 
#' The names of any objects exposed by this package indicate the origin and
#' resources exposed. So for example \code{EpiTxDb.Mm.mm10.tRNAdb} would be a
#' \code{EpiTxDb} object of Mus musculus data from tRNAdb build based on the
#' mm10 genome.
#'
#' @return a \code{\link[EpiTxDb:EpiTxDb-class]{EpiTxDb}} object 
#' 
#' @seealso
#' \itemize{
#' \item{\code{\link[EpiTxDb:modifications]{modifications}}}
#' \item{\code{\link[EpiTxDb:modifications]{modificationsBy}}}
#' \item{\code{\link[EpiTxDb:modifications]{modifiedSeqsByTranscript}}}
#' }
#' 
#' @docType package
#' @name EpiTxDb.Mm.mm10
#' 
#' @examples 
#' EpiTxDb.Mm.mm10.tRNAdb()
NULL

#' @import AnnotationHub
#' @import EpiTxDb
NULL

.check_version <- function(version){
    if(!is.character(version) || length(version) != 1L){
        stop("'version' must be single character value.",call. = FALSE)
    }
    if(!(version %in% AH_DATA$version)){
        stop("'version' must be valid version. Currently valid versions are: '",
             paste(unique(AH_DATA$version), collapse = "', '"),"'",
             call. = FALSE)
    }
}

.load_resource <- function(version = "1", type = NA){
    .check_version(version)
    ah <- AnnotationHub()
    id <- AH_DATA[AH_DATA$version == version,type]
    if(!is.na(id)){
        stop("Not data for '",type,"' and version '",version,"' available.")
    }
    resource <- ah[[id]]
    return(resource)
}

#' @rdname EpiTxDb.Mm.mm10
#' @export
EpiTxDb.Mm.mm10.RMBase <- function(version = "1"){
    .load_resource(version = version, type = "RMBase")
}

#' @rdname EpiTxDb.Mm.mm10
#' @export
EpiTxDb.Mm.mm10.tRNAdb <- function(version = "1"){
    .load_resource(version = version, type = "tRNAdb")
}

# version information ----------------------------------------------------------

AH_DATA <- data.frame(version = "1",
                      RMBase = "AH78917",
                      tRNAdb = "AH78918")

# AH_DATA <- rbind(AH_DATA,
#                  data.frame(version = "1.0",
#                             RMBase = "AH00000",
#                             tRNAdb = "AH00000"))
