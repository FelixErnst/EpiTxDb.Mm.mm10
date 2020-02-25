context("EpiTxDb.Mm.mm10")
test_that("EpiTxDb.Mm.mm10:",{
  actual <- AnnotationHubData::makeAnnotationHubMetadata(system.file(package = "EpiTxDb.Mm.mm10"),
                                                         fileName = "../../extdata/metadata.csv")
  expect_equal(length(actual), 2L)
})
