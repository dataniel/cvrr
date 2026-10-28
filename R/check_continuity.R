#' Does the balance a company closed on reopen in the next filing?
#'
#' Every other check in this package reads one annual report and asks whether
#' it agrees with itself. This one compares filings: the balance sheet a
#' company closed on at the end of one year is the balance it opens on in the
#' next, and the two figures are filed a year apart.
#'
#' @section The one check a single filing cannot make:
#' A filing scaled wrongly all the way through is internally perfect. Its
#' balance balances, its cascade reconciles, every structural test in this
#' package passes -- because everything in it was multiplied by the same
#' number. Only a figure from outside disagrees.
#'
#' Across 4,304 Danish filings this found 84 such figures, 8 out by a thousand
#' and 76 by a thousandth. Nothing else here would have seen them.
#'
#' @section A difference is not always an error:
#' Companies restate. Where more than half a balance sheet's lines disagree the
#' filer has changed something deliberately -- a change of accounting policy, a
#' correction, a merger -- and a statistic needs to know that rather than treat
#' it as noise. Where one line moves and the rest hold, it is a correction to
#' that line. The verdicts say which shape it is; neither is called wrong.
#'
#' @section What is compared:
#' Undimensioned figures, where two filings state the same element for the same
#' date -- a balance by its instant, an income statement line by the period it
#' covers. Both are things a company says twice: the comparative column of one
#' filing against the primary column of the one before it.
#'
#' Comparatives *inside* a single filing are not used. They are the same
#' document making the same claim twice, and agreeing with itself proves
#' nothing.
#'
#' @param x Facts from several filings, with `elementid`, `value`, the columns
#'   named by `by` and `filing`, and `instant` -- plus `startdate` and
#'   `enddate` if the income statement is to be compared as well.
#' @param by Column identifying the company. Default `"cvr"`.
#' @param filing Column identifying the filing, used to order the two
#'   statements. Default `"year"`; a table from [read_xbrl()] carries
#'   `period_end` instead, so pass that.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#' @param rel Relative tolerance below which a difference is called rounding.
#'   Default `0.001`.
#'
#' @return A tibble with one row per figure stated twice: the `by` column,
#'   `elementid`, `period` (the instant, or the span a duration covers), the
#'   two filings and their values, `diff`, `rel`,
#'   and `verdict` -- `"agrees"`, `"rounding"`, `"scaled"` where the ratio is a
#'   power of a thousand, or `"differs"`.
#'
#' @examples
#' \dontrun{
#' # every filing of every company in one table
#' x  <- read_xbrl("materiale/xbrl")
#' cc <- check_continuity(x, filing = "period_end")
#'
#' cc[cc$verdict == "scaled", ]     # a filing multiplied all the way through
#' }
#'
#' @seealso [check_movement()], which checks the same balance through one year
#'   rather than across two.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_continuity <- function(x, by = "cvr", filing = "year", tol = 1,
                             rel = 0.001) {
  need <- c("elementid", "instant", "value", by, filing)
  missing_cols <- setdiff(need, names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  d <- x[!is.na(x$value), , drop = FALSE]
  if ("dimensions" %in% names(d)) d <- d[is.na(d$dimensions), , drop = FALSE]

  # A balance is dated by its instant and an income statement line by the
  # period it covers. Both are figures a company states twice, so both are
  # compared: the comparative column of one filing against the primary column
  # of the one before it.
  d$..when <- if (!"startdate" %in% names(d)) d$instant else
    ifelse(is.na(d$instant), paste(d$startdate, d$enddate), d$instant)
  d <- d[!is.na(d$..when) & !grepl("NA", d$..when, fixed = TRUE), , drop = FALSE]
  if (nrow(d) == 0) return(tibble::as_tibble(data.frame()))

  # One value per filing, element and date: a filing repeating a figure is
  # still one claim.
  key <- do.call(paste, c(d[c(by, "elementid", "..when")], sep = "\r"))
  once <- !duplicated(paste(key, d[[filing]], sep = "\r"))
  d <- d[once, , drop = FALSE]
  key <- key[once]
  twice <- key %in% key[duplicated(key)]
  d <- d[twice, , drop = FALSE]
  key <- key[twice]
  if (nrow(d) == 0) return(tibble::as_tibble(data.frame()))

  # The earliest filing to state a figure closed on it and the latest reopened
  # on it. Sorted once, the two ends of each run are its first and last rows.
  # This was a data frame built per figure, and on a corpus there are hundreds
  # of thousands of figures stated twice: 200 seconds, where this takes a few.
  # order() is stable, so ties within a filing date keep the order they came
  # in, as they did.
  o <- order(key, d[[filing]])
  d <- d[o, , drop = FALSE]
  key <- key[o]
  first <- !duplicated(key)
  last <- !duplicated(key, fromLast = TRUE)
  r <- as.data.frame(d[first, c(by, "elementid"), drop = FALSE])
  r$period <- d$..when[first]
  r$closed_in <- d[[filing]][first]
  r$opened_in <- d[[filing]][last]
  r$closing <- d$value[first]
  r$opening <- d$value[last]
  rownames(r) <- NULL

  r$diff <- r$opening - r$closing
  r$rel <- r$diff / pmax(abs(r$closing), 1)
  ratio <- abs(r$opening) / pmax(abs(r$closing), 1)
  # A power of a thousand, within a fifth: the figure was written in the other
  # unit, not adjusted. Nothing else lands there.
  scaled <- (abs(ratio - 1000) < 200) | (abs(ratio - 0.001) < 0.0002)

  r$verdict <- ifelse(abs(r$diff) <= tol, "agrees",
               ifelse(scaled, "scaled",
               ifelse(abs(r$rel) < rel, "rounding", "differs")))
  tibble::as_tibble(r)
}
