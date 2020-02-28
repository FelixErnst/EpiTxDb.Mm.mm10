context("EpiTxDb.Mm.mm10")
test_that("EpiTxDb.Mm.mm10:",{
  etdb <- EpiTxDb.Mm.mm10.tRNAdb()
  expect_s4_class(etdb,"EpiTxDb")
})
