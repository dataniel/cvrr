#' A pile of filings as the tables an analysis reads
#'
#' Takes the fact table from [read_xbrl()] and divides it: who the company is,
#' where it is, how the report was audited, what its statements say, what its
#' fixed asset note shows, whether any of it adds up, and what management
#' wrote. One named list of tibbles, every one of them opening with the same
#' key, so that moving between them needs no looking.
#'
#' @section The key comes first, and is the same everywhere:
#' `cvr`, `name`, `period_start`, `period_end`, in that order, at the front of
#' every table, and `file` at the back of it -- the key is what a reader joins
#' and groups on, and the file name is what a figure is traced back to. `name`
#' is repeated rather than left to a join: R keeps one copy of each distinct
#' string and a pointer per row, so 127,000 balance sheet lines cost about a
#' megabyte for never having to fetch a company's name in order to read its
#' figures.
#'
#' @section Why eight tables and not one:
#' The company row is 40 columns wide and they answer different questions.
#' `development` runs to 486 characters in the median filing, so keeping the
#' prose beside the accounting class means every glance at the class drags a
#' paragraph with it. And the verdicts are not attributes of a company at all;
#' they are what the checks concluded about one filing.
#'
#' \describe{
#'   \item{`company`}{Who this is: legal form, when it was founded, accounting
#'     class, employees, currency.}
#'   \item{`location`}{Where it is: street, postcode, city, country and the
#'     registered office it states.}
#'   \item{`audit`}{How the report came to be, and how far to trust its
#'     tagging: who audited it and with what opinion, who submitted it, when it
#'     was approved, and which tool wrote the XBRL. With `persons`, the names
#'     that signed it.}
#'   \item{`checks`}{What the checks concluded, one row per filing.}
#'   \item{`income_statement`}{One row per line, in statement order, as
#'     reported. See [xbrl_lines()].}
#'   \item{`balance`}{One row per line, with the lines the filer left out
#'     derived and marked in `source`. See [xbrl_lines()].}
#'   \item{`movements`}{The fixed asset note, one row per movement per asset
#'     class. See [xbrl_movements()].}
#'   \item{`prose`}{What management wrote: the activity, the year's
#'     development, events after the reporting period, mortgages and contingent
#'     liabilities.}
#' }
#'
#' `what` builds only the tables named, and skips the work they do not need:
#' the checks are the expensive part, and `what = "company"` still runs them
#' because that row reports their verdicts, while `what = "location"` runs
#' none of them.
#'
#' @section Whether it adds up:
#' `income_statement` and `balance` carry `reconciled` on every row, so the
#' commonest filter -- give me only the lines that add up -- needs no join.
#' `movements` carries four verdicts of its own. And `checks` gathers the
#' per-filing conclusions in one place, at the grain the question is asked:
#'
#' * `balance_reconciled` -- the balance sheet's debit side equals its credit
#'   side, from [check_statement()].
#' * `income_reconciled` -- no step of the income statement's cascade is left
#'   unexplained, from [check_cascade()].
#' * `movements_reconciled` -- every block of the fixed asset note that could
#'   be checked rolls forward.
#' * `movements_cover` -- the notes together account for the fixed assets the
#'   balance sheet carries.
#'
#' They are four columns and never one verdict, because a filing can pass any
#' of them and fail the rest: a balance sheet that closes says nothing about
#' whether the income statement does, and a fixed asset schedule that rolls
#' forward perfectly for land and buildings says nothing about the machinery it
#' never mentions. `NA` means there was nothing of that kind to check, which is
#' not the same as failing.
#'
#' Each is a summary of something you can go and look at: `check_cascade()` on
#' one filing's facts gives the income statement's steps one row each, and
#' `movements` gives the note's blocks one row per movement.
#'
#' @param x A tibble from [read_xbrl()].
#' @param what Which tables to build. Any of `"company"`, `"audit"`,
#'   `"location"`, `"checks"`, `"income_statement"`, `"balance"`,
#'   `"movements"` and `"prose"`; all eight by default.
#' @param basis `"parent"` (default) or `"consolidated"`, for the statements
#'   and the note. An untagged figure is the parent's -- see [add_taxonomy()].
#' @param persons Include the names of the auditor, the boards and the chairman
#'   in `audit`. Personal data, so off by default -- see [xbrl_company()].
#' @param taxonomy Passed to [xbrl_lines()]. `NULL` uses the packaged tables.
#'
#' @return A list of tibbles of class `cvrr_accounts`, named by `what` and in
#'   that order. The filings that could not be read are carried through in
#'   `attr(a, "failed")`.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' a <- xbrl_accounts(x)
#' a
#'
#' a$balance
#' subset(a$income_statement, reconciled)
#'
#' # the tables join on the key they share
#' merge(a$checks, a$audit)
#'
#' # just the one table, and only the work it needs
#' xbrl_accounts(x, what = "company")
#' }
#'
#' @seealso [read_xbrl()] for what goes in, [xbrl_lines()], [xbrl_company()]
#'   and [xbrl_movements()] for the tables one at a time, [check_cascade()]
#'   and [check_statement()] for the detail behind `reconciled`.
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_success
#' @importFrom cli cli_alert_info
#' @importFrom tibble tibble
#' @export
xbrl_accounts <- function(x, what = NULL,
                          basis = c("parent", "consolidated"),
                          persons = FALSE, taxonomy = NULL) {
  basis <- match.arg(basis)
  all_of <- c("company", "location", "audit", "checks",
              "income_statement", "balance", "movements", "prose")
  what <- if (is.null(what)) all_of else match.arg(what, all_of, several.ok = TRUE)

  if (!"file" %in% names(x))
    cli::cli_abort(c(
      "{.arg x} has no {.field file} column.",
      "i" = "It comes from {.fn read_xbrl}."))

  # One line saying how big the job is, then one line per table saying how it
  # went. The count belongs in the opening line and nowhere else -- read_xbrl()
  # has already said it once, and repeating it on every step buries the part
  # that differs.
  #
  # And what a stage reports when it finishes is how well the figures held up,
  # not how many seconds it took. A corpus takes minutes either way; whether
  # the statements reconcile is the thing worth reading.
  n <- length(unique(x$file))
  cli::cli_alert_info("{length(what)} table{?s} from {n} filing{?s}.")

  # No spinner around the stage. The functions below run a progress bar over
  # the filings, which is what actually moves, and two of them drawing on the
  # same line means neither is readable. So the stage says nothing until it is
  # finished, and then says how it went.
  step <- function(lab, expr) {
    r <- force(expr)
    # Computed first: a leading dot inside cli's braces is a literal, so
    # `{.stage_note(r)}` is read as markup rather than as a call.
    note <- .stage_note(r)
    cli::cli_alert_success("{lab} -- {note}")
    r
  }

  # The checks are the expensive part, so they run only for a table that asks
  # for them. `company` asks for all of them, because it reports every verdict.
  none <- stats::setNames(logical(), character())
  ok_income <- if (any(c("checks", "income_statement") %in% what))
    .reconciles(x, "income", basis) else none
  ok_balance <- if (any(c("checks", "balance") %in% what))
    .reconciles(x, "balance", basis) else none

  # The tables first and the company row last: it reports the others' verdicts,
  # and `out[what]` puts them back in the order asked for.
  out <- list()
  if ("income_statement" %in% what)
    out$income_statement <- step("Income statement", .with_verdict(
      xbrl_lines(x, "income", basis = basis, taxonomy = taxonomy), ok_income))
  if ("balance" %in% what)
    out$balance <- step("Balance sheet", .with_verdict(
      xbrl_lines(x, "balance", basis = basis, taxonomy = taxonomy), ok_balance))

  mv <- if (any(c("checks", "movements") %in% what))
    step("Fixed asset note", xbrl_movements(x, basis = basis)) else NULL
  if ("movements" %in% what) out$movements <- mv

  if (any(c("company", "location", "audit", "prose", "checks") %in% what)) {
    d <- step("Company", xbrl_company(x, persons = persons))
    d$income_reconciled  <- unname(ok_income[d$file])
    d$balance_reconciled <- unname(ok_balance[d$file])

    # Two verdicts from the note, because it answers two questions. Does every
    # block that could be checked close, and do the notes account for the fixed
    # assets the balance sheet carries? A note can do the first and not the
    # second: a schedule that rolls forward perfectly for land and buildings
    # says nothing about the machinery it never mentions.
    d$movements_reconciled <- unname(.by_file(mv$reconciled, mv$file)[d$file])
    d$movements_cover <-
      unname(.by_file(mv$covers_fixed_assets, mv$file)[d$file])

    grouped <- unlist(.COMPANY_GROUPS, use.names = FALSE)
    if ("company" %in% what)
      out$company <- .key_first(d[setdiff(names(d), grouped)])
    if ("location" %in% what) out$location <- .company_group(d, "location")
    if ("audit" %in% what)  out$audit  <- .company_group(d, "audit")
    if ("prose" %in% what)  out$prose  <- .company_group(d, "prose")
    if ("checks" %in% what) out$checks <- .company_group(d, "checks")
  }

  out <- out[what]
  ends <- x$period_end[!is.na(x$period_end)]
  attr(out, "failed")  <- attr(x, "failed")
  attr(out, "filings") <- length(unique(x$file))
  attr(out, "years")   <- if (length(ends)) range(ends) else NULL
  class(out) <- c("cvrr_accounts", "list")
  out
}

#' @export
print.cvrr_accounts <- function(x, ...) {
  n <- attr(x, "filings")
  yrs <- attr(x, "years")
  span <- if (is.null(yrs) || any(is.na(yrs))) NULL else
    paste(unique(format(yrs, "%Y")), collapse = "-")
  head <- paste(c(paste(format(n, big.mark = ","),
                        if (isTRUE(n == 1)) "filing" else "filings"), span),
                collapse = "  \u00b7  ")
  # cli::rule() rather than cli_rule(): a print method writes to stdout, and
  # the cli_* functions are messages, which go to stderr and are not captured
  # with the rest of the output.
  cat(cli::rule(left = cli::style_bold("cvrr accounts"), right = head), "\n",
      sep = "")

  # Padded before it is coloured: ANSI codes count as characters to sprintf,
  # so a coloured string cannot be given a width.
  nms  <- names(x)
  rows <- vapply(x, nrow, integer(1))
  fig  <- format(rows, big.mark = ",")
  w    <- max(nchar(nms))
  for (i in seq_along(nms)) {
    note <- .verdict_note(x[[nms[i]]])
    cat("  ", cli::col_cyan(formatC(nms[i], width = -w)), "  ",
        cli::style_bold(formatC(fig[i], width = max(nchar(fig)))), " ",
        cli::col_grey("rows"),
        if (nzchar(note)) paste0("   ", cli::col_grey(note)) else "", "\n",
        sep = "")
  }

  # Printed, not warned: a print method's output belongs on stdout, where it
  # can be captured with the rest of what it wrote.
  failed <- attr(x, "failed")
  if (length(failed))
    cat("  ", cli::col_yellow("!"), " ",
        format(length(failed), big.mark = ","),
        if (length(failed) == 1) " filing" else " filings",
        " could not be read ",
        cli::col_grey("attr(x, \"failed\")"), "\n", sep = "")
  invisible(x)
}
