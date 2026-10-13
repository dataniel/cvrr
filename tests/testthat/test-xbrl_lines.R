# A frame in the shape read_xbrl() returns: one row per statement line, with
# the hierarchy's code, the flags the statement is read through, and the
# filing's own identity and declared period end.
line <- function(elementid, code, value, period = "2023-12-31",
                 basis = "parent", is_line = TRUE, abstract = FALSE,
                 statement = "BalanceSheetAccountForm",
                 file = "a.xml", cvr = "12345678")
  data.frame(file = file, cvr = cvr,
             period_start = as.Date("2023-01-01"),
             period_end = as.Date("2023-12-31"),
             statement = statement, code = code, depth = 3L,
             elementid = elementid, label = elementid, value = value,
             is_line = is_line, abstract = abstract, basis = basis,
             period = as.Date(period), schemaref = REF, unit = "iso4217:DKK",
             dimensions = NA_character_, explicit_member = NA_character_,
             stringsAsFactors = FALSE)

# A real schemaRef -- the entry point most of the corpus declares -- so the
# packaged structure tables resolve and the codes are the taxonomy's own.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")

codes <- function() {
  st <- cvrr:::.structure_for(REF, NULL)
  st <- st[st$statement == "BalanceSheetAccountForm", ]
  function(e) {
    i <- match(e, st$elementid)
    if (is.na(i)) stop("element not in structure: ", e)
    st$code[i]
  }
}
cd <- codes()

test_that("the balance sheet comes back in statement order", {
  x <- rbind(line("Assets", cd("Assets"), 1000),
             line("Equity", cd("Equity"), 400))
  b <- xbrl_lines(x, "balance", fill = FALSE)
  expect_equal(nrow(b), 2L)
  expect_equal(b$code, sort(b$code))
  expect_true(all(b$source == "reported"))
  expect_true(all(b$currency == "DKK"))
})

test_that("only one column and one date are returned", {
  x <- rbind(
    line("Assets", cd("Assets"), 1000),
    line("Assets", cd("Assets"), 900, period = "2022-12-31"),
    line("Assets", cd("Assets"), 5000, basis = "consolidated"))
  b <- xbrl_lines(x, "balance", fill = FALSE)
  expect_equal(b$value, 1000)

  g <- xbrl_lines(x, "balance", basis = "consolidated", fill = FALSE)
  expect_equal(g$value, 5000)
})

# The whole point of taking a directory at once: two filings must not solve
# each other's identities.
test_that("filings are kept apart", {
  x <- rbind(
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 1000, file = "a.xml",
         cvr = "11111111"),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 700, file = "a.xml",
         cvr = "11111111"),
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 500, file = "b.xml",
         cvr = "22222222"))
  b <- xbrl_lines(x, "balance")

  lt <- b[b$elementid == "LongtermLiabilitiesOtherThanProvisions", ]
  expect_equal(nrow(lt), 1L)
  expect_equal(lt$file, "a.xml")
  expect_equal(lt$value, 300)
  expect_equal(sort(unique(b$cvr)), c("11111111", "22222222"))
})

# The income statement is a cascade, not a partition: summing components into a
# subtotal would count the same krone twice.
test_that("nothing is derived outside the balance sheet", {
  x <- rbind(
    line("GrossProfitLoss", "300.00.010", 1000,
         statement = "IncomeStatementByNature"),
    line("EmployeeBenefitsExpense", "300.00.020", 400,
         statement = "IncomeStatementByNature"))
  b <- xbrl_lines(x, "income")

  expect_equal(nrow(b), 2L)
  expect_true(all(b$source == "reported"))
})

test_that("an alias picks up whichever presentation the filer used", {
  by_function <- line("GrossProfitLoss", "300.00.010", 1000,
                      statement = "IncomeStatementByFunction")
  expect_equal(nrow(xbrl_lines(by_function, "income")), 1L)

  # and a taxonomy statement name passes straight through
  expect_equal(nrow(xbrl_lines(by_function, "IncomeStatementByFunction")), 1L)
  expect_equal(nrow(xbrl_lines(by_function, "IncomeStatementByNature")), 0L)
})

test_that("a breakdown is not mistaken for the line it breaks down", {
  x <- rbind(
    line("PropertyPlantAndEquipment", cd("PropertyPlantAndEquipment"), 1000),
    line("PropertyPlantAndEquipment", cd("PropertyPlantAndEquipment"), 600,
         is_line = FALSE))
  b <- xbrl_lines(x, "balance", fill = FALSE)
  expect_equal(b$value, 1000)
})

test_that("long-term debt is recovered from the total and the short-term part", {
  # The case the hierarchy walk cannot reach: LiabilitiesOtherThanProvisions
  # has 33 children presenting the same debts by kind and by term, so summing
  # the nearest reported counts every krone twice.
  x <- rbind(
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 1000),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 700))
  b <- xbrl_lines(x, "balance")
  lt <- b[b$elementid == "LongtermLiabilitiesOtherThanProvisions", ]
  expect_equal(nrow(lt), 1L)
  expect_equal(lt$value, 300)
  expect_equal(lt$source, "derived: identity")
})

test_that("a company with no long-term debt gets nought, not a gap", {
  # 2,071 filings of the corpus state the total and the short-term part and
  # nothing else, because there is nothing else. The identity says so.
  x <- rbind(
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 700),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 700))
  b <- xbrl_lines(x, "balance")
  lt <- b[b$elementid == "LongtermLiabilitiesOtherThanProvisions", ]
  expect_equal(lt$value, 0)
  expect_equal(lt$source, "derived: identity")
})

test_that("a solved term unlocks the next identity", {
  # Liabilities comes from the balance sheet total, and long-term debt then
  # comes from Liabilities. Two passes, one call.
  x <- rbind(
    line("LiabilitiesAndEquity", cd("LiabilitiesAndEquity"), 1000),
    line("Equity", cd("Equity"), 300),
    line("Provisions", cd("Provisions"), 100),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 500))
  b <- xbrl_lines(x, "balance")
  expect_equal(b$value[b$elementid == "LiabilitiesOtherThanProvisions"], 600)
  expect_equal(b$value[b$elementid == "LongtermLiabilitiesOtherThanProvisions"],
               100)
})

test_that("nothing is derived where two terms are missing", {
  x <- rbind(line("LiabilitiesAndEquity", cd("LiabilitiesAndEquity"), 1000),
             line("Equity", cd("Equity"), 300))
  b <- xbrl_lines(x, "balance")
  expect_false("LiabilitiesOtherThanProvisions" %in% b$elementid)
  expect_false("Provisions" %in% b$elementid)
})

test_that("a reported figure is never overwritten by a derived one", {
  x <- rbind(
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 1000),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 700),
    line("LongtermLiabilitiesOtherThanProvisions",
         cd("LongtermLiabilitiesOtherThanProvisions"), 250))
  b <- xbrl_lines(x, "balance")
  lt <- b[b$elementid == "LongtermLiabilitiesOtherThanProvisions", ]
  expect_equal(nrow(lt), 1L)
  expect_equal(lt$value, 250)
  expect_equal(lt$source, "reported")
})

test_that("fill = FALSE returns only what the filing stated", {
  x <- rbind(
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 1000),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 700))
  b <- xbrl_lines(x, "balance", fill = FALSE)
  expect_equal(nrow(b), 2L)
  expect_true(all(b$source == "reported"))
})

test_that("a frame that is not from read_xbrl is refused with a reason", {
  expect_error(xbrl_lines(data.frame(elementid = "Assets", value = 1)),
               "add_taxonomy")
})

test_that("a filing with no balance sheet returns an empty frame, not an error", {
  x <- line("Revenue", "501.00.020.010", 5000,
            statement = "IncomeStatementByNature")
  b <- xbrl_lines(x, "balance")
  expect_equal(nrow(b), 0L)
  expect_true(all(c("code", "elementid", "value", "source") %in% names(b)))
})

# The identity rows have to keep their source across xbrl_fill(), which resets
# it. Carried on a column of its own: matching the rows back afterwards on
# paste(elementid, value) keys on a floating-point number rendered as text, and
# two lines of one statement holding the same amount is ordinary.
test_that("a derived source survives filling, even when amounts repeat", {
  x <- rbind(
    line("LiabilitiesOtherThanProvisions",
         cd("LiabilitiesOtherThanProvisions"), 1000),
    line("ShorttermLiabilitiesOtherThanProvisions",
         cd("ShorttermLiabilitiesOtherThanProvisions"), 500),
    # Equity holds the same amount as the short-term debt. Under the old
    # string key these two rows were indistinguishable.
    line("Equity", cd("Equity"), 500))
  b <- xbrl_lines(x, "balance")

  lt <- b[b$elementid == "LongtermLiabilitiesOtherThanProvisions", ]
  expect_equal(lt$value, 500)
  expect_equal(lt$source, "derived: identity")
  expect_equal(b$source[b$elementid == "Equity"], "reported")
  expect_false(".source_in" %in% names(b))
})
