# A frame in the shape read_xbrl() returns: statement lines and the company
# data that belongs to no statement, in one table, the way the fact table
# actually arrives.
REF <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
              "entryDanishGAAPBalanceSheetAccountFormIncomeStatementByNature",
              "IncludingManagementsReviewStatisticsAndTax20231001.xsd")

# The code and the debit/credit marking come from the packaged structure, not
# from a guess: whether the two sides of the balance sheet agree is decided by
# the taxonomy's own marking of each line.
from_taxonomy <- local({
  st <- cvrr:::.structure_for(REF, NULL)
  function(e, statement) {
    s <- st[st$statement == statement, ]
    i <- match(e, s$elementid)
    if (is.na(i)) stop("element not in structure: ", e)
    s[i, ]
  }
})

fact <- function(elementid, fact = NA_character_, value = NA_real_,
                 statement = NA_character_, code = NA_character_,
                 balance = NA_character_, instant = NA, enddate = NA,
                 is_line = TRUE)
  data.frame(elementid = elementid, fact = fact, value = value,
             statement = statement, code = code, depth = 3L,
             label = elementid, balance = balance, is_line = is_line,
             abstract = FALSE, basis = "parent", instant = as.Date(instant),
             enddate = as.Date(enddate),
             period = as.Date(if (is.na(instant)) enddate else instant),
             schemaref = REF, unit = "iso4217:DKK", decimals = "0",
             dimensions = NA_character_, explicit_member = NA_character_,
             stringsAsFactors = FALSE)

bal <- function(el, value) {
  s <- from_taxonomy(el, "BalanceSheetAccountForm")
  fact(el, value = value, statement = "BalanceSheetAccountForm",
       code = s$code, balance = s$balance, instant = "2023-12-31")
}

inc <- function(el, value) {
  s <- from_taxonomy(el, "IncomeStatementByNature")
  fact(el, value = value, statement = "IncomeStatementByNature",
       code = s$code, balance = s$balance, enddate = "2023-12-31")
}

filing <- function(..., file = "a.xml", cvr = "12345678") {
  x <- rbind(
    fact("IdentificationNumberCvrOfReportingEntity", cvr),
    fact("NameOfReportingEntity", "Testselskabet ApS"),
    fact("ClassOfReportingEntity", "Regnskabsklasse B"),
    ...)
  x$file <- file
  x$cvr  <- cvr
  x$period_start <- as.Date("2023-01-01")
  x$period_end   <- as.Date("2023-12-31")
  x$prev_start   <- as.Date(NA)
  x$prev_end     <- as.Date("2022-12-31")
  x
}

# A balance sheet whose two sides agree, so it reconciles.
balanced <- function(file = "a.xml", cvr = "12345678")
  filing(bal("Assets", 1000), bal("LiabilitiesAndEquity", 1000),
         bal("Equity", 400), bal("Provisions", 100),
         bal("ShorttermLiabilitiesOtherThanProvisions", 500),
         inc("GrossProfitLoss", 800),
         file = file, cvr = cvr)

test_that("the tables come back, named and keyed", {
  a <- xbrl_accounts(balanced())

  expect_s3_class(a, "cvrr_accounts")
  expect_named(a, c("company", "location", "audit", "checks",
                    "income_statement", "balance", "movements", "prose"))
  for (nm in names(a))
    expect_true(all(c("cvr", "period_end") %in% names(a[[nm]])), info = nm)
})

test_that("what = picks out one table and only that one", {
  a <- xbrl_accounts(balanced(), what = "company")
  expect_named(a, "company")
  expect_equal(nrow(a$company), 1L)
})

test_that("each filing gets its own row, and its own figures", {
  x <- rbind(balanced("a.xml", "11111111"), balanced("b.xml", "22222222"))
  a <- xbrl_accounts(x)

  expect_equal(nrow(a$company), 2L)
  expect_equal(sort(a$company$cvr), c("11111111", "22222222"))
  expect_equal(sort(unique(a$balance$file)), c("a.xml", "b.xml"))
})

# The verdict is per filing and per statement, which is the grain of the
# question "can I trust this one".
test_that("a balance sheet that adds up is marked as reconciled", {
  a <- xbrl_accounts(balanced())

  expect_true(a$checks$balance_reconciled)
  expect_true(all(a$balance$reconciled))
})

test_that("a balance sheet whose sides differ is marked, and not dropped", {
  x <- filing(bal("Assets", 1000), bal("LiabilitiesAndEquity", 900),
              bal("Equity", 900))
  a <- xbrl_accounts(x)

  expect_false(a$checks$balance_reconciled)
  expect_gt(nrow(a$balance), 0)
  expect_true(all(!a$balance$reconciled))
})

# A filing can have a balance sheet that adds up and an income statement that
# does not. The two verdicts are separate columns and one never speaks for the
# other, so a broken balance sheet must leave the income statement's verdict
# exactly where it was.
test_that("the two statements are judged independently", {
  good <- xbrl_accounts(balanced())
  bad  <- xbrl_accounts(filing(bal("Assets", 1000),
                               bal("LiabilitiesAndEquity", 900),
                               bal("Equity", 900),
                               inc("GrossProfitLoss", 800)))

  expect_true(good$checks$balance_reconciled)
  expect_false(bad$checks$balance_reconciled)
  expect_equal(bad$checks$income_reconciled, good$checks$income_reconciled)
})

test_that("company data survives having no statement of its own", {
  # These facts belong to no statement in the taxonomy. Dropping them, which is
  # what the old pipeline did, meant reading every filing a second time.
  a <- xbrl_accounts(balanced())
  expect_equal(a$company$name, "Testselskabet ApS")
  expect_equal(a$company$class, "B")
})

test_that("print says how many filings and how big each table is", {
  a <- xbrl_accounts(balanced())
  out <- paste(capture.output(print(a)), collapse = "\n")

  expect_match(out, "cvrr accounts")
  expect_match(out, "1 filing")
  expect_match(out, "company")
  expect_match(out, "balance")
})

test_that("filings that could not be read are carried through", {
  x <- balanced()
  attr(x, "failed") <- "broken.xml"
  a <- xbrl_accounts(x)

  expect_equal(attr(a, "failed"), "broken.xml")
  expect_match(paste(capture.output(print(a)), collapse = "\n"),
               "could not be read")
})

test_that("a frame that is not from read_xbrl is refused with a reason", {
  expect_error(xbrl_accounts(data.frame(elementid = "Assets")), "read_xbrl")
})

# The note has verdicts of its own, and they are not the statements'. A
# balance sheet that closes says nothing about whether the fixed asset
# schedule rolls forward, so the two are never the same column.
test_that("the movements table brings its own verdicts", {
  a <- xbrl_accounts(balanced())
  expect_true(all(c("reconciled", "covers_balance", "continuous") %in%
                    names(a$movements)))
})

# The verdicts are not attributes of a company -- they are what the checks
# concluded about one filing -- so they live together in their own table, and
# the company row is the company.
test_that("the verdicts are gathered in checks, not on the company row", {
  a <- xbrl_accounts(balanced())
  verdicts <- c("income_reconciled", "balance_reconciled",
                "movements_reconciled", "movements_cover")

  expect_true(all(verdicts %in% names(a$checks)))
  expect_false(any(verdicts %in% names(a$company)))
})

# The prose runs to hundreds of characters and the audit trail is fifteen
# columns; neither belongs beside the accounting class.
test_that("the company row is narrowed to who the company is", {
  a <- xbrl_accounts(balanced())

  expect_false("development" %in% names(a$company))
  expect_false("audit_firm" %in% names(a$company))
  expect_true("development" %in% names(a$prose))
  expect_true("audit_firm" %in% names(a$audit))
})

# Every table opens the same way, so moving between them needs no looking.
test_that("the key comes first, and is the same everywhere", {
  a <- xbrl_accounts(balanced())
  for (nm in names(a)) {
    expect_equal(names(a[[nm]])[1:4], cvrr:::.KEYS, info = nm)
    # And the path last: it is where the row came from, not what it is.
    expect_equal(utils::tail(names(a[[nm]]), 1), "file", info = nm)
  }
})

test_that("a filing with no fixed asset note gets NA, not FALSE", {
  a <- xbrl_accounts(balanced())
  expect_true(is.na(a$checks$movements_reconciled))
  expect_true(is.na(a$checks$movements_cover))
})

# One unchecked block must not decide the filing: the question is whether
# everything checkable passed.
test_that("an unchecked block does not make the filing NA", {
  expect_equal(cvrr:::.by_file(c(TRUE, NA), c("a", "a")), c(a = TRUE))
  expect_equal(cvrr:::.by_file(c(FALSE, NA), c("a", "a")), c(a = FALSE))
  expect_equal(cvrr:::.by_file(c(NA, NA), c("a", "a")), c(a = NA))
})

# What a stage says when it finishes is how the figures held up, not how many
# seconds it took -- and at the grain the question is asked. A statement
# reconciles per filing; a fixed asset note per class and per layer, so calling
# those filings would overstate what was checked.
test_that("a stage reports its size and its verdict", {
  d <- data.frame(file = c("a", "a", "b"), reconciled = c(TRUE, TRUE, FALSE))
  expect_equal(cvrr:::.stage_note(d), "3 rows, 1 of 2 filings reconcile")

  n <- data.frame(file = "a", category = "tangible", class = NA,
                  layer = c("cost", "depreciation"), reconciled = c(TRUE, FALSE))
  expect_equal(cvrr:::.stage_note(n), "2 rows, 1 of 2 blocks reconcile")
})

test_that("a stage with no verdict to give says only its size", {
  expect_equal(cvrr:::.stage_note(data.frame(a = 1:4)), "4 rows")
  expect_match(cvrr:::.stage_note(data.frame(file = "a", reconciled = NA)),
               "none with anything to check")
})
