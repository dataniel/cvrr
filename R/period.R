#' The accounting period a filing declares
#'
#' A filing states its own reporting period as facts, and the preceding one
#' alongside it. Reading them beats inferring the period from the contexts:
#' the contexts hold whatever periods the filer happened to tag, comparatives
#' and note periods included, so the latest is not reliably the accounting year
#' and the earliest is not reliably its start.
#'
#' @section The taxonomy's typo:
#' The preceding period's end is `PredingReportingPeriodEndDate` -- not
#' *Preceding*, which is how its own start date is spelled two elements
#' earlier. The misspelling is in the published taxonomy, so it is what filings
#' carry and what this looks for. Both spellings are accepted, because a filer
#' who corrects it should not be punished for it.
#'
#' @section How often it is there:
#' Across 4,304 Danish filings from 2020-2024 every one declared its current
#' period, and 3,950 declared the preceding one -- a filing states both dates
#' of a period or neither. So this is a reliable route rather than a lucky one
#' -- but `NA` still comes back where a filing is silent, and callers should
#' have a fallback rather than assume.
#'
#' @param x A tibble from [read_xbrl()].
#'
#' @return A one-row tibble with `start`, `end`, `prev_start` and `prev_end` as
#'   `Date`. A field the filing does not declare is `NA`. Where a filing states
#'   a date more than once, the first is taken.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("filing.xml")
#' p <- xbrl_period(x)
#'
#' # the opening balance of the year is the closing balance of the one before
#' p$prev_end
#' }
#'
#' @seealso [read_xbrl()], and [check_movement()], which uses this to pair an
#'   opening balance with the year its movements cover.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom tibble tibble
#' @export
xbrl_period <- function(x) {
  if (!all(c("elementid", "fact") %in% names(x)))
    cli::cli_abort("{.arg x} must be a tibble from {.fn read_xbrl}.")

  one <- function(els) {
    v <- x$fact[x$elementid %in% els]
    v <- v[!is.na(v)]
    if (length(v) == 0) return(as.Date(NA))
    suppressWarnings(as.Date(v[1]))
  }
  tibble::tibble(
    start      = one("ReportingPeriodStartDate"),
    end        = one("ReportingPeriodEndDate"),
    prev_start = one(c("PrecedingReportingPeriodStartDate",
                       "PredingReportingPeriodStartDate")),
    prev_end   = one(c("PredingReportingPeriodEndDate",
                       "PrecedingReportingPeriodEndDate"))
  )
}
