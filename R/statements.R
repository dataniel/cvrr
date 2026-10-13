# Which statement, which column, which grouping
#
# The vocabulary every function that reads a statement needs, kept in one place
# because five of them need it: xbrl_lines() to pick a statement, xbrl_accounts()
# to judge one, and check_statement(), check_cascade() and check_breakdown() to
# scope themselves to the filing and the year they are about.
#
# A fact table used to hold one filing and one accounting year. read_xbrl() now
# returns a directory at a time, and every default here exists because that
# change made an old one wrong.


# ---- which statement -------------------------------------------------------

# Every name the Danish balance sheet is presented under. The corpus uses the
# first for 4,279 filings of 4,304 and the second for 25; the third is in the
# taxonomy and unused here, and costs nothing to accept.
.BALANCE_STATEMENTS <- c("BalanceSheetAccountForm",
                         "BalanceSheetAccountByCurrentAndLongtermForm",
                         "BalanceSheetReportForm")

# Every income statement the taxonomy defines, read from the packaged tables
# rather than listed here.
#
# The corpus uses two -- by nature and by function -- but the taxonomy carries
# a dozen more for sectors that file under their own format, and an education
# institution's income statement is still an income statement. A hardcoded pair
# would drop them silently.
#
# The `...Disclosures` points are excluded: they are the notes to a statement,
# not the statement, and they have no cascade of their own.
.INCOME_STATEMENTS <- function() {
  s <- unique(cvrr_line$statement)
  s <- s[!is.na(s) & startsWith(s, "IncomeStatement")]
  s[!endsWith(s, "Disclosures")]
}

# The aliases, and the taxonomy statement names behind each. Anything that is
# not an alias is taken to be a statement name already, so a sector the aliases
# do not cover is reachable without the package enumerating every one of them.
.statement_names <- function(statement) {
  if (!is.character(statement) || length(statement) == 0)
    cli::cli_abort("{.arg statement} must be a character vector.")

  unlist(lapply(statement, function(s) switch(s,
    balance  = .BALANCE_STATEMENTS,
    income   = .INCOME_STATEMENTS(),
    cashflow = "CashFlowStatement",
    equity   = c("StatementOfChangesInEquityLongVersion",
                 "StatementOfChangesInEquityShortVersion"),
    s)), use.names = FALSE)
}


# ---- which column ----------------------------------------------------------

# The filing's own closing column, and nothing else.
#
# A filing carries several years at once: the year it is about and at least one
# comparative, which is usually partial. A check run over all of them reports
# the comparative's gaps as the filing's own -- on four filings that turned
# four verdicts into nine, most of them failures that were not there.
#
# `period_end` is the date the filing declares for itself, so this needs no
# argument and no guessing. `period = NULL` keeps every column, which is what
# to pass when the comparative is the thing being checked.
.closing_only <- function(x, period = "closing") {
  if (is.null(period)) return(x)
  if (!all(c("period", "period_end") %in% names(x))) return(x)

  # A filing that declares no period end has no closing column to narrow to.
  # Filtering on an NA would empty the table and report the filing as having
  # nothing to check, which is not the same as having nothing wrong.
  if (all(is.na(x$period_end))) return(x)

  x[!is.na(x$period) & !is.na(x$period_end) & x$period == x$period_end, ,
    drop = FALSE]
}


# ---- which grouping --------------------------------------------------------

# Which columns identify one statement, one schedule -- one *filing's* worth of
# arithmetic.
#
# The check functions were written when a fact table held one filing, and
# `c("basis", "period")` identified a statement inside it. read_xbrl() now
# returns a directory at a time, so that is no longer true: four companies with
# the same balance sheet date land in one group, their codes collide, and the
# residual comes back NA -- or the group errors outright.
#
# So the default is derived from the data rather than fixed. `file` first,
# because it is the one key guaranteed present and unique per filing; a table
# that has no such column is a single filing and grouping is unchanged.
.default_by <- function(x, by = NULL, want = c("file", "basis", "period")) {
  if (!is.null(by)) return(by)
  hit <- intersect(want, names(x))

  # Nothing matched. Hand back what was asked for rather than aborting: the
  # calling function names the columns it cannot find, and its message is the
  # better one -- it knows what the column was for.
  if (length(hit) == 0) want else hit
}
