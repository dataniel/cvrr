# Filings in the shape read_xbrl() returns, built from the packaged taxonomy.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")
st <- cvrr:::.structure_for(REF, NULL)

line <- function(el, value, statement, when) {
  s <- st[st$statement == statement & st$elementid == el, ][1, ]
  if (is.na(s$code)) stop("element not in structure: ", el)
  data.frame(elementid = el, value = value, fact = as.character(value),
             statement = statement, code = s$code, depth = 3L,
             label = el, balance = s$balance, is_line = TRUE, abstract = FALSE,
             basis = "parent", period = as.Date(when), instant = as.Date(when),
             periodtype = "instant", schemaref = REF, decimals = "0",
             dimensions = NA_character_, explicit_member = NA_character_,
             stringsAsFactors = FALSE)
}
bs <- function(el, value, when = "2023-12-31")
  line(el, value, "BalanceSheetAccountForm", when)
cf <- function(el, value, when = "2023-12-31") {
  r <- line(el, value, "CashFlowStatement", when)
  if (!el %in% "CashAndCashEquivalentsConcerningCashflowStatement") {
    r$periodtype <- "duration"; r$instant <- as.Date(NA)
  }
  r
}
filing <- function(..., file = "a.xml", cvr = "12345678") {
  x <- rbind(...)
  x$file <- file; x$cvr <- cvr
  x$period_start <- as.Date("2023-01-01"); x$period_end <- as.Date("2023-12-31")
  x$prev_end <- as.Date("2022-12-31")
  x
}

# A balance sheet that closes, with debt that rose by 700.
clean <- function(file = "a.xml", cvr = "12345678") filing(
  bs("Assets", 3000), bs("LiabilitiesAndEquity", 3000), bs("Equity", 300),
  bs("LongtermLiabilitiesOtherThanProvisions", 2000, "2022-12-31"),
  bs("LongtermLiabilitiesOtherThanProvisions", 2700),
  file = file, cvr = cvr)

# The same, with a cash flow statement that borrowed 1,000 the balance sheet
# owes only 700 of, and the other 300 taken out under investing as a negative
# sale: a grant booked as a loan.
grant_as_loan <- function() rbind(clean(), filing(
  cf("CashFlowsFromUsedInOperatingActivities", 100),
  cf("CashFlowsFromUsedInInvestingActivities", -900),
  cf("PurchaseOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities", 600),
  cf("SaleOfOtherCompany", -300),
  cf("CashFlowsFromUsedInFinancingActivities", 1000),
  cf("ProceedsFromLongtermLiabilitiesClassifiedAsFinancingActivities", 1000),
  cf("NetIncreaseDecreaseInCashAndCashEquivalents", 200)))

test_that("a filing with nothing wrong has no findings", {
  s <- suppressMessages(xbrl_screen(clean(), what = c("balance", "cashflow")))
  expect_equal(nrow(s), 0L)
  expect_equal(attr(s, "screened"), 1L)
})

test_that("a grant booked as a loan is a high finding, sized against assets", {
  s <- suppressMessages(xbrl_screen(grant_as_loan(), what = "cashflow"))
  d <- s[s$finding == "borrowed more than owed", ]
  expect_equal(d$severity, "high")
  expect_equal(d$amount, 300)
  expect_equal(d$share, 300 / 3000)
  expect_match(d$detail, "SaleOfOtherCompany")
  expect_equal(names(s)[1:4], cvrr:::.KEYS)
})

test_that("a balance sheet whose sides differ is found", {
  x <- clean()
  x$value[x$elementid == "LiabilitiesAndEquity"] <- 2900
  x <- rbind(x, filing(bs("Provisions", 100), bs("LiabilitiesOtherThanProvisions", 2500)))
  s <- suppressMessages(xbrl_screen(x, what = "balance"))
  expect_true("sides differ" %in% s$finding)
})

# Materiality moves a finding down, and one that ends at low is left out.
test_that("an immaterial finding moves down a level", {
  s <- suppressMessages(xbrl_screen(grant_as_loan(), what = "cashflow",
                                    materiality = 0.5))
  expect_equal(s$severity[s$finding == "borrowed more than owed"], "medium")
})

# Some filers tag the five-year overview on placeholder dates that each filing
# reuses for its own earlier years. Two filings then "state" 2001-12-30 with
# figures for different years, and that is not a restatement.
test_that("placeholder dates are not compared, a reopening balance is", {
  later <- function(comparative) {
    b <- filing(bs("Assets", comparative, "2023-12-31"), bs("Assets", 3100, "2024-12-31"),
                bs("Assets", 200, "2001-12-30"), file = "b.xml")
    b$period_start <- as.Date("2024-01-01"); b$period_end <- as.Date("2024-12-31")
    b$prev_end <- as.Date("2023-12-31")
    b
  }
  a <- rbind(clean("a.xml"), filing(bs("Assets", 100, "2001-12-30")))
  s <- suppressMessages(xbrl_screen(rbind(a, later(3000)), what = "continuity"))
  expect_false("restated" %in% s$finding)

  s <- suppressMessages(xbrl_screen(rbind(a, later(2800)), what = "continuity"))
  expect_true("restated" %in% s$finding)
  expect_match(s$detail[s$finding == "restated"], "of 1 figures")
})

test_that("a restatement's detail is in the report's language", {
  tr <- cvrr:::.report_words("da")
  expect_equal(cvrr:::.detail_words("4 of 109 figures differ; largest Assets", tr),
               "4 af 109 tal afviger; størst Assets")
  expect_equal(cvrr:::.detail_words("x", cvrr:::.report_words("en")), "x")
})

# A figure written in kroner one year and in thousands the next.
test_that("a figure in the other unit between filings is found", {
  a <- clean("a.xml")
  b <- clean("b.xml")
  b$period_start <- as.Date("2024-01-01"); b$period_end <- as.Date("2024-12-31")
  b$prev_end <- as.Date("2023-12-31")
  # b's comparative for 2023 states Assets in thousands
  b$period[b$elementid == "Assets"] <- as.Date("2023-12-31")
  b$instant[b$elementid == "Assets"] <- as.Date("2023-12-31")
  b$value[b$elementid == "Assets"] <- 3
  b <- rbind(b, filing(bs("Assets", 3100, "2024-12-31"), file = "b.xml"))
  b$period_start <- as.Date("2024-01-01"); b$period_end <- as.Date("2024-12-31")
  # As tagged, it is a finding.
  s <- suppressMessages(xbrl_screen(rbind(a, b), what = "continuity",
                                    standardise = FALSE))
  expect_true("written in the other unit" %in% s$finding)
  expect_equal(unique(s$file[s$finding == "written in the other unit"]), "b.xml")

  # Standardised first, it is a technicality: not a finding, but listed.
  s <- suppressMessages(xbrl_screen(rbind(a, b), what = "continuity"))
  expect_false("written in the other unit" %in% s$finding)
  expect_true(nrow(attr(s, "technical")) >= 1)
})

test_that("print gives one line per filing, its worst finding first", {
  s <- suppressMessages(xbrl_screen(grant_as_loan(), what = "cashflow"))
  out <- paste(capture.output(print(s)), collapse = "\n")
  expect_match(out, "cvrr screen")
  expect_match(out, "1 screened")
  expect_match(out, "borrowed more than owed")
  expect_match(out, "10.0%")
})

# Filtering is the commonest thing done to it, and whatever comes back has to
# print, whether or not the class survived.
test_that("a subset of a screen still prints", {
  s <- suppressMessages(xbrl_screen(grant_as_loan(), what = "cashflow"))
  expect_no_error(capture.output(print(s[s$severity == "high", ])))
  expect_no_error(capture.output(print(s[, c("cvr", "finding")])))
})

test_that("a screen with nothing found prints as such", {
  s <- suppressMessages(xbrl_screen(clean(), what = "cashflow"))
  expect_match(paste(capture.output(print(s)), collapse = "\n"), "0 with a finding")
})

test_that("a frame that is not from read_xbrl is refused with a reason", {
  expect_error(xbrl_screen(data.frame(elementid = "Assets")), "read_xbrl")
})
