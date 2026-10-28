test_that("the data decides the report, unless told", {
  one <- data.frame(cvr = "1", basis = "parent", file = "a",
                    period_end = as.Date("2023-12-31"))
  two_years <- rbind(one, transform(one, file = "b", period_end = as.Date("2024-12-31")))
  two_firms <- rbind(one, transform(one, cvr = "2", file = "c"))
  panel <- rbind(two_years, transform(two_years, cvr = "2", file = c("c", "d")))
  expect_equal(cvrr:::.report_type(one), "filing")
  expect_equal(cvrr:::.report_type(two_years), "company")
  expect_equal(cvrr:::.report_type(two_firms), "cross_section")
  expect_equal(cvrr:::.report_type(panel), "panel")
})

# What a reader should know first, and nothing when there is nothing.
highlight <- function(...) {
  last <- data.frame(opinion_kind = "clean", going_concern = NA, profit = 100,
                     two_losses = FALSE, negative_equity = FALSE, capital_lost = FALSE,
                     equity = 500, equity_ratio = 0.4, equity_ratio_change = 0,
                     gross_profit_growth = 0.02, gross_profit_buffer = 0.4,
                     operating_profit = 200, cash_months = 4, n_factors = 0,
                     period_end = as.Date("2024-12-31"))
  a <- list(...)
  for (n in names(a)) last[[n]] <- a[[n]]
  f <- data.frame(severity = character(), period_end = as.Date(character()),
                  check = character(), finding = character())
  cvrr:::.company_highlights(last, last, f, cvrr:::.report_words("da"), FALSE)
}

test_that("a company with nothing unusual says so", {
  expect_equal(highlight(), "Intet i regnskabet skiller sig ud.")
})

test_that("each rule says its thing when its threshold is crossed", {
  expect_match(highlight(opinion_kind = "qualified"), "forbehold", all = FALSE)
  expect_match(highlight(profit = -50, two_losses = TRUE), "andet år i træk", all = FALSE)
  expect_match(highlight(equity_ratio = 0.2, equity_ratio_change = -0.2),
               "Soliditeten faldt", all = FALSE)
  expect_match(highlight(cash_months = 0.5), "måneders løn", all = FALSE)
  expect_match(highlight(n_factors = 4), "4 af de kendte tegn", all = FALSE)
})

# The column name went in as an argument name, matched .cell()'s own first
# formal, and every cell of a year table showed the name of its column.
test_that("a table of years shows the figures, not the column names", {
  d <- data.frame(year = c("2023", "2024"), equity = c(1000, 1500),
                  equity_ratio = c(0.25, 0.3))
  h <- cvrr:::.html_table(d, cvrr:::.report_labels("da"), cvrr:::.report_words("da"),
                          wide_years = TRUE)
  expect_match(h, "1.500")
  expect_match(h, "30,0 %")
  expect_false(grepl(">equity<", h, fixed = TRUE))
})

test_that("text is escaped on the page", {
  expect_equal(cvrr:::.esc("A & B <C>"), "A &amp; B &lt;C&gt;")
})

# The whole way, on one filing built from the packaged taxonomy.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")
st <- cvrr:::.structure_for(REF, NULL)
line <- function(el, value, statement, instant = TRUE) {
  s <- st[st$statement == statement & st$elementid == el, ][1, ]
  data.frame(elementid = el, fact = as.character(value), value = value,
             statement = statement, code = s$code, depth = 3L, label = el,
             balance = s$balance, is_line = TRUE, abstract = FALSE, basis = "parent",
             instant = if (instant) as.Date("2023-12-31") else as.Date(NA),
             enddate = if (instant) as.Date(NA) else as.Date("2023-12-31"),
             startdate = if (instant) as.Date(NA) else as.Date("2023-01-01"),
             period = as.Date("2023-12-31"), schemaref = REF, unit = "iso4217:DKK",
             decimals = "0", dimensions = NA_character_, explicit_member = NA_character_,
             periodtype = if (instant) "instant" else "duration",
             stringsAsFactors = FALSE)
}
one_filing <- function() {
  inc <- function(e, v) line(e, v, "IncomeStatementByNature", FALSE)
  bal <- function(e, v) line(e, v, "BalanceSheetAccountForm")
  nm <- inc("GrossProfitLoss", 0); nm$elementid <- "NameOfReportingEntity"
  nm$fact <- "Testselskabet ApS"; nm$value <- NA; nm$statement <- NA; nm$is_line <- FALSE
  x <- rbind(nm, inc("GrossProfitLoss", 800), inc("ProfitLossFromOrdinaryOperatingActivities", -100),
             inc("ProfitLossFromOrdinaryActivitiesBeforeTax", -120), inc("ProfitLoss", -120),
             bal("Assets", 1000), bal("LiabilitiesAndEquity", 1000), bal("Equity", -50),
             bal("Provisions", 50), bal("ShorttermLiabilitiesOtherThanProvisions", 1000))
  x$file <- "a.xml"; x$cvr <- "12345678"
  x$period_start <- as.Date("2023-01-01"); x$period_end <- as.Date("2023-12-31")
  x$prev_end <- as.Date("2022-12-31")
  x
}

test_that("one filing becomes a report, and the report a page", {
  d <- suppressMessages(xbrl_report_data(one_filing()))
  expect_s3_class(d, "cvrr_report_data")
  expect_equal(d$type, "filing")
  expect_true(any(grepl("negativ", d$highlights)))
  f <- withr::local_tempfile(fileext = ".html")
  suppressMessages(xbrl_report(d, f))
  page <- paste(readLines(f, encoding = "UTF-8"), collapse = "\n")
  expect_match(page, "Testselskabet ApS")
  expect_match(page, "<!doctype html>", fixed = TRUE)
  expect_match(page, "−120")      # the loss, with a real minus
})

test_that("a CVR number not in the filings is refused with a reason", {
  expect_error(suppressMessages(xbrl_report_data(one_filing(), cvr = "99999999")),
               "No filing")
})
