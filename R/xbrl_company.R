#' The company behind a filing: who, how big, audited how, and doing what
#'
#' The background a set of accounts needs to be usable as statistics --
#' identity, period, accounting class, auditor, employees, and the management's
#' own description of what the company does and how the year went. One row per
#' filing, ready to sit beside [xbrl_lines()] and [xbrl_movements()].
#'
#' @section What a filing reliably carries:
#' Measured over 4,304 Danish and Greenlandic filings. Present in every one:
#' the CVR number, the company's name, the accounting class, the type of
#' auditor's assistance and the reporting period; the date of the general
#' meeting is there in all but two. Then, in falling order: the executive
#' board's names (94%), the address (82%), what the company does (79%), the
#' audit firm and its CVR number (78%), how the year went (76%), the average
#' number of employees (74%), when the company was founded (47%) and its
#' registered office (45%). 99% say something about either their activity or
#' their year.
#'
#' The two prose figures are what this function returns, not what any single
#' element carries -- both fall back to a second element, and the `_source`
#' columns say which answered.
#'
#' @section The industry is not in the filing:
#' The taxonomy has a place for it -- `IndustrySectorForEconomicActivitiesOfEntity`
#' -- and **not one filing of 4,304 uses it**. Nor does any use
#' `SizeOfReportingEntityBySector`. A company's industry has to come from the
#' register instead, where it arrives as a code and a label in one field.
#' No column is returned for it here, because a column that is empty
#' in every row is worse than an absent one: it invites the reader to conclude
#' the industry is unknown rather than that it was never asked for.
#'
#' @section The legal form is not in the filing either, but the name has it:
#' The taxonomy has no element for the reporting entity's own legal form.
#' `RelatedEntityLegalForm` exists and is about the companies a filer is
#' related to; there is nothing that says whether this one is an A/S or an ApS.
#'
#' The name almost always does, because company law requires the form to be
#' part of it. Measured over 4,304 filings, 99.6% carry a recognisable one:
#' 3,330 ApS, 786 A/S, 120 IVS, 41 foundations and a handful of K/S and P/S.
#' `form` is that reading.
#'
#' The 17 that miss are mostly foundations named without "Fonden", and
#' companies whose form is a compound -- "Ejendomsaktieselskabet Illuut" --
#' which is why the spelled-out Danish words are matched inside a word and the
#' abbreviations are not: "ApS" as a syllable is a coincidence,
#' "anpartsselskab" is not.
#'
#' It is a reading of the name, not a reported fact, and it is here because the
#' alternative is every caller writing the same regular expression. Where it
#' matters, the register is the authority.
#'
#' @section The activity description, and where it actually sits:
#' The obvious element -- `DisclosureOfMainActivitiesAndAccountingAndFinancialMatters`
#' -- is used by 6% of filings. The one companies actually use is
#' `DescriptionOfPrimaryActivitiesOfEntity`, "virksomhedens væsentligste
#' aktiviteter", at 72%. Both are read, the first as a fallback for the second.
#'
#' `development` works the same way: the tagged description of the year at 54%,
#' falling back to the management's review as a whole for a further 22% --
#' which is a longer and looser text, so `development_source` says which was
#' taken.
#'
#' @section Two things the corpus taught this function:
#' **A headcount tagged to the nearest thousand.** Six facts in 4,304 filings
#' carry `decimals = "-3"` on the number of employees, and all six are the two
#' filings that state 151,000 or 2,286,000 employees. No plausible fact carries
#' it; the separation is exact. The filer's tool applied the statement's
#' thousands-scaling to a headcount, and the same company states 2,296 in
#' another year. Such a count is divided by a thousand. It moved the corpus mean
#' from 780 employees to 19.8, and the maximum to Royal Greenland's real 2,296.
#'
#' **The accounting class is written in the filing's own language.** 13 filings
#' say "Reporting class B" where 4,112 say "Regnskabsklasse B", which splits a
#' grouping in two without anyone noticing. `reporting_class` keeps the filing's
#' own words -- it is where "mikrovirksomhed" is visible -- and `class` carries
#' just the letter, which is the same in both languages.
#'
#' @section Persons:
#' A filing names people: the auditor, the executive board, the chairman of the
#' general meeting. Those are personal data, and an accounts statistic does not
#' need them -- the audit *firm* and its CVR number answer "who audited this"
#' without naming anyone. So they are left out unless asked for. Set
#' `persons = TRUE` where there is a reason, and keep in mind that the result
#' then carries names that should not be redistributed casually.
#'
#' @param x A tibble from [read_xbrl()]. Every field here is read as text, so
#'   this is the one table that still works on a filing whose taxonomy version
#'   the package does not know.
#' @param persons Include the names of the auditor, the executive and
#'   supervisory boards and the chairman of the general meeting. Off by
#'   default; see the section above.
#' @param prose Include the free-text fields -- the activity description, the
#'   year's development, events after the reporting period and the expected
#'   development. They can run to thousands of characters. `FALSE` keeps the
#'   row narrow for a table of many companies.
#'
#' @return A tibble with one row per filing, every field the filing carries
#'   about itself. A field it does not state is `NA`.
#' * **Identity:** `cvr`, `name`, `form`, `founded`, `period_start`,
#'   `period_end`.
#' * **Where:** `street`, `postcode`, `city`, `country`,
#'   `registered_office`.
#' * **Size and class:** `reporting_class`, `class`, `micro`,
#'   `class_c_elements`, `employees`, `assets_not_owned`, `currency`.
#' * **Group:** `group_accounts` (the filing has consolidated figures) and
#'   `in_group` (the company is part of a group: balances with group
#'   enterprises, shares in them, a subsidiary's exemption under section 78a,
#'   or a note on group accounts).
#' * **The report:** `report_type`, `general_meeting`, `approved`,
#'   `signature_place`, `submitter`, `submitter_cvr`, `xbrl_tool`,
#'   `policies_unchanged`.
#' * **The audit:** `auditor_assistance` as written and `assurance` as one of
#'   `"audit"`, `"extended review"`, `"review"`, `"compilation"` or `"none"`;
#'   `audit_firm`, `audit_firm_cvr`; `opinion` as written and `opinion_kind`
#'   as `"clean"`, `"qualified"`, `"adverse"` or `"disclaimer"`;
#'   `going_concern`, whether the auditor or the filing reports a material
#'   uncertainty about the company continuing; `auditor_signed`,
#'   `audit_exempt`.
#'
#' Branch of industry is not in a filing, only in the CVR register. Join it on
#' `cvr` from a register extract of your own.
#' * With `prose`: `activity`, `activity_source`, `development`,
#'   `development_source`, `events_after`, `expected_development`,
#'   `mortgages`, `contingent_liabilities`.
#' * With `persons`: `auditor_name`, `auditor_id`, `auditor_description`,
#'   `executive_board`, `supervisory_board`, `chairman`.
#'
#' `file` comes last: the path the row was read from. [xbrl_accounts()]
#' divides these into `company`, `location`, `audit` and `prose`.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' xbrl_company(x)
#'
#' # with the names of the people who signed
#' xbrl_company(x, persons = TRUE)
#' }
#'
#' @seealso [xbrl_accounts()], which returns this beside the statements,
#'   and [xbrl_lines()] for the figures.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
xbrl_company <- function(x, persons = FALSE, prose = TRUE) {
  need <- c("file", "elementid", "fact", "period_start", "period_end")
  gone <- setdiff(need, names(x))
  if (length(gone) > 0)
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} must be a tibble from {.fn read_xbrl}."))

  # Narrow before splitting: add_taxonomy() returns a fact once per statement
  # it appears in, and none of those columns are read here.
  keep <- c("file", "cvr", "period_start", "period_end", "elementid", "fact",
            "decimals", "enddate", "instant", "unit", "basis", "value")
  d <- x[intersect(keep, names(x))]
  d <- d[!is.na(d$fact) & trimws(d$fact) != "", , drop = FALSE]
  # Once each. add_taxonomy() repeats a fact for every statement it is placed
  # in, and with only these columns kept the copies are identical rows; every
  # field below scanned all of them.
  d <- d[!duplicated(data.table::as.data.table(d)), , drop = FALSE]

  # A plain data.frame for the split, and one row per filing built the same
  # way: 4,304 of them are 4,304 constructions, and tibble() checks and
  # rebuilds every column each time where data.frame() does not. The tibble is
  # made once, at the end, out of the bound result.
  g  <- split(as.data.frame(d), d$file)
  pb <- .file_progress(g, "  reading companies")
  out <- lapply(g, function(z) {
    .file_tick(pb)
    .company_one(z, persons = persons, prose = prose)
  })
  .file_done(pb)
  tibble::as_tibble(data.table::rbindlist(out, fill = TRUE))
}

# One filing's row.
.company_one <- function(x, persons, prose) {
  end <- x$period_end[1]

  idx <- split(seq_len(nrow(x)), x$elementid)
  one <- function(...) .company_fact(x, c(...), end, idx = idx)
  all_of <- function(...) .company_fact(x, c(...), end, collapse = "; ", idx = idx)

  # A street address is two elements, and either can be absent.
  street <- paste(stats::na.omit(
    c(one("AddressOfReportingEntityStreetName"),
      one("AddressOfReportingEntityStreetBuildingIdentifier"))),
    collapse = " ")
  if (!nzchar(street)) street <- NA_character_

  emp <- .company_employees(x, end)

  # The accounting class is written in the filing's own language, and 13 of
  # 4,304 write it in English -- enough to split a grouping in two without
  # anyone noticing. The letter is the same in both.
  cls <- one("ClassOfReportingEntity")
  letter <- if (is.na(cls)) NA_character_
            else sub("^.*?([A-D])\\b.*$", "\\1", cls)
  if (!is.na(letter) && !letter %in% c("A", "B", "C", "D"))
    letter <- NA_character_

  out <- data.frame(
    stringsAsFactors  = FALSE,
    cvr               = x$cvr[1],
    name              = one("NameOfReportingEntity"),
    form              = .company_form(one("NameOfReportingEntity")),
    street            = street,
    postcode          = one("AddressOfReportingEntityPostCodeIdentifier"),
    city              = one("AddressOfReportingEntityDistrictName"),
    country           = one("AddressOfReportingEntityCountry"),
    registered_office = one("RegisteredOfficeOfReportingEntity"),
    founded           = .as_date(one("DateOfFoundationOfReportingEntity")),
    period_start      = x$period_start[1],
    period_end        = end,
    general_meeting   = .as_date(one("DateOfGeneralMeeting")),
    report_type       = one("InformationOnTypeOfSubmittedReport"),
    reporting_class   = cls,
    class             = letter,
    auditor_assistance = one("TypeOfAuditorAssistance"),
    employees         = emp,
    audit_firm        = one("NameOfAuditFirm"),
    audit_firm_cvr    = one("IdentificationNumberCvrOfAuditFirm"),
    currency          = .filing_currency(x),
    # Who filed it. Almost always an accounting firm -- Gronlands Revision,
    # BDO, Deloitte -- and knowing which one explains a good deal of the
    # systematic variation in how a filing is tagged.
    submitter         = one("NameOfSubmittingEnterprise"),
    submitter_cvr     = one("IdentificationNumberCvrOfSubmittingEnterprise"),
    approved          = .as_date(one("DateOfApprovalOfAnnualReport",
                                     "DateOfApprovalOfReport")),
    signature_place   = one("PlaceOfSignatureOfStatement"),
    auditor_signed    = .as_date(one("SignatureOfAuditorsDate")),
    # "Konklusion" where the opinion is clean and "Konklusion med forbehold"
    # where it is qualified. A qualified opinion is a reason to treat the
    # figures with care, and there is no other field that says so.
    opinion           = one("TypeOfModifiedOpinionOnAuditedFinancialStatements",
                            paste0("TypeOfModifiedOpinionOnAuditedFinancial",
                                   "StatementsExtendedReview"),
                            paste0("TypeOfModifiedOpinionOnAuditedFinancial",
                                   "StatementsReview")),
    # Whether the auditor drew attention to a material uncertainty about the
    # company continuing as a going concern. The auditor's paragraph is the
    # stronger evidence, and the filing's own typed answer is used where
    # there is no paragraph. 57 filings of a 4,304-filing corpus carry the
    # paragraph. NA where neither says anything, which is not the same as no.
    going_concern     = .going_concern(
      one("MaterialUncertaintyConcerningGoingConcernAudit",
          "MaterialUncertaintyConcerningGoingConcernExtendedReview"),
      one("TypeOfDisclosureRelatingToGoingConcern")),
    # Whether last year's figures were prepared the same way. A break in a
    # series is explained if the policy changed, and unexplained if it did not.
    policies_unchanged = .company_flag(
      one("AccountingPoliciesAreUnchangedFromPreviousPeriod")),
    class_c_elements  = .company_flag(one("SelectedElementsFromReportingClassC")),
    audit_exempt      = !is.na(one(paste0("ConfirmationThatFinancialStatements",
                                          "AreExemptedFromAuditing"))),
    assets_not_owned  = suppressWarnings(as.numeric(
      one("RecognisedButNotOwnedAssets"))),
    xbrl_tool         = one("ToolForPreparingTheXBRLInstanceDocument"))

  # What kind of filing this is, in the terms a comparison needs: the same
  # finding means different things for a micro company with no auditor and a
  # group under audit.
  out$micro <- !is.na(cls) & grepl("mikro|micro", cls, ignore.case = TRUE)
  out$assurance <- .assurance(out$auditor_assistance)
  out$opinion_kind <- .opinion_kind(out$opinion)
  # Group accounts are what consolidated figures are; a filing with none of
  # them is a single company's, whatever its group.
  out$group_accounts <- "basis" %in% names(x) && any(x$basis %in% "consolidated")
  # Part of a group: balances with group enterprises, shares in them, a
  # subsidiary's exemption under section 78a, or a note on the group accounts
  # the company is in or leaves out. Any one is enough.
  grp <- x$elementid %in% .GROUP_ELEMENTS
  if ("value" %in% names(x))
    grp <- grp & (is.na(x$value) | x$value != 0)
  out$in_group <- out$group_accounts || any(grp)

  if (isTRUE(prose)) {
    act <- one("DescriptionOfPrimaryActivitiesOfEntity")
    act_src <- if (!is.na(act)) "primary activities" else NA_character_
    if (is.na(act)) {
      act <- one("DisclosureOfMainActivitiesAndAccountingAndFinancialMatters")
      if (!is.na(act)) act_src <- "main activities disclosure"
    }
    dev <- one("DescriptionOfDevelopmentInActivitiesAndFinancialAffairs")
    dev_src <- if (!is.na(dev)) "development described" else NA_character_
    if (is.na(dev)) {
      dev <- one("ManagementsReview")
      if (!is.na(dev)) dev_src <- "management's review"
    }
    out$activity <- act
    out$activity_source <- act_src
    out$development <- dev
    out$development_source <- dev_src
    out$events_after <- one(paste0("DescriptionOfSignificantEventsOccurring",
                                   "AfterEndOfReportingPeriod"))
    out$expected_development <- one("DescriptionOfExpectedDevelopment")
    out$mortgages <- one("DisclosureOfMortgagesAndCollaterals")
    out$contingent_liabilities <- one("DisclosureOfContingentLiabilities")
  }

  if (isTRUE(persons)) {
    out$auditor_name <- all_of("NameAndSurnameOfAuditor")
    out$auditor_id <- all_of("IdentificationNumberOfAuditor")
    out$auditor_description <- one("DescriptionOfAuditor")
    out$executive_board <- all_of("NameAndSurnameOfMemberOfExecutiveBoard")
    out$supervisory_board <- all_of("NameAndSurnameOfMemberOfSupervisoryBoard")
    out$chairman <- all_of("NameAndSurnameOfChairmanOfGeneralMeeting")
  }

  # Last, not first: the path is where the row came from, not what it is.
  out$file <- x$file[1]
  out
}

# A taxonomy flag, as filers actually write it: "true"/"false", and "1" often
# enough that ignoring it would drop the field for those filings.
.company_flag <- function(v) {
  if (is.na(v)) return(NA)
  z <- tolower(trimws(v))
  if (z %in% c("true", "1")) TRUE else if (z %in% c("false", "0")) FALSE else NA
}

# The average number of employees, with the one tagging fault that matters.
#
# Six facts in the corpus carry `decimals = "-3"`, and all six are the two
# filings that state a headcount of 151,000 or 2,286,000. No other fact of this
# element carries it: the plausible ones are 0, 1, 3, INF or nothing. The
# separation is exact.
#
# What happened is that the filer's tool applied the statement's
# thousands-scaling to a count. Read literally the claim is "2,286,000
# employees, to the nearest thousand", which no Greenlandic fishing company
# means -- and the same company states 2,296 in another year. So a count tagged
# to the nearest thousand is divided by a thousand, which puts it back where
# its own other filings put it.
#
# This is a correction, not a reading of the standard, and it is confined to a
# pattern that cannot occur innocently: `decimals` of -3 on a headcount.
.company_employees <- function(x, end) {
  h <- x[x$elementid %in% "AverageNumberOfEmployees" & !is.na(x$fact) &
           trimws(x$fact) != "", , drop = FALSE]
  if (nrow(h) == 0) return(NA_real_)
  if (!is.na(end)) {
    cur <- h[h$enddate %in% end | h$instant %in% end, , drop = FALSE]
    if (nrow(cur) > 0) h <- cur
  }
  v <- suppressWarnings(as.numeric(trimws(h$fact[1])))
  dec <- if ("decimals" %in% names(h)) h$decimals[1] else NA_character_
  if (!is.na(v) && !is.na(dec) && dec == "-3") v <- v / 1000
  v
}

# One text fact for a set of elements, taken from the reporting period where
# the filing distinguishes periods.
#
# Company data is usually stated once, against the year's own context, but a
# filing that restates a comparative can carry it twice. Preferring the
# declared year keeps the answer the year's, and falling back to whatever is
# there keeps a filing that dated the fact differently from coming back empty.
#
# `collapse` is for the fields that are genuinely several -- a board has more
# than one member -- and joins them rather than silently taking the first.
.company_fact <- function(x, els, end, collapse = NULL, idx = NULL) {
  # Rows by index, and the columns as vectors. Subsetting the filing as a data
  # frame for each of some fifty fields was half of what reading a company
  # cost. Sorted, so that the first answer is the first row, as it was.
  i <- if (is.null(idx)) which(x$elementid %in% els)
       else sort(unlist(idx[intersect(els, names(idx))], use.names = FALSE))
  if (length(i)) {
    f <- x$fact[i]
    i <- i[!is.na(f) & trimws(f) != ""]
  }
  if (length(i) == 0) return(NA_character_)

  if (!is.na(end)) {
    cur <- i[x$enddate[i] %in% end | x$instant[i] %in% end]
    if (length(cur) > 0) i <- cur
  }
  v <- trimws(x$fact[i])
  # The same fact tagged against several contexts is one answer, not several.
  v <- unique(v)
  if (is.null(collapse)) v[1] else paste(v, collapse = collapse)
}


# The legal form, read off the company's own name.
#
# The taxonomy has no element for it. `RelatedEntityLegalForm` exists and is
# for the companies a filer is related to, not for the filer; there is nothing
# that says whether this one is an A/S or an ApS. The register has it, the
# filing does not.
#
# But the name almost always does, because Danish and Greenlandic company law
# requires the form to be part of it. Measured over 4,304 filings: 99.6% carry
# a recognisable form, 3,330 ApS, 786 A/S, 120 IVS, 41 foundations and a few
# K/S and P/S. The 17 that do not are mostly foundations named without
# "Fonden", and companies whose form is a compound -- "Ejendomsaktieselskabet
# Illuut" -- which is why the long Danish words are matched inside a word and
# the abbreviations are not: "APS" as a syllable is a coincidence,
# "ANPARTSSELSKAB" is not.
.LEGAL_FORMS <- list(
  # Matched as a word of its own: an abbreviation inside another word is a
  # coincidence, not a legal form.
  word = c("A/S", "ApS", "IVS", "P/S", "I/S", "K/S",
           "AMBA", "FMBA", "SMBA", "G/S"),
  # Matched anywhere in the name, because the law lets the form be written
  # into a compound: "Ejendomsaktieselskabet" is an A/S.
  part = c(Fond = "FOND", ApS = "ANPARTSSELSKAB", "A/S" = "AKTIESELSKAB",
           "I/S" = "INTERESSENTSKAB", "K/S" = "KOMMANDITSELSKAB"))

.company_form <- function(name) {
  if (is.na(name)) return(NA_character_)
  s <- toupper(name)

  # The abbreviations first, and only where they stand alone. A character
  # class of the Danish alphabet rather than `\\b`, because the slash in
  # "A/S" is itself a word boundary and every name containing an "s" would
  # match. The letters are escaped so the source stays ASCII.
  ae_oe_aa <- "\u00c6\u00d8\u00c5"
  for (f in .LEGAL_FORMS$word) {
    pat <- paste0("(^|[^A-Z", ae_oe_aa, "])", toupper(f),
                  "($|[^A-Z", ae_oe_aa, "])")
    if (grepl(pat, s)) return(f)
  }

  hit <- names(.LEGAL_FORMS$part)[
    vapply(.LEGAL_FORMS$part, grepl, logical(1), x = s, fixed = TRUE)]
  if (length(hit)) hit[1] else NA_character_
}


# Which of the company row's columns belong to which table.
#
# xbrl_company() reads one filing into one wide row, and xbrl_accounts()
# divides that row by the question it answers: where the company is, how the
# report came to be, what management wrote, and what the checks concluded.
# The split lives here rather than in xbrl_accounts() so that adding a field
# means naming it once.
#
# What is not listed stays in `company`, which is the right default: a new
# field is about the company until someone says otherwise.
.COMPANY_GROUPS <- list(
  location = c("street", "postcode", "city", "country", "registered_office"),
  audit    = c("report_type", "general_meeting", "auditor_assistance",
               "assurance", "audit_firm", "audit_firm_cvr", "opinion",
               "opinion_kind", "going_concern", "auditor_signed",
               "audit_exempt", "submitter", "submitter_cvr", "approved",
               "signature_place", "xbrl_tool", "policies_unchanged",
               "currency", "auditor_name", "auditor_id", "auditor_description",
               "executive_board", "supervisory_board", "chairman"),
  prose    = c("activity", "activity_source", "development",
               "development_source", "events_after", "expected_development",
               "mortgages", "contingent_liabilities"),
  checks   = c("income_reconciled", "balance_reconciled",
               "cashflow_reconciled", "cashflow_debt_backed",
               "movements_reconciled", "movements_cover"))

# Elements whose presence says the company is part of a group.
.GROUP_ELEMENTS <- c(
  "LongtermInvestmentsInGroupEnterprises", "ShorttermReceivablesFromGroupEnterprises",
  "LongtermReceivablesFromGroupEnterprises", "ShorttermPayablesToGroupEnterprises",
  "LongtermPayablesToGroupEnterprises", "ShorttermTaxPayablesToGroupEnterprises",
  "IncomeFromInvestmentsInGroupEnterprises", "InterestIncomeFromGroupEnterprises",
  "InterestExpenseAssignedToGroupEnterprises", "InformationOnConsolidatedFinancialStatements",
  "InformationOnOmissionOfConsolidatedFinancialStatement",
  paste0("TheCompanyHasPresentedTheAnnualReportEtcWithReferenceToTheDanish",
         "FinancialStatementsAct78aConcerningTheExceptionForReportingClassC",
         "MediumsizeSubsidiariesWhichChoosesToPresentTheAnnualReportEtc",
         "AccordingToReportingClassB"))

# The auditor's involvement, one word for each level of assurance, whichever
# language the filing wrote it in.
.assurance <- function(assistance) {
  a <- tolower(trimws(assistance))
  ifelse(is.na(a), NA_character_,
  ifelse(grepl("udvidet|extended", a), "extended review",
  ifelse(grepl("review", a), "review",
  ifelse(grepl("revisionsp|audited", a), "audit",
  ifelse(grepl("ingen|no audit", a), "none",
  ifelse(grepl("uden sikkerhed|non-assurance", a), "compilation", "other"))))))
}

# TRUE where the auditor's report carries a material uncertainty paragraph,
# or the filing types its going concern disclosure as one; FALSE where it
# types it as not material; NA where nothing is said.
.going_concern <- function(paragraph, typed) {
  if (!is.na(paragraph) && nzchar(trimws(paragraph))) return(TRUE)
  if (is.na(typed)) return(NA)
  if (grepl("^ikke", trimws(typed), ignore.case = TRUE) ||
      grepl("^no ", trimws(typed), ignore.case = TRUE)) return(FALSE)
  grepl("usikkerhed|uncertainty", typed, ignore.case = TRUE)
}

# The auditor's conclusion, read off the Danish or the English wording, as
# one of four: clean, qualified, adverse, or no conclusion at all.
.opinion_kind <- function(opinion) {
  o <- tolower(trimws(opinion))
  ifelse(is.na(o), NA_character_,
  ifelse(grepl("afkr.ftende|adverse", o), "adverse",
  ifelse(grepl("manglende|disclaimer", o), "disclaimer",
  ifelse(grepl("forbehold|qualified", o), "qualified", "clean"))))
}

# One of those tables: the key, the group's own columns, and the file last.
# `intersect()` throughout, because `persons` and `prose` decide whether some
# of the columns are there at all.
.company_group <- function(d, which) {
  cols <- intersect(.COMPANY_GROUPS[[which]], names(d))
  keep <- c(intersect(.KEYS, names(d)), cols, intersect("file", names(d)))
  .key_first(d[keep])
}
