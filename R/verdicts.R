# What the checks concluded about one filing
#
# xbrl_accounts() reports six verdicts, and each is a summary of something
# a caller can go and look at: check_statement(), check_cascade() and
# check_cashflow() give the detail one row at a time, and xbrl_movements()
# carries the note's own.
# What lives here is the reduction from that detail to one logical per
# filing, and the line a stage prints when it finishes.


# Does the statement add up, per filing? One logical per file, named by it, so
# it can be looked up from any of the four tables.
#
# The balance sheet is a partition and reconciles when its two sides agree.
# The income statement is a cascade and reconciles when no step is left
# unexplained -- a step that is merely absent from the filing is not a failure.
#
# `checks` is the check's own output, already computed over every basis --
# xbrl_screen() keeps it -- so that a caller who has screened the filings does
# not pay for the same checks twice. It is the same check with the same
# settings, filtered to the basis asked for.
.reconciles <- function(x, statement, basis, checks = NULL) {
  if (!is.null(checks)) {
    # A check with nothing to check returns an empty frame without columns.
    if (!nrow(checks) || !"basis" %in% names(checks))
      return(stats::setNames(logical(), character()))
    ch <- checks[checks$basis %in% basis, , drop = FALSE]
    if (identical(statement, "balance")) {
      ch <- ch[ch$label %in% "debit side vs credit side", , drop = FALSE]
      if (nrow(ch) == 0) return(stats::setNames(logical(), character()))
      return(.by_file(ch$verdict %in% "sides agree", ch$file))
    }
    if (nrow(ch) == 0) return(stats::setNames(logical(), character()))
    return(.by_file(!ch$status %in% "unexplained", ch$file))
  }

  want <- .statement_names(statement)
  d <- x[x$statement %in% want & x$basis %in% basis & !is.na(x$period) &
           !is.na(x$period_end) & x$period == x$period_end, , drop = FALSE]
  if (nrow(d) == 0) return(stats::setNames(logical(), character()))

  by <- c("file", "basis", "period")
  if (identical(statement, "balance")) {
    ch <- tryCatch(check_statement(d, by = by), error = function(e) NULL)
    if (is.null(ch) || nrow(ch) == 0)
      return(stats::setNames(logical(), character()))
    ch <- ch[ch$label %in% "debit side vs credit side", , drop = FALSE]
    if (nrow(ch) == 0) return(stats::setNames(logical(), character()))
    return(.by_file(ch$verdict %in% "sides agree", ch$file))
  }

  ch <- tryCatch(check_cascade(d, by = by), error = function(e) NULL)
  if (is.null(ch) || nrow(ch) == 0)
    return(stats::setNames(logical(), character()))
  .by_file(!ch$status %in% "unexplained", ch$file)
}


# The cash flow statement's two verdicts, per filing, because it answers two
# questions. Does it agree with itself -- activities, roll-forward, closing
# cash -- and is every krone it says was borrowed a krone the balance sheet
# owes? A statement can do the first perfectly and fail the second: moving an
# amount between activities leaves every total where it was.
#
# Debt that grew by more than the cash raised is not a failure. A new lease
# does that, and so does interest added to principal. Only the other direction
# is: cash reported as borrowed with no debt in the balance sheet to match.
.cashflow_verdicts <- function(x, basis, checks = NULL) {
  none <- stats::setNames(logical(), character())
  if (!is.null(checks) && (!nrow(checks) || !"basis" %in% names(checks)))
    return(list(reconciled = none, debt = none))
  ch <- if (!is.null(checks)) checks[checks$basis %in% basis, , drop = FALSE] else {
    d <- x[x$basis %in% basis, , drop = FALSE]
    tryCatch(check_cashflow(d, by = c("file", "basis")), error = function(e) NULL)
  }
  if (is.null(ch) || nrow(ch) == 0) return(list(reconciled = none, debt = none))

  internal <- ch$check %in% c("activities", "rollforward", "cash vs balance")
  debt <- ch$check %in% "debt vs balance"
  list(
    reconciled = .by_file(ifelse(internal, startsWith(ch$verdict, "agrees"), NA),
                          ch$file),
    debt = .by_file(ifelse(debt, !ch$verdict %in% "borrowed more than owed", NA),
                    ch$file))
}


# All of `v` per file, as a plain named logical.
#
# Two details. tapply() hands back a one-dimensional array, and a column
# carrying one prints as `<lgl[1d]>` and compares oddly -- a surprise in a
# table meant to be handled with ordinary verbs. And `all()` on a vector with
# an NA in it is NA, which would let one unchecked block decide the whole
# filing; the question is whether everything *checkable* passed, so NA is
# reserved for a filing where nothing was.
.by_file <- function(v, file) {
  if (length(v) == 0) return(stats::setNames(logical(), character()))
  r <- tapply(v, file, function(z)
    if (all(is.na(z))) NA else all(z, na.rm = TRUE))
  stats::setNames(as.vector(r), names(r))
}


.with_verdict <- function(d, ok) {
  d$reconciled <- unname(ok[d$file])
  # Again, because the verdict arrives after the columns were first ordered.
  .key_first(d)
}


# What a stage says when it finishes: its size, and how the figures held up.
#
# The grain differs by table and the wording follows it. A statement reconciles
# per filing, so it is counted in filings. A fixed asset note reconciles per
# class and per layer -- one filing can have a cost block that closes and a
# depreciation block that does not -- so it is counted in blocks, and calling
# those filings would overstate what was checked.
.stage_note <- function(d) {
  rows <- paste(format(nrow(d), big.mark = ","), "rows")
  verdict <- .verdict_note(d)
  if (!nzchar(verdict)) rows else paste0(rows, ", ", verdict)
}


# How the figures held up, without the row count: the print method wants the
# two apart so it can line the columns up, and the stage lines want them
# joined. `""` where the table carries no verdict at all.
.verdict_note <- function(d) {
  if (!"reconciled" %in% names(d)) return("")

  if (all(c("layer", "class") %in% names(d))) {
    u <- unique(d[c("file", "category", "class", "layer", "reconciled")])
    unit <- "block"
  } else {
    u <- unique(d[c("file", "reconciled")])
    unit <- "filing"
  }
  judged <- u$reconciled[!is.na(u$reconciled)]
  if (length(judged) == 0) return("none with anything to check")

  sprintf("%s of %s %s%s reconcile",
          format(sum(judged), big.mark = ","),
          format(length(judged), big.mark = ","), unit,
          if (length(judged) == 1) "" else "s")
}

