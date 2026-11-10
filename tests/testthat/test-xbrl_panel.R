# One filing in the shape read_xbrl() returns, from the packaged taxonomy.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")
st <- cvrr:::.structure_for(REF, NULL)
line <- function(el, value, statement, instant = TRUE) {
  s <- st[st$statement == statement & st$elementid == el, ][1, ]
  if (is.na(s$code)) stop("element not in structure: ", el)
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
info <- function(el, fact) {
  r <- inc("GrossProfitLoss", 0)[1, ]
  r$elementid <- el; r$fact <- fact; r$value <- NA; r$statement <- NA
  r$code <- NA; r$is_line <- FALSE
  r
}
filing <- function(tax = 50) {
  x <- rbind(
    info("NameOfReportingEntity", "Testselskabet ApS"),
    info("ClassOfReportingEntity", "Regnskabsklasse B"),
    inc("GrossProfitLoss", 800),
    inc("EmployeeBenefitsExpense", -300),      # a filer who signed it
    inc("ProfitLossFromOrdinaryOperatingActivities", 500),
    inc("ProfitLossFromOrdinaryActivitiesBeforeTax", 480),
    inc("TaxExpense", abs(tax)),               # tax written positive either way
    inc("ProfitLoss", 480 - tax),
    bal("Assets", 1000), bal("LiabilitiesAndEquity", 1000),
    bal("Equity", 400), bal("Provisions", 100),
    bal("ShorttermLiabilitiesOtherThanProvisions", 500))
  x$file <- "a.xml"; x$cvr <- "12345678"
  x$period_start <- as.Date("2023-01-01"); x$period_end <- as.Date("2023-12-31")
  x$prev_end <- as.Date("2022-12-31")
  x
}

test_that("a filing becomes one row with its figures named", {
  p <- suppressMessages(xbrl_panel(filing()))
  expect_s3_class(p, "cvrr_panel")
  expect_equal(nrow(p), 1L)
  expect_equal(names(p)[1:4], cvrr:::.KEYS)
  expect_equal(p$gross_profit, 800)
  expect_equal(p$operating_profit, 500)
  expect_equal(p$equity, 400)
  expect_equal(p$assets, 1000)
  expect_equal(p$class, "B")
})

test_that("costs are positive amounts whatever sign the filer gave them", {
  p <- suppressMessages(xbrl_panel(filing()))
  expect_equal(p$staff_costs, 300)
})

# Tax is the one cost that can be negative. Written positive, as a refund
# often is, it would be read as a charge; the two results say which it is.
test_that("tax and net financials are signed by identity", {
  p <- suppressMessages(xbrl_panel(filing(tax = -30)))
  expect_equal(p$tax, -30)
  expect_equal(p$net_financials, -20)
  expect_equal(p$profit, 510)
})

test_that("a figure the filing does not report is NA, not an estimate", {
  p <- suppressMessages(xbrl_panel(filing()))
  expect_true(is.na(p$revenue))
  expect_true(is.na(p$cf_operating))
})

test_that("the trust columns are there", {
  p <- suppressMessages(xbrl_panel(filing()))
  expect_true(p$balance_reconciled)
  expect_equal(p$corrections, 0L)
})

# Facts with no statement line in them: a directory of filings read with a
# taxonomy that places none of their elements. The panel is then empty, and
# used to be an error -- one NA assigned to a table with no rows.
test_that("filings without statement lines give an empty panel, not an error", {
  x <- filing()
  p <- suppressMessages(xbrl_panel(x[is.na(x$statement), ]))
  expect_s3_class(p, "cvrr_panel")
  expect_equal(nrow(p), 0L)
  expect_true(all(c("equity", "balance_reconciled", "corrections") %in% names(p)))
})

# A report withdrawn and filed again: two files, one company, one year.
test_that("a report filed twice is in the panel once, as the later filing", {
  first <- filing()
  again <- filing()
  again$file <- "a_2.xml"
  again$value[again$elementid == "Equity"] <- 300
  again$value[again$elementid == "Provisions"] <- 200
  approved <- function(x, day) {
    r <- info("DateOfApprovalOfAnnualReport", day)
    r[setdiff(names(x), names(r))] <- x[1, setdiff(names(x), names(r))]
    rbind(x, r[names(x)])
  }
  # the later approval wins whichever file is read first
  for (x in list(rbind(approved(first, "2024-03-01"), approved(again, "2024-06-01")),
                 rbind(approved(again, "2024-06-01"), approved(first, "2024-03-01")))) {
    expect_warning(p <- suppressMessages(xbrl_panel(x)), "same company and year")
    expect_equal(nrow(p), 1L)
    expect_equal(p$file, "a_2.xml")
    expect_equal(p$equity, 300)
  }
  # with no date to go by, the one read last
  expect_warning(p <- suppressMessages(xbrl_panel(rbind(first, again))), "a.xml")
  expect_equal(p$file, "a_2.xml")
})

test_that("a check that fails says so instead of reading as nothing to check", {
  local_mocked_bindings(check_statement = function(...) stop("broken {inside}"))
  expect_warning(p <- suppressMessages(xbrl_panel(filing())),
                 "balance sheet check failed")
  expect_true(is.na(p$balance_reconciled))
})
