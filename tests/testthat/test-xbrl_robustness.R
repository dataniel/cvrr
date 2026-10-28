# A panel written by hand: the ratios and factors are arithmetic on it, so
# the panel's own construction is not what is tested here.
panel <- function(...) {
  base <- data.frame(
    cvr = "1", name = "A", period_start = as.Date("2023-01-01"),
    period_end = as.Date("2023-12-31"), basis = "parent", class = "B",
    revenue = NA_real_, gross_profit = 1000, staff_costs = 600,
    depreciation = 100, operating_profit = 300, finance_expenses = 50,
    profit = 200, assets = 2000, current_assets = 800, cash = 300,
    equity = 600, contributed_capital = 100, longterm_debt = 400,
    shortterm_debt = 1000, employees = 4, founded = as.Date("2010-01-01"),
    assurance = "audit", going_concern = NA, file = "a.xml",
    stringsAsFactors = FALSE)
  args <- list(...)
  for (n in names(args)) base[[n]] <- args[[n]]
  base
}

test_that("ratios follow the statistics offices' definitions", {
  r <- xbrl_ratios(panel())
  expect_equal(r$equity_ratio, 0.3)
  expect_equal(r$return_on_assets, 0.1)        # after tax, on assets
  expect_equal(r$operating_return, 0.15)
  expect_equal(r$current_ratio, 0.8)
  expect_equal(r$interest_coverage, 6)
  expect_equal(r$staff_share, 0.6)
  expect_equal(r$value_added_per_employee, 250)
})

test_that("a ratio with no meaningful denominator is NA", {
  r <- xbrl_ratios(panel(equity = -100))
  expect_true(is.na(r$return_on_equity))
  expect_true(is.na(r$operating_margin))         # no revenue reported
})

test_that("growth is measured against the previous annual report only", {
  p <- rbind(panel(), panel(period_start = as.Date("2024-01-01"),
                            period_end = as.Date("2024-12-31"),
                            gross_profit = 1200, file = "b.xml"))
  r <- xbrl_ratios(p)
  expect_true(is.na(r$gross_profit_growth[1]))
  expect_equal(r$gross_profit_growth[2], 0.2)
})

test_that("a peer median needs enough peers", {
  p <- do.call(rbind, lapply(1:6, function(i)
    panel(cvr = as.character(i), equity = 100 * i, file = paste0(i, ".xml"))))
  r <- xbrl_ratios(p)
  expect_false(anyNA(r$equity_ratio_median))
  expect_equal(range(r$equity_ratio_pct), c(100 * 0.5 / 6, 100 * 5.5 / 6))
  r <- xbrl_ratios(p[1:4, ])
  expect_true(all(is.na(r$equity_ratio_median)))
})

test_that("the factors fire on what they describe, and stay quiet otherwise", {
  r <- xbrl_robustness(panel())
  expect_false(r$negative_equity)
  expect_false(r$capital_lost)
  expect_false(r$thin_equity)
  expect_false(r$shortterm_heavy)                # exactly half is not over half
  expect_true(xbrl_robustness(panel(shortterm_debt = 1100))$shortterm_heavy)
  expect_false(r$weak_interest_cover)
  expect_false(r$young)
  # Audited, nothing said: no going concern uncertainty.
  expect_false(r$going_concern_factor)

  r <- xbrl_robustness(panel(equity = -50, profit = -10, operating_profit = 40))
  expect_true(r$negative_equity)
  expect_true(r$capital_lost)
  expect_true(r$thin_equity)
  expect_true(r$weak_interest_cover)
})

test_that("two losses needs the year before", {
  p <- rbind(panel(profit = -5),
             panel(period_end = as.Date("2024-12-31"), profit = -8, file = "b.xml"))
  r <- xbrl_robustness(p)
  expect_true(is.na(r$two_losses[1]))
  expect_true(r$two_losses[2])
})

test_that("going concern is unknown where no auditor looked", {
  r <- xbrl_robustness(panel(assurance = "none"))
  expect_true(is.na(r$going_concern_factor))
  r <- xbrl_robustness(panel(assurance = "none", going_concern = TRUE))
  expect_true(r$going_concern_factor)
})

test_that("the buffers say what the figures could absorb", {
  r <- xbrl_robustness(panel())
  expect_equal(r$gross_profit_buffer, 0.3)       # 300 of 1000
  expect_equal(r$cash_months, 6)                 # 300 against 600 a year
})
