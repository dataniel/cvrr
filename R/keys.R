# The key every table opens with
#
# One contract, in one place, because eight tables keep it and a reader moving
# between them should never have to check.


# `file` is not one of them. A report is one accounting year, and cvr with
# period_end identifies it -- across 4,304 filings there is not one duplicate.
# Where a directory does hold a report filed twice, .current_files() says
# which of the two stands.
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


# The filing that stands for each company and year.
#
# `cvr` and `period_end` identify an annual report, and in a corpus of 4,304
# filings no two share them. But a report can be filed again -- withdrawn and
# replaced, or corrected -- and cvr_download() gives the second file of a
# company a `_2` suffix, so a directory can hold both. Then "one row per
# company and year" needs a rule, and every function has to use the same one:
# before this, the panel kept both and the screen and the standardising each
# took whichever came first.
#
# The later report wins: the one approved last, by the dates the filing itself
# states, and where those do not settle it, the one read last. When the report
# was published is not in the file, so approval is the nearest thing to it.
#
# One row per company and year: `cvr`, `period_end`, `file`, and `n`, the
# number of filings there were to choose from.
.current_files <- function(x) {
  f <- unique(x[c("cvr", "period_end", "file")])
  f <- as.data.frame(f[!duplicated(f$file), , drop = FALSE])
  f$order <- seq_len(nrow(f))
  f$when <- as.Date(NA)
  if ("fact" %in% names(x)) {
    a <- x[x$elementid %in% c("DateOfApprovalOfAnnualReport",
                              "DateOfApprovalOfReport", "DateOfGeneralMeeting"),
           c("file", "fact")]
    d <- .as_date(a$fact)
    a <- a[!is.na(d), , drop = FALSE]
    d <- d[!is.na(d)]
    if (length(d)) {
      latest <- tapply(as.numeric(d), a$file, max)
      f$when <- as.Date(unname(latest[f$file]), origin = "1970-01-01")
    }
  }
  k <- paste(f$cvr, f$period_end)
  f$n <- as.integer(table(k)[k])
  # Latest first within a company and year; a filing with no date loses to one
  # that has it.
  f <- f[order(k, -ifelse(is.na(f$when), -Inf, as.numeric(f$when)), -f$order), ,
         drop = FALSE]
  f <- f[!duplicated(paste(f$cvr, f$period_end)), , drop = FALSE]
  f <- f[order(f$order), c("cvr", "period_end", "file", "n"), drop = FALSE]
  rownames(f) <- NULL
  f
}

# The filings another filing of the same company and year replaces.
.superseded_files <- function(x) {
  if (!all(c("cvr", "period_end", "file") %in% names(x))) return(character())
  known <- !is.na(x$cvr) & !is.na(x$period_end)
  setdiff(unique(x$file[known]), .current_files(x[known, , drop = FALSE])$file)
}


# A whole-table step that failed, said out loud.
#
# These steps used to be wrapped in `tryCatch(..., error = function(e) NULL)`,
# and a failure then came out as `NA` -- "nothing of that kind to check" --
# which is what a filing without the statement gets too. The two are not the
# same, and only one of them is a fault in the package or in the facts.
.or_null <- function(expr, what) {
  tryCatch(expr, error = function(e) {
    # Through a variable: the message is someone else's text, and a brace in
    # it would be read as cli markup.
    why <- conditionMessage(e)
    cli::cli_warn(c(
      "{what} failed, and what it would have found is missing.",
      "x" = "{why}"))
    NULL
  })
}

# Someone else's text, made safe to hand to cli as a bullet.
.cli_literal <- function(s) gsub("}", "}}", gsub("{", "{{", s, fixed = TRUE),
                                 fixed = TRUE)


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
