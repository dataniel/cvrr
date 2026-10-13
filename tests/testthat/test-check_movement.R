# A schedule in the shape add_taxonomy produces: one presentation group, a balance
# at both ends of the year, and the movements between them.
sched <- function(..., statement = "DisclosureOfAssets", member = NA_character_) {
  rows <- list(...)
  d <- do.call(rbind, lapply(rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))
  d$statement <- statement
  d$dim_ClassesOfAssets <- member
  d$basis <- "parent"
  d
}
bal <- function(code, el, period, value)
  list(code = code, elementid = el, periodtype = "instant", period = period,
       startdate = NA_character_, enddate = NA_character_, value = value)
flow <- function(code, el, value, start = "2023-01-01", end = "2023-12-31")
  list(code = code, elementid = el, periodtype = "duration", period = end,
       startdate = start, enddate = end, value = value)

test_that("a schedule that arrives is reported as unique", {
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 300),
    flow("400.00.010.060", "Disposals", 100)
  )
  r <- check_movement(x)
  expect_equal(nrow(r), 1L)
  expect_equal(r$status, "unique")
  expect_equal(r$opening, 1000)
  expect_equal(r$closing, 1200)
  expect_equal(r$n_movements, 2L)
  expect_equal(r$movements, "tagged")
})

test_that("the period comes from the movements, not from the balances", {
  # The comparative year is present, as it always is in a real filing. Pairing
  # the earliest instant with the latest would span two years and never close.
  x <- sched(
    bal("400.00.010.020", "Gross", "2022-01-01", 500),
    bal("400.00.010.020", "Gross", "2022-12-31", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200)
  )
  r <- check_movement(x)
  expect_equal(r$period, "2023-12-31")
  expect_equal(r$opening, 1000)
  expect_equal(r$status, "unique")
})

test_that("an opening balance dated to the year before is the same instant", {
  x <- sched(
    bal("400.00.010.020", "Gross", "2022-12-31", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200)
  )
  expect_equal(check_movement(x)$status, "unique")
})

test_that("a schedule that does not arrive is reported as unsolved", {
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 77)
  )
  expect_equal(check_movement(x)$status, "unsolved")
})

test_that("a rounding difference of one krone still reconciles", {
  # tol is a distance, not a grid: bucketing the sums without probing the
  # neighbouring buckets would report this as irreconcilable.
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1659925),
    bal("400.00.010.020", "Gross", "2023-12-31", -1439573),
    flow("400.00.010.040", "Movement", -3099497)
  )
  expect_equal(check_movement(x)$status, "unique")
  expect_equal(check_movement(x, tol = 0.5)$status, "unsolved")
})

test_that("each dimension member is its own schedule", {
  x <- rbind(
    sched(bal("400.00.010.020", "Gross", "2023-01-01", 1000),
          bal("400.00.010.020", "Gross", "2023-12-31", 1200),
          flow("400.00.010.040", "Additions", 200), member = "Buildings"),
    sched(bal("400.00.010.020", "Gross", "2023-01-01", 50),
          bal("400.00.010.020", "Gross", "2023-12-31", 90),
          flow("400.00.010.040", "Additions", 40), member = "Equipment")
  )
  r <- check_movement(x)
  expect_equal(nrow(r), 2L)
  expect_true(all(r$status == "unique"))
  expect_setequal(r$member, c("dim_ClassesOfAssets=Buildings",
                              "dim_ClassesOfAssets=Equipment"))
})

test_that("a total whose movements are tagged only per class is summed", {
  x <- rbind(
    sched(bal("400.00.010.020", "Gross", "2023-01-01", 1050),
          bal("400.00.010.020", "Gross", "2023-12-31", 1290)),
    sched(bal("400.00.010.020", "Gross", "2023-01-01", 1000),
          bal("400.00.010.020", "Gross", "2023-12-31", 1200),
          flow("400.00.010.040", "Additions", 200), member = "Buildings"),
    sched(bal("400.00.010.020", "Gross", "2023-01-01", 50),
          bal("400.00.010.020", "Gross", "2023-12-31", 90),
          flow("400.00.010.040", "Additions", 40), member = "Equipment")
  )
  r <- check_movement(x)
  tot <- r[is.na(r$member), ]
  expect_equal(nrow(tot), 1L)
  expect_equal(tot$status, "unique")
  expect_equal(tot$movements, "summed over classes")
})

test_that("a group holding several balances is not a schedule", {
  # The shape of a five-year summary: assets and equity at two dates each,
  # with the profit beside them. Nothing says which one the profit explains.
  x <- sched(
    bal("210.00.003.019", "Assets", "2023-01-01", 1000),
    bal("210.00.003.019", "Assets", "2023-12-31", 1200),
    bal("210.00.003.023", "Equity", "2023-01-01", 400),
    bal("210.00.003.023", "Equity", "2023-12-31", 600),
    flow("210.00.003.018", "ProfitLoss", 200),
    statement = "KeyFiguresAndFinancialRatios"
  )
  expect_equal(nrow(check_movement(x)), 0L)
})

test_that("statement scoping keeps a disclosure note out", {
  x <- rbind(
    sched(bal("400.00.010.020", "Gross", "2023-01-01", 1000),
          bal("400.00.010.020", "Gross", "2023-12-31", 1200),
          flow("400.00.010.040", "Additions", 200)),
    sched(bal("807.00.030.010.080", "Equity", "2023-01-01", 400),
          bal("807.00.030.010.080", "Equity", "2023-12-31", 600),
          flow("807.00.030.010.090", "ProfitLoss", 50),
          statement = "DisclosureOfRelatedParties")
  )
  expect_equal(nrow(check_movement(x)), 2L)
  r <- check_movement(x, statement = "DisclosureOfAssets")
  expect_equal(nrow(r), 1L)
  expect_equal(r$status, "unique")
})

test_that("a missing column is named", {
  expect_error(check_movement(data.frame(code = "1")), "startdate")
})

test_that("nothing to check returns an empty tibble, not an error", {
  x <- sched(bal("400.00.010.020", "Gross", "2023-12-31", 1200))
  expect_equal(nrow(check_movement(x)), 0L)
})

test_that("a nil movement is counted, not searched over", {
  # Zero times any sign is zero, so leaving it in the search would report
  # every schedule that has one as ambiguous.
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200),
    flow("400.00.010.060", "Disposals", 0)
  )
  r <- check_movement(x)
  expect_equal(r$status, "unique")
  expect_equal(r$n_movements, 1L)
  expect_equal(r$n_zero, 1L)
})

test_that("no movement may be discarded to make a schedule close", {
  # 1000 + 200 = 1200 on its own, but the filer also reported 50 moving, so
  # the schedule does not add up and saying otherwise would mean ignoring a
  # figure the filer put there deliberately.
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200),
    flow("400.00.010.060", "Disposals", 50)
  )
  expect_equal(check_movement(x)$status, "unsolved")
})

test_that("signs are the filer's, not a convention", {
  # A disposal reported positive must be subtracted; the depreciation written
  # back on the same disposal is reported negative and must be added. Both
  # appear in one note, so no fixed convention reads it.
  x <- sched(
    bal("400.00.010.020", "Dep", "2023-01-01", 700),
    bal("400.00.010.020", "Dep", "2023-12-31", 900),
    flow("400.00.010.040", "ChargeForYear", 300),
    flow("400.00.010.060", "ReversedOnDisposals", -100)
  )
  expect_equal(check_movement(x)$status, "unique")
})

test_that("a declared period rescues a movement with no start date", {
  # Without a start date on the movement there is nothing to pair the opening
  # balance to, and the schedule is skipped. The filing says when its year
  # began; that is enough.
  x <- sched(
    bal("400.00.010.020", "Gross", "2022-12-31", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200, start = NA_character_)
  )
  expect_equal(nrow(check_movement(x)), 0L)

  p <- data.frame(elementid = c("ReportingPeriodEndDate",
                                "PredingReportingPeriodEndDate"),
                  fact = c("2023-12-31", "2022-12-31"), stringsAsFactors = FALSE)
  r <- check_movement(x, period = xbrl_period(p))
  expect_equal(r$status, "unique")
  expect_equal(r$opening, 1000)
})

test_that("one figure tagged under both opening dates is still one figure", {
  x <- sched(
    bal("400.00.010.020", "Gross", "2022-12-31", 1000),
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200)
  )
  expect_equal(check_movement(x)$status, "unique")
})

test_that("a blank closing balance can be read as nil, and is marked", {
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    flow("400.00.010.040", "Disposals", 1000)
  )
  expect_equal(nrow(check_movement(x)), 0L)

  r <- check_movement(x, assume_nil = TRUE)
  expect_equal(r$status, "unique")
  expect_equal(r$closing, 0)
  expect_equal(r$balances, "closing assumed nil")
})

test_that("a schedule missing both balances is not a schedule", {
  x <- sched(flow("400.00.010.040", "Additions", 200))
  expect_equal(nrow(check_movement(x, assume_nil = TRUE)), 0L)
})

test_that("a reported balance is never overwritten by an assumed nil", {
  x <- sched(
    bal("400.00.010.020", "Gross", "2023-01-01", 1000),
    bal("400.00.010.020", "Gross", "2023-12-31", 1200),
    flow("400.00.010.040", "Additions", 200)
  )
  expect_equal(check_movement(x, assume_nil = TRUE)$balances, "reported")
})
