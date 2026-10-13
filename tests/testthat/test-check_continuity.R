# Facts from several filings of one or more companies, stacked.
fact <- function(cvr, year, el, instant, value)
  data.frame(cvr = cvr, year = year, elementid = el, instant = instant,
             value = value, dimensions = NA_character_,
             stringsAsFactors = FALSE)

test_that("a balance that reopens where it closed agrees", {
  x <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000),
    fact("1", "2024", "Assets", "2023-12-31", 1000),
    fact("1", "2024", "Assets", "2024-12-31", 1200))
  r <- check_continuity(x)
  expect_equal(nrow(r), 1L)                 # only the shared date is compared
  expect_equal(r$period, "2023-12-31")
  expect_equal(r$verdict, "agrees")
  expect_equal(r$closed_in, "2023")
  expect_equal(r$opened_in, "2024")
})

test_that("a figure written in the other unit is called scaled", {
  # The check no single filing can make: a filing multiplied all the way
  # through is internally perfect, and only a figure from outside disagrees.
  x <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000),
    fact("1", "2024", "Assets", "2023-12-31", 1000000))
  expect_equal(check_continuity(x)$verdict, "scaled")

  y <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000000),
    fact("1", "2024", "Assets", "2023-12-31", 1000))
  expect_equal(check_continuity(y)$verdict, "scaled")
})

test_that("a small difference is rounding and a large one is not", {
  x <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000000),
    fact("1", "2024", "Assets", "2023-12-31", 1000200))
  expect_equal(check_continuity(x)$verdict, "rounding")

  y <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000000),
    fact("1", "2024", "Assets", "2023-12-31", 1400000))
  expect_equal(check_continuity(y)$verdict, "differs")
})

test_that("comparatives inside one filing are not a second opinion", {
  # A filing stating last year's figure alongside this year's is one document
  # making one claim; comparing it with itself proves nothing.
  x <- rbind(
    fact("1", "2024", "Assets", "2023-12-31", 1000),
    fact("1", "2024", "Assets", "2024-12-31", 1200))
  expect_equal(nrow(check_continuity(x)), 0L)
})

test_that("companies are kept apart", {
  x <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000),
    fact("2", "2024", "Assets", "2023-12-31", 9999))
  expect_equal(nrow(check_continuity(x)), 0L)
})

test_that("a dimensional breakdown is not compared", {
  x <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000),
    fact("1", "2024", "Assets", "2023-12-31", 1000))
  x$dimensions[2] <- "fsa:ClassesDimension"
  expect_equal(nrow(check_continuity(x)), 0L)
})

test_that("a filing repeating a figure is still one claim", {
  x <- rbind(
    fact("1", "2023", "Assets", "2023-12-31", 1000),
    fact("1", "2023", "Assets", "2023-12-31", 1000),
    fact("1", "2024", "Assets", "2023-12-31", 1000))
  r <- check_continuity(x)
  expect_equal(nrow(r), 1L)
  expect_equal(r$verdict, "agrees")
})

test_that("a missing column is named", {
  expect_error(check_continuity(data.frame(cvr = "1")), "elementid")
})

test_that("income statement lines are compared by the period they cover", {
  # The comparative column of one filing against the primary column of the one
  # before it: the same year's profit, stated twice a year apart.
  dur <- function(cvr, year, el, start, end, value)
    data.frame(cvr = cvr, year = year, elementid = el, instant = NA_character_,
               startdate = start, enddate = end, value = value,
               dimensions = NA_character_, stringsAsFactors = FALSE)
  x <- rbind(
    dur("1", "2023", "ProfitLoss", "2023-01-01", "2023-12-31", 500),
    dur("1", "2024", "ProfitLoss", "2023-01-01", "2023-12-31", 500),
    dur("1", "2024", "ProfitLoss", "2024-01-01", "2024-12-31", 700))
  r <- check_continuity(x)
  expect_equal(nrow(r), 1L)
  expect_equal(r$period, "2023-01-01 2023-12-31")
  expect_equal(r$verdict, "agrees")
})

test_that("a restated profit is reported", {
  dur <- function(cvr, year, value)
    data.frame(cvr = cvr, year = year, elementid = "ProfitLoss",
               instant = NA_character_, startdate = "2023-01-01",
               enddate = "2023-12-31", value = value,
               dimensions = NA_character_, stringsAsFactors = FALSE)
  expect_equal(check_continuity(rbind(dur("1", "2023", 500),
                                      dur("1", "2024", 800)))$verdict, "differs")
})
