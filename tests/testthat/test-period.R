facts <- function(...) {
  d <- data.frame(elementid = c(...), stringsAsFactors = FALSE)
  d$fact <- c("2023-01-01", "2023-12-31", "2022-01-01", "2022-12-31")[seq_len(nrow(d))]
  d
}

test_that("a filing's declared period is read", {
  x <- data.frame(
    elementid = c("ReportingPeriodStartDate", "ReportingPeriodEndDate",
                  "PrecedingReportingPeriodStartDate", "PredingReportingPeriodEndDate"),
    fact = c("2023-01-01", "2023-12-31", "2022-01-01", "2022-12-31"),
    stringsAsFactors = FALSE)
  p <- xbrl_period(x)
  expect_equal(p$start, as.Date("2023-01-01"))
  expect_equal(p$end, as.Date("2023-12-31"))
  expect_equal(p$prev_start, as.Date("2022-01-01"))
  expect_equal(p$prev_end, as.Date("2022-12-31"))
})

test_that("the taxonomy's misspelling and its correction both work", {
  # `PredingReportingPeriodEndDate` is what the published taxonomy calls it, so
  # it is what filings carry; a filer who spells it correctly is still read.
  correct <- data.frame(elementid = "PrecedingReportingPeriodEndDate",
                        fact = "2022-12-31", stringsAsFactors = FALSE)
  expect_equal(xbrl_period(correct)$prev_end, as.Date("2022-12-31"))
})

test_that("a silent filing gives NA, not a guess", {
  x <- data.frame(elementid = "Assets", fact = "100", stringsAsFactors = FALSE)
  p <- xbrl_period(x)
  expect_true(all(is.na(unlist(p))))
  expect_equal(nrow(p), 1L)
})

test_that("a date stated twice takes the first", {
  x <- data.frame(elementid = rep("ReportingPeriodEndDate", 2),
                  fact = c("2023-12-31", "2022-12-31"), stringsAsFactors = FALSE)
  expect_equal(xbrl_period(x)$end, as.Date("2023-12-31"))
})

test_that("something that is not a filing is refused", {
  expect_error(xbrl_period(data.frame(a = 1)), "read_xbrl")
})

# A period date that is not a date is NA. It used to throw, and read_xbrl()
# caught the error by dropping the whole filing.
test_that("xbrl_period() reads a malformed date as NA rather than failing", {
  x <- data.frame(elementid = c("ReportingPeriodStartDate", "ReportingPeriodEndDate"),
                  fact = c("2023-01-01", "31.12.2023"))
  p <- xbrl_period(x)
  expect_equal(p$start, as.Date("2023-01-01"))
  expect_true(is.na(p$end))
})
