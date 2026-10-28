# One filing in the shape read_xbrl() returns, from the packaged taxonomy.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")
st <- cvrr:::.structure_for(REF, NULL)
line <- function(el, value, statement, instant = TRUE) {
  s <- st[st$statement == statement & st$elementid == el, ][1, ]
  data.frame(elementid = el, fact = as.character(value), value = value,
             statement = statement, code = s$code, depth = 3L, label = el,
             balance = s$balance, is_line = TRUE, abstract = FALSE,
             basis = "parent", instant = if (instant) as.Date("2023-12-31") else as.Date(NA),
             enddate = if (instant) as.Date(NA) else as.Date("2023-12-31"),
             startdate = if (instant) as.Date(NA) else as.Date("2023-01-01"),
             period = as.Date("2023-12-31"), schemaref = REF, unit = "iso4217:DKK",
             decimals = "0", dimensions = NA_character_, explicit_member = NA_character_,
             periodtype = if (instant) "instant" else "duration",
             stringsAsFactors = FALSE)
}
bal <- function(el, v) line(el, v, "BalanceSheetAccountForm")
inc <- function(el, v) line(el, v, "IncomeStatementByNature", instant = FALSE)
filing <- function(file, cvr, equity = 400) {
  x <- rbind(
    inc("GrossProfitLoss", 800),
    inc("ProfitLossFromOrdinaryOperatingActivities", 500),
    inc("ProfitLossFromOrdinaryActivitiesBeforeTax", 480),
    inc("ProfitLoss", 430),
    bal("Assets", 1000), bal("LiabilitiesAndEquity", 1000),
    bal("Equity", equity), bal("Provisions", 100),
    bal("ShorttermLiabilitiesOtherThanProvisions", 1000 - equity - 100))
  x$file <- file; x$cvr <- cvr
  x$period_start <- as.Date("2023-01-01"); x$period_end <- as.Date("2023-12-31")
  x$prev_end <- as.Date("2022-12-31")
  x
}
two <- function() tibble::as_tibble(rbind(filing("a.xml", "11111111"),
                                          filing("b.xml", "22222222", 300)))

test_that("the work is attached to the facts, which stay facts", {
  v <- suppressMessages(xbrl_validate(two()))
  expect_s3_class(v, "cvrr_validated")
  expect_s3_class(v, "tbl_df")
  expect_true("standardised" %in% names(v))
  w <- attr(v, "validated")
  expect_true(all(c("company", "statement", "cascade", "cashflow", "lines",
                    "fingerprint") %in% names(w)))
  expect_named(w$lines, c("parent", "consolidated"))
})

test_that("panel and screen come out as they do from the facts", {
  x <- two()
  v <- suppressMessages(xbrl_validate(x))
  expect_equal(suppressMessages(xbrl_panel(v)), suppressMessages(xbrl_panel(x)))
  s1 <- suppressMessages(xbrl_screen(v))
  s2 <- suppressMessages(xbrl_screen(x))
  attr(s1, "checks") <- attr(s2, "checks") <- NULL
  expect_equal(s1, s2)
  expect_equal(suppressMessages(xbrl_lines(v, "balance")),
               suppressMessages(xbrl_lines(x, "balance")))
})

test_that("validated facts are read, not checked again", {
  v <- suppressMessages(xbrl_validate(two()))
  local_mocked_bindings(
    check_cascade = function(...) stop("ran again"),
    check_statement = function(...) stop("ran again"),
    xbrl_lines = function(...) stop("ran again"))
  expect_no_error(suppressMessages(xbrl_screen(v)))
  expect_no_error(suppressMessages(xbrl_panel(v)))
})

test_that("a subset of whole filings keeps the work, cut to it", {
  v <- suppressMessages(xbrl_validate(two()))
  a <- v[v$cvr == "11111111", ]
  w <- cvrr:::.validated(a)
  expect_false(is.null(w))
  expect_equal(unique(w$company$file), "a.xml")
  expect_equal(unique(w$lines$parent$balance$file), "a.xml")
})

test_that("a changed figure is not read from stale work", {
  v <- suppressMessages(xbrl_validate(two()))
  v$value[v$file == "a.xml" & v$elementid == "Equity"] <- 999
  expect_null(cvrr:::.validated(v))
  p <- suppressMessages(xbrl_panel(v))
  expect_equal(p$equity[p$file == "a.xml"], 999)

  # and so is a filing with some of its rows dropped
  v <- suppressMessages(xbrl_validate(two()))
  expect_null(cvrr:::.validated(v[!(v$file == "a.xml" & v$elementid == "Equity"), ]))
})
