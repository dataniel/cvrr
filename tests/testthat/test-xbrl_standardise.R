# Two years of one company, as read_xbrl() returns them.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")
fact <- function(el, value, when, file, end)
  data.frame(file = file, cvr = "12345678", elementid = el, value = value,
             fact = as.character(value), statement = "BalanceSheetAccountForm",
             is_line = TRUE, abstract = FALSE, basis = "parent",
             period = as.Date(when), instant = as.Date(when),
             startdate = as.Date(NA), enddate = as.Date(NA),
             period_start = as.Date(end) - 364, period_end = as.Date(end),
             prev_end = as.Date(end) - 365, dimensions = NA_character_,
             stringsAsFactors = FALSE)

# 2023 closes on land of 2,981,848. The 2024 filing states its own 2024 land
# in kroner and its 2023 comparative in thousands: 2,982.
two_years <- function(own_2024 = 3100000, comparative = 2982) rbind(
  fact("LandAndBuildings", 2981848, "2023-12-31", "a.xml", "2023-12-31"),
  fact("LandAndBuildings", comparative, "2023-12-31", "b.xml", "2024-12-31"),
  fact("LandAndBuildings", own_2024, "2024-12-31", "b.xml", "2024-12-31"))

test_that("a comparative the filing contradicts itself on is put back", {
  x <- suppressMessages(xbrl_standardise(two_years()))
  i <- x$file == "b.xml" & x$period == as.Date("2023-12-31")
  expect_equal(x$value[i], 2982000)
  expect_equal(x$value_tagged[i], 2982)
  expect_match(x$standardised[i], "x1,000")
  # Nothing else moves.
  expect_true(all(is.na(x$standardised[!i])))
  expect_equal(x$value[!i], x$value_tagged[!i])
  expect_equal(attr(x, "standardisation")$action, "corrected comparative")
})

# The later filing's two columns agree, both in thousands: either it is tagged
# in thousands throughout or the earlier one is wrong, and nothing here can
# tell which.
test_that("a disagreement the later filing does not contradict is left alone", {
  x <- suppressMessages(xbrl_standardise(two_years(own_2024 = 3100)))
  expect_equal(x$value, x$value_tagged)
  expect_equal(attr(x, "standardisation")$action, "undecided")
})

# Nought is in no unit. The ratio's floor of one made nought then a thousand
# look like a factor of a thousand.
test_that("a nil is never read as a figure in the other unit", {
  x <- two_years(comparative = 1000)
  x$value[x$file == "a.xml"] <- 0
  cc <- check_continuity(x, filing = "period_end")
  expect_false("scaled" %in% cc$verdict)
})

test_that("check_continuity() writes an instant as a date, not a day count", {
  cc <- check_continuity(two_years(), filing = "period_end")
  expect_equal(cc$period, "2023-12-31")
})

test_that("one filing per company has nothing to compare", {
  x <- two_years()[1, ]
  out <- suppressMessages(xbrl_standardise(x))
  expect_equal(out$value, x$value)
  expect_equal(nrow(attr(out, "standardisation")), 0L)
})

# ---- signs in the cash flow statement ---------------------------------------

st <- cvrr:::.structure_for(REF, NULL)
cf <- function(el, value) {
  s <- st[st$statement == "CashFlowStatement" & st$elementid == el, ][1, ]
  r <- fact(el, value, "2023-12-31", "a.xml", "2023-12-31")
  r$statement <- "CashFlowStatement"; r$code <- s$code; r$balance <- s$balance
  r$instant <- as.Date(NA)
  r
}
# Investing of -900: purchases of 600 and 400 written as positive outflows,
# a sale of 100 as an inflow. `sale` lets the sale be written the wrong way.
investing <- function(sale = 100, total = -900, extra = NULL)
  do.call(rbind, c(list(
    cf("CashFlowsFromUsedInInvestingActivities", total),
    cf("PurchaseOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities", 600),
    cf("PurchaseOfIntangibleAssetsClassifiedAsInvestingActivities", 400),
    cf("ProceedsFromSalesOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities", sale)),
    extra))

test_that("a sign the activity only adds up without is reversed", {
  # The sale written as -100: the activity sums to -1,100, not -900.
  x <- suppressMessages(xbrl_standardise(investing(sale = -100), what = "signs"))
  i <- x$elementid == "ProceedsFromSalesOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities"
  expect_equal(x$value[i], 100)
  expect_equal(x$value_tagged[i], -100)
  expect_match(x$standardised[i], "investing adds up")
  expect_equal(attr(x, "standardisation")$action, "flipped sign")
})

# Greenland Airports' case: a sale of a company reported negative, in an
# investing activity that adds up with it. The sign means something; it is
# the classification that is wrong, and that is for the screen to find.
test_that("a contrary sign the activity adds up with is left alone", {
  x <- investing(total = -1200,
                 extra = list(cf("SaleOfOtherCompany", -300)))
  out <- suppressMessages(xbrl_standardise(x, what = "signs"))
  expect_equal(out$value, out$value_tagged)
  expect_equal(nrow(attr(out, "standardisation")), 0L)
})

# Two sales of 100 each, and an activity stated at -1,000 against -800 as
# tagged: reversing either sale would do, so neither is.
test_that("a sign that any of several lines could explain is undecided", {
  x <- investing(total = -1000, extra = list(
    cf("ProceedsFromSalesOfIntangibleAssetsClassifiedAsInvestingActivities", 100)))
  out <- suppressMessages(xbrl_standardise(x, what = "signs"))
  expect_equal(out$value, out$value_tagged)
  expect_equal(attr(out, "standardisation")$action, "undecided")
})
