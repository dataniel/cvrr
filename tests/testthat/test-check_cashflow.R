# A filing in the shape read_xbrl() returns, built from the packaged taxonomy
# so that every code and debit/credit marking is the real one.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")
st <- cvrr:::.structure_for(REF, NULL)

line <- function(el, value, statement, when) {
  s <- st[st$statement == statement & st$elementid == el, ][1, ]
  if (is.na(s$code)) stop("element not in structure: ", el)
  data.frame(elementid = el, value = value, statement = statement,
             code = s$code, balance = s$balance, is_line = TRUE,
             abstract = FALSE, basis = "consolidated",
             period = as.Date(when), stringsAsFactors = FALSE)
}
cf <- function(el, value, when = "2023-12-31")
  line(el, value, "CashFlowStatement", when)
bs <- function(el, value, when = "2023-12-31")
  line(el, value, "BalanceSheetAccountForm", when)

filing <- function(...) {
  x <- rbind(...)
  x$file <- "a.xml"
  x$cvr <- "12345678"
  x$period_start <- as.Date("2023-01-01")
  x$period_end <- as.Date("2023-12-31")
  x$prev_end <- as.Date("2022-12-31")
  x
}

# The shape of Greenland Airports' 2025 group accounts, scaled down: 300 of the
# 1,000 "borrowed" is a grant, and the grant taken to income is tagged in
# investing as a negative sale of a company. Every total adds up.
misclassified <- function(raised = 1000, grant_line = -300, securities = 0) filing(
  cf("CashFlowsFromUsedInOperatingActivities", 100),
  cf("CashFlowsFromUsedInInvestingActivities", -600 + grant_line),
  cf("PurchaseOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities", 600),
  if (grant_line != 0) cf("SaleOfOtherCompany", grant_line),
  cf("CashFlowsFromUsedInFinancingActivities", raised),
  cf("ProceedsFromLongtermLiabilitiesClassifiedAsFinancingActivities", raised),
  cf("NetIncreaseDecreaseInCashAndCashEquivalents", 100 - 600 + grant_line + raised),
  cf("CashAndCashEquivalentsConcerningCashflowStatement", 500, "2022-12-31"),
  cf("CashAndCashEquivalentsConcerningCashflowStatement",
     500 + 100 - 600 + grant_line + raised),
  bs("CashAndCashEquivalents", 500 + 100 - 600 + grant_line + raised - securities),
  if (securities != 0) cf("SharesIncludedAsCashAndCashEquivalents", securities),
  bs("LongtermLiabilitiesOtherThanProvisions", 2000, "2022-12-31"),
  bs("LongtermLiabilitiesOtherThanProvisions", 2700))

verdict <- function(r, check) r$verdict[r$check == check]

test_that("a misclassification passes every internal check", {
  r <- check_cashflow(misclassified())
  expect_equal(verdict(r, "activities"), "agrees")
  expect_equal(verdict(r, "rollforward"), "agrees")
  expect_equal(verdict(r, "cash vs balance"), "agrees")
  expect_equal(verdict(r, "untagged: investing"), "complete")
})

test_that("and is caught against the balance sheet, with its other half named", {
  r <- check_cashflow(misclassified())
  d <- r[r$check == "debt vs balance", ]
  expect_equal(d$verdict, "borrowed more than owed")
  expect_equal(d$residual, 300)
  expect_equal(d$offset_by, "investing: SaleOfOtherCompany")
})

test_that("a sale that took cash out is reported against its element", {
  r <- check_cashflow(misclassified())
  s <- r[startsWith(r$check, "sign:"), ]
  expect_equal(s$elementid, "SaleOfOtherCompany")
  expect_equal(s$verdict, "against its element")
})

test_that("borrowing the balance sheet shows as debt agrees", {
  r <- check_cashflow(misclassified(raised = 700, grant_line = 0))
  expect_equal(verdict(r, "debt vs balance"), "agrees")
  expect_false(any(startsWith(r$check, "sign:")))
})

# A new lease raises the debt without any cash being borrowed. That is the
# common direction and not the suspicious one, and the verdict says which.
test_that("debt that grew by more than was borrowed is told apart", {
  r <- check_cashflow(misclassified(raised = 400, grant_line = 0))
  expect_equal(verdict(r, "debt vs balance"), "owed more than borrowed")
})

test_that("a statement that does not add up is reported", {
  x <- misclassified()
  x$value[x$elementid == "NetIncreaseDecreaseInCashAndCashEquivalents"] <- 999
  r <- check_cashflow(x)
  expect_equal(verdict(r, "activities"), "differs")
  expect_equal(verdict(r, "rollforward"), "differs")
})

# Filers write outflows positive under an outflow element, or negative. The
# taxonomy's marking reads both the same way.
test_that("outflows written as negative figures reconcile too", {
  x <- misclassified(raised = 700, grant_line = 0)
  i <- x$elementid == "PurchaseOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities"
  x$value[i] <- -600
  r <- check_cashflow(x)
  expect_equal(verdict(r, "untagged: investing"), "complete")
})

test_that("securities counted as cash are named as the adjustment", {
  r <- check_cashflow(misclassified(raised = 700, grant_line = 0, securities = 50))
  expect_equal(verdict(r, "cash vs balance"), "agrees, adjusted")
  expect_equal(r$adjustment[r$check == "cash vs balance"], "securities")
})

# A debt that fell by more than was repaid is a reclassification or a
# conversion, not cash from nowhere, and must not be called the other thing.
test_that("debt falling faster than repayments is not borrowing", {
  # 700 repaid, and the debt fell by 1,000.
  x <- misclassified(raised = -700, grant_line = 0)
  i <- x$elementid == "ProceedsFromLongtermLiabilitiesClassifiedAsFinancingActivities"
  x$elementid[i] <- "RepaymentsOfLongtermLiabilitiesClassifiedAsFinancingActivities"
  x$balance[i] <- "credit"
  x$value[i] <- 700
  x$value[x$elementid == "LongtermLiabilitiesOtherThanProvisions" &
            x$period == as.Date("2023-12-31")] <- 1000
  r <- check_cashflow(x)
  expect_equal(verdict(r, "debt vs balance"), "fell more than repaid")
})

# Cash raised while the debt fell is the Greenland pattern in its plainest form.
test_that("borrowing while the debt falls is borrowed more than owed", {
  x <- misclassified(raised = 700, grant_line = 0)
  x$value[x$elementid == "LongtermLiabilitiesOtherThanProvisions" &
            x$period == as.Date("2023-12-31")] <- 1000
  r <- check_cashflow(x)
  expect_equal(verdict(r, "debt vs balance"), "borrowed more than owed")
})

# Danish practice prints the change in cash and then the exchange rate
# adjustment beneath it, whatever the element's name says.
test_that("a roll-forward that needs the exchange rate adjustment says so", {
  x <- misclassified(raised = 700, grant_line = 0)
  i <- x$elementid == "CashAndCashEquivalentsConcerningCashflowStatement" &
    x$period == as.Date("2023-12-31")
  x$value[i] <- x$value[i] + 7
  x$value[x$elementid == "CashAndCashEquivalents"] <- x$value[i]
  x <- rbind(x, filing(cf("ExchangeRateAdjustmentsCashAndCashEquivalents", 7)))
  r <- check_cashflow(x)
  expect_equal(verdict(r, "rollforward"), "agrees, adjusted")
  expect_equal(r$adjustment[r$check == "rollforward"], "exchange rates")
})

test_that("the other ties compare the cash flow with the rest of the filing", {
  x <- rbind(misclassified(raised = 700, grant_line = 0), filing(
    cf("DepreciationAmortisationExpenseAndImpairmentLossesOfPropertyPlantAndEquipmentAndIntangibleAssets", 80),
    line("DepreciationAmortisationExpenseAndImpairmentLossesOfPropertyPlantAndEquipmentAndIntangibleAssetsRecognisedInProfitOrLoss",
         80, "IncomeStatementByNature", "2023-12-31"),
    cf("CashCapitalIncrease", 50),
    bs("ContributedCapital", 100, "2022-12-31"),
    bs("ContributedCapital", 110)))
  r <- check_cashflow(x)
  expect_equal(verdict(r, "depreciation vs income"), "agrees")
  # 50 raised in cash, 10 more capital: cash the equity does not show.
  expect_equal(verdict(r, "capital vs equity"), "cash flow larger")
})

test_that("a filing with no cash flow statement gives no rows", {
  x <- filing(bs("LongtermLiabilitiesOtherThanProvisions", 2700))
  expect_equal(nrow(check_cashflow(x)), 0L)
})

test_that("a frame without the taxonomy is refused with a reason", {
  expect_error(check_cashflow(data.frame(elementid = "x", value = 1)),
               "read_xbrl")
})
