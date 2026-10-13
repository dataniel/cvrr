# A filing in the shape read_xbrl() returns. Company data is text, so unlike
# the figure tests there is no `value` column to fill.
row <- function(el, fact, enddate = NA_character_, instant = NA_character_)
  data.frame(elementid = el, fact = fact, enddate = as.Date(enddate),
             instant = as.Date(instant), decimals = NA_character_,
             stringsAsFactors = FALSE)

END <- as.Date("2023-12-31")
period_rows <- rbind(
  row("ReportingPeriodStartDate", "2023-01-01"),
  row("ReportingPeriodEndDate", "2023-12-31"),
  row("PredingReportingPeriodEndDate", "2022-12-31"))
period_rows$decimals <- NA_character_

# read_xbrl() stamps the filing's own identity and declared period on every
# row; xbrl_company() reads them from there rather than working them out again.
filing <- function(..., file = "a.xml") {
  x <- rbind(period_rows, ...)
  cvr <- x$fact[x$elementid == "IdentificationNumberCvrOfReportingEntity"]
  x$file <- file
  x$cvr <- if (length(cvr)) cvr[1] else NA_character_
  x$period_start <- as.Date("2023-01-01")
  x$period_end   <- END
  x$prev_start   <- as.Date(NA)
  x$prev_end     <- as.Date("2022-12-31")
  x
}

test_that("the identity and the period come back", {
  x <- filing(
    row("IdentificationNumberCvrOfReportingEntity", "12345674"),
    row("NameOfReportingEntity", "Testselskabet ApS"),
    row("ClassOfReportingEntity", "Regnskabsklasse B"))
  r <- xbrl_company(x)
  expect_equal(r$cvr, "12345674")
  expect_equal(r$name, "Testselskabet ApS")
  expect_equal(r$reporting_class, "Regnskabsklasse B")
  expect_equal(r$period_start, as.Date("2023-01-01"))
  expect_equal(r$period_end, END)
  expect_equal(nrow(r), 1L)
})

test_that("a street is built from both of its elements, or from neither", {
  x <- filing(row("AddressOfReportingEntityStreetName", "Sipisaq Avannarleq"),
              row("AddressOfReportingEntityStreetBuildingIdentifier", "4"))
  expect_equal(xbrl_company(x)$street, "Sipisaq Avannarleq 4")

  expect_true(is.na(xbrl_company(filing())$street))

  # One half is still an address, not a blank.
  y <- filing(row("AddressOfReportingEntityStreetName", "Hovedgaden"))
  expect_equal(xbrl_company(y)$street, "Hovedgaden")
})

test_that("employees come back as a number", {
  x <- filing(row("AverageNumberOfEmployees", "17", enddate = END))
  r <- xbrl_company(x)
  expect_identical(r$employees, 17)
  expect_true(is.na(xbrl_company(filing())$employees))
})

test_that("the year's own value wins over a comparative", {
  x <- filing(
    row("AverageNumberOfEmployees", "9", enddate = "2022-12-31"),
    row("AverageNumberOfEmployees", "17", enddate = END))
  expect_identical(xbrl_company(x)$employees, 17)
})

test_that("a fact dated differently is still read rather than lost", {
  # Some filers tag company data against no period the function knows. Falling
  # back to whatever is there beats returning NA for a stated fact.
  x <- filing(row("NameOfAuditFirm", "Revisionsfirmaet ApS",
                  enddate = "2019-06-30"))
  expect_equal(xbrl_company(x)$audit_firm, "Revisionsfirmaet ApS")
})

test_that("the activity is read from the element companies actually use", {
  # DescriptionOfPrimaryActivitiesOfEntity is used by 72% of filings and the
  # obvious-sounding DisclosureOfMainActivities... by 7%, so the first is
  # preferred and the second is the fallback.
  a <- filing(row("DescriptionOfPrimaryActivitiesOfEntity", "Flaskevand."))
  expect_equal(xbrl_company(a)$activity, "Flaskevand.")
  expect_equal(xbrl_company(a)$activity_source, "primary activities")

  b <- filing(row("DisclosureOfMainActivitiesAndAccountingAndFinancialMatters",
                  "Handel."))
  expect_equal(xbrl_company(b)$activity, "Handel.")
  expect_equal(xbrl_company(b)$activity_source, "main activities disclosure")

  both <- filing(row("DescriptionOfPrimaryActivitiesOfEntity", "Flaskevand."),
                 row("DisclosureOfMainActivitiesAndAccountingAndFinancialMatters",
                     "Handel."))
  expect_equal(xbrl_company(both)$activity, "Flaskevand.")
})

test_that("the year's development falls back to the review, and says so", {
  a <- filing(row("DescriptionOfDevelopmentInActivitiesAndFinancialAffairs",
                  "Et tilfredsstillende aar."))
  expect_equal(xbrl_company(a)$development_source, "development described")

  b <- filing(row("ManagementsReview", "Lang beretning."))
  expect_equal(xbrl_company(b)$development, "Lang beretning.")
  expect_equal(xbrl_company(b)$development_source, "management's review")
})

test_that("persons are left out unless asked for", {
  x <- filing(row("NameAndSurnameOfAuditor", "A Revisor"),
              row("NameOfAuditFirm", "Revisionsfirmaet ApS"))
  r <- xbrl_company(x)
  expect_false("auditor_name" %in% names(r))
  expect_equal(r$audit_firm, "Revisionsfirmaet ApS")

  p <- xbrl_company(x, persons = TRUE)
  expect_equal(p$auditor_name, "A Revisor")
})

test_that("a board with several members is joined, not truncated", {
  x <- filing(row("NameAndSurnameOfMemberOfExecutiveBoard", "A Direktoer"),
              row("NameAndSurnameOfMemberOfExecutiveBoard", "B Direktoer"))
  expect_equal(xbrl_company(x, persons = TRUE)$executive_board,
               "A Direktoer; B Direktoer")
})

test_that("the same name tagged twice is one member, not two", {
  x <- filing(row("NameAndSurnameOfMemberOfExecutiveBoard", "A Direktoer"),
              row("NameAndSurnameOfMemberOfExecutiveBoard", "A Direktoer"))
  expect_equal(xbrl_company(x, persons = TRUE)$executive_board, "A Direktoer")
})

test_that("prose can be left out to keep the row narrow", {
  x <- filing(row("DescriptionOfPrimaryActivitiesOfEntity", "Flaskevand."))
  expect_false("activity" %in% names(xbrl_company(x, prose = FALSE)))
})

test_that("no industry column is returned, because no filing states one", {
  # The taxonomy has a place for it and nothing in 4,304 filings uses it. An
  # always-empty column would read as "unknown" rather than "never asked for".
  r <- xbrl_company(filing())
  expect_false(any(grepl("industry|branch", names(r), ignore.case = TRUE)))
})

test_that("a filing that is not from read_xbrl is refused with a reason", {
  expect_error(xbrl_company(data.frame(a = 1)), "read_xbrl")
})

test_that("empty and whitespace facts count as absent", {
  x <- filing(row("NameOfReportingEntity", "   "),
              row("NameOfAuditFirm", ""))
  r <- xbrl_company(x)
  expect_true(is.na(r$name))
  expect_true(is.na(r$audit_firm))
})

test_that("a headcount tagged to the nearest thousand is rescaled", {
  # Six facts in the corpus carry decimals = "-3" on the number of employees,
  # and all six are the two filings claiming 151,000 or 2,286,000 employees.
  # No plausible fact carries it. The filer's tool applied the statement's
  # thousands-scaling to a count.
  x <- filing(data.frame(elementid = "AverageNumberOfEmployees",
                         fact = "2286000", enddate = END,
                         instant = as.Date(NA), decimals = "-3",
                         stringsAsFactors = FALSE))
  expect_identical(xbrl_company(x)$employees, 2286)
})

test_that("an ordinary headcount is left exactly as stated", {
  for (dec in c("0", "1", "3", "INF", NA_character_)) {
    x <- filing(data.frame(elementid = "AverageNumberOfEmployees",
                           fact = "17", enddate = END, instant = as.Date(NA),
                           decimals = dec, stringsAsFactors = FALSE))
    expect_identical(xbrl_company(x)$employees, 17)
  }
})

test_that("the accounting class letter survives the filing's language", {
  da <- filing(row("ClassOfReportingEntity", "Regnskabsklasse B, mikrovirksomhed"))
  en <- filing(row("ClassOfReportingEntity", "Reporting class B, micro-undertaking"))
  expect_equal(xbrl_company(da)$class, "B")
  expect_equal(xbrl_company(en)$class, "B")
  # The verbatim field keeps what the filing said, micro and all.
  expect_equal(xbrl_company(da)$reporting_class,
               "Regnskabsklasse B, mikrovirksomhed")

  expect_equal(xbrl_company(filing(row("ClassOfReportingEntity",
                                       "Regnskabsklasse D")))$class, "D")
  expect_true(is.na(xbrl_company(filing())$class))
})

test_that("the filing's currency is reported alongside its background", {
  x <- filing(row("NameOfReportingEntity", "Testselskabet ApS"))
  x$unit <- "iso4217:CAD"
  expect_equal(xbrl_company(x)$currency, "CAD")

  y <- filing(row("NameOfReportingEntity", "Testselskabet ApS"))
  expect_true(is.na(xbrl_company(y)$currency))
})

test_that("the accounting firm that filed it is reported", {
  # Almost always an accounting firm, and which one explains a good deal of
  # the systematic variation in how a filing is tagged.
  x <- filing(row("NameOfSubmittingEnterprise", "Groenlands Revision A/S"),
              row("IdentificationNumberCvrOfSubmittingEnterprise", "12345674"))
  r <- xbrl_company(x)
  expect_equal(r$submitter, "Groenlands Revision A/S")
  expect_equal(r$submitter_cvr, "12345674")
})

test_that("approval and signature dates come back", {
  x <- filing(row("DateOfApprovalOfAnnualReport", "2024-05-20"),
              row("PlaceOfSignatureOfStatement", "Nuuk"),
              row("SignatureOfAuditorsDate", "2024-05-18"))
  r <- xbrl_company(x)
  expect_equal(r$approved, as.Date("2024-05-20"))
  expect_equal(r$signature_place, "Nuuk")
  expect_equal(r$auditor_signed, as.Date("2024-05-18"))
})

test_that("a qualified audit opinion is visible", {
  # "Konklusion" is a clean opinion and "Konklusion med forbehold" a qualified
  # one. Nothing else in the filing says so.
  clean <- filing(row("TypeOfModifiedOpinionOnAuditedFinancialStatements",
                      "Konklusion"))
  expect_equal(xbrl_company(clean)$opinion, "Konklusion")

  qual <- filing(row("TypeOfModifiedOpinionOnAuditedFinancialStatements",
                     "Konklusion med forbehold"))
  expect_equal(xbrl_company(qual)$opinion, "Konklusion med forbehold")
})

test_that("the taxonomy flags are read as logicals, however they are written", {
  # Filers write "true", "false" and "1"; all three occur.
  t1 <- filing(row("AccountingPoliciesAreUnchangedFromPreviousPeriod", "true"))
  expect_true(xbrl_company(t1)$policies_unchanged)

  t2 <- filing(row("AccountingPoliciesAreUnchangedFromPreviousPeriod", "false"))
  expect_false(xbrl_company(t2)$policies_unchanged)

  t3 <- filing(row("SelectedElementsFromReportingClassC", "1"))
  expect_true(xbrl_company(t3)$class_c_elements)

  expect_true(is.na(xbrl_company(filing())$policies_unchanged))
})

test_that("opting out of an audit shows as a flag, not as prose", {
  x <- filing(row(paste0("ConfirmationThatFinancialStatementsAreExempted",
                         "FromAuditing"),
                  "Ledelsen anser betingelserne for at udelade revision..."))
  expect_true(xbrl_company(x)$audit_exempt)
  expect_false(xbrl_company(filing())$audit_exempt)
})

test_that("assets used but not owned come back as a number", {
  x <- filing(row("RecognisedButNotOwnedAssets", "402369369"))
  expect_identical(xbrl_company(x)$assets_not_owned, 402369369)
})

test_that("the off-balance-sheet disclosures travel with the prose", {
  x <- filing(row("DisclosureOfMortgagesAndCollaterals", "Pantsat til banken."),
              row("DisclosureOfContingentLiabilities", "Kaution for datter."))
  r <- xbrl_company(x)
  expect_equal(r$mortgages, "Pantsat til banken.")
  expect_equal(r$contingent_liabilities, "Kaution for datter.")
  expect_false("mortgages" %in% names(xbrl_company(x, prose = FALSE)))
})


# The taxonomy has no element for the reporting entity's own legal form --
# RelatedEntityLegalForm is about the companies a filer is related to -- and
# across 4,304 filings not one uses an industry element either. Both have to
# come from outside the filing. But Danish and Greenlandic company law puts the
# form in the name, so it can be read rather than guessed: 98.4% of names carry
# a recognisable one.
test_that("the legal form is read off the name", {
  expect_equal(cvrr:::.company_form("Nuuk Købmandshandel A/S"), "A/S")
  expect_equal(cvrr:::.company_form("Testselskabet ApS"), "ApS")
  expect_equal(cvrr:::.company_form("K/S Nordlys"), "K/S")
  expect_equal(cvrr:::.company_form("Fonden Sermitsiaq"), "Fond")

  # Compounds: the form is inside a word, which is why the spelled-out names
  # are matched as substrings and the abbreviations are not.
  expect_equal(cvrr:::.company_form("Ejendomsaktieselskabet Illuut"), "A/S")
  expect_equal(cvrr:::.company_form("Anpartsselskabet af 1/9 2005"), "ApS")

  expect_true(is.na(cvrr:::.company_form("Ukendt Navn")))
  expect_true(is.na(cvrr:::.company_form(NA_character_)))
})

# Escaping the slash to be safe turned it into a wildcard, so the pattern for
# "A/S" matched "ApS". Nothing here holds a regex metacharacter.
test_that("ApS is not read as A/S", {
  expect_equal(cvrr:::.company_form("Grønlands Handel ApS"), "ApS")
  expect_equal(cvrr:::.company_form("Grønlands Handel A/S"), "A/S")
})
