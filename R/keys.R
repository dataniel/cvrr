# The key every table opens with
#
# One contract, in one place, because eight tables keep it and a reader moving
# between them should never have to check.


# `file` is not one of them. A report is one accounting year, and cvr with
# period_end identifies it -- across 4,304 filings there is not one duplicate.
# The path is where the row came from, which matters when a filing will not
# parse and not otherwise, so it goes last.
#
# `name` is repeated rather than left to a join. R keeps one copy of each
# distinct string and a pointer per row, so 127,000 balance sheet lines cost
# 1.4 MB -- the same order as a date column, against a table of 15 to 20 -- for
# never having to fetch a company's name in order to read its figures.
.KEYS <- c("cvr", "name", "period_start", "period_end")

.key_first <- function(d) {
  keys <- intersect(.KEYS, names(d))
  rest <- setdiff(names(d), c(keys, "file"))
  d[c(keys, rest, intersect("file", names(d)))]
}

# The reporting entity's name, per filing. Read from the facts before they are
# narrowed to a statement: the name belongs to no statement.
.filing_names <- function(x) {
  if (!all(c("file", "elementid", "fact") %in% names(x)))
    return(stats::setNames(character(), character()))
  h <- x[x$elementid %in% "NameOfReportingEntity" & !is.na(x$fact) &
           nzchar(trimws(x$fact)), c("file", "fact")]
  h <- h[!duplicated(h$file), , drop = FALSE]
  stats::setNames(trimws(h$fact), h$file)
}


# One progress bar per filing, for the functions that loop over them.
#
# The stage lines in xbrl_accounts() say what is being built, but a stage that
# takes seventy seconds on a corpus shows nothing while it runs, and a spinner
# that does not move reads as a hang. This is what moves.
#
# The bar is only worth its own overhead on many filings; on one it would be
# noise, so it is silent there. The id is returned and passed to the update,
# because cli ties a bar to the frame that created it and the update happens
# inside a loop's closure.
.file_progress <- function(files, label) {
  if (length(files) < 2L) return(NULL)
  cli::cli_progress_bar(label, total = length(files), .envir = parent.frame())
}

.file_tick <- function(pb) {
  if (!is.null(pb)) cli::cli_progress_update(id = pb)
  invisible(NULL)
}

.file_done <- function(pb) {
  if (!is.null(pb)) cli::cli_progress_done(id = pb)
  invisible(NULL)
}
