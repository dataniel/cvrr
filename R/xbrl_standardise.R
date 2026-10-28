#' Put figures written in the wrong unit back in the right one
#'
#' A filing tags each figure in kroner, and now and then a line is tagged in
#' thousands instead -- most often in the comparative column, so that last
#' year's land and buildings of 2,981,848 reappears this year as 2,982. That
#' is a technicality of the tagging, not a fact about the company, and left in
#' place it reads as the company's accounts changing by a factor of a
#' thousand. This finds such figures between filings and puts them back.
#'
#' @section Which figure is the wrong one:
#' A figure stated in two filings that disagree by a power of a thousand has
#' two candidates for the mistake. A third figure can decide: the later
#' filing's own figure for the same line in its own year. If it is of the
#' earlier filing's order, the later filing disagrees with itself -- its
#' comparative column is in a different unit from its own year -- and that is
#' proof enough. The comparative is corrected.
#'
#' The opposite case is not settled. When the later filing's two columns agree
#' and the earlier filing is the odd one, the earlier filing may be wrong, or
#' the later filing may be tagged in thousands throughout. The two look the
#' same from here. The figure is listed as undecided and left as it is.
#'
#' Over 4,304 filings for 2020-2024, 147 figures were corrected and 49 left
#' undecided. A filing with a corrected comparative typically had three lines
#' affected, about a sixth of its comparable balances: a column tagged in the
#' wrong unit, not a company reporting in thousands.
#'
#' @section What changes:
#' The figure is multiplied or divided by the power of a thousand that brings
#' it into line, so its own digits are kept and only the unit moves. Every
#' copy of the fact moves with it: the same element, filing, date and basis.
#' `value_tagged` keeps the figure as tagged and `standardised` says why it
#' moved, on every row that did; elsewhere they are the value and `NA`.
#' Nothing else in the filing is touched.
#'
#' @param x A tibble from [read_xbrl()], with several years of at least some
#'   companies. A company with one filing has nothing to compare and is
#'   returned as it came.
#'
#' @return `x`, with `value` corrected where a figure was in the wrong unit
#'   and the columns `value_tagged` and `standardised` added. Attribute
#'   `"standardisation"` is a tibble with one row per figure looked at: the
#'   company, the element, the date, the two filings, the figures and what was
#'   done (`"corrected comparative"` or `"undecided"`).
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' x <- xbrl_standardise(x)
#' attr(x, "standardisation")
#' x[!is.na(x$standardised), c("cvr", "elementid", "value_tagged", "value")]
#' }
#'
#' @seealso [check_continuity()], which finds these figures, and
#'   [xbrl_screen()], which standardises before it screens.
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @importFrom tibble as_tibble
#' @export
xbrl_standardise <- function(x) {
  need <- c("file", "cvr", "elementid", "value", "period", "period_end", "basis",
            "is_line", "instant")
  gone <- setdiff(need, names(x))
  if (length(gone))
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} comes from {.fn read_xbrl}, with the taxonomy on it."))

  if (!"value_tagged" %in% names(x)) x$value_tagged <- x$value
  if (!"standardised" %in% names(x)) x$standardised <- NA_character_
  attr(x, "standardisation") <- .empty_standardisation()

  line <- x$is_line %in% TRUE & !is.na(x$value)
  if (!any(duplicated(unique(x[line, c("cvr", "period_end")])$cvr))) return(x)

  cc <- check_continuity(x[line, , drop = FALSE], filing = "period_end")
  sc <- cc[cc$verdict %in% "scaled", , drop = FALSE]
  if (!nrow(sc)) return(x)

  # The later filing's own figure for the line, in its own year: the third
  # figure that says which of the two disagreeing ones is the odd one out.
  # `==`, not %in%: %in% asks whether the date is any filing's period end, and
  # a comparative's date always is -- the earlier filing's -- so the later
  # filing's comparative was taken for its own figure and the wrong one moved.
  own <- line & !is.na(x$period_end) & !is.na(x$period) &
    x$period == x$period_end
  own_key <- paste(x$cvr, x$period_end, x$elementid, x$basis)[own]
  files <- unique(x[c("cvr", "period_end", "file")])
  files <- files[!duplicated(files[c("cvr", "period_end")]), , drop = FALSE]
  file_of <- function(cvr, end)
    files$file[match(paste(cvr, end), paste(files$cvr, files$period_end))]

  log_rows <- vector("list", nrow(sc))
  for (i in seq_len(nrow(sc))) {
    r <- sc[i, ]
    later <- file_of(r$cvr, r$opened_in)
    when <- .period_rows(x, r$period)
    # The basis of the figure in the later filing: the comparison is only of
    # undimensioned lines, and a filing states its parent and its group apart.
    in_later <- which(line & x$file %in% later & x$elementid == r$elementid & when)
    basis <- if (length(in_later)) x$basis[in_later[1]] else NA_character_
    third <- x$value[own][match(paste(r$cvr, r$opened_in, r$elementid, basis),
                                own_key)]
    same <- function(a, b) !is.na(a) && !is.na(b) && a != 0 && b != 0 &&
      abs(log10(abs(a / b))) < 1.5
    # Only the case the later filing proves against itself: its own two
    # columns disagree by a power of a thousand, and the earlier filing agrees
    # with its own year. The other case -- the later filing's columns agree,
    # and the earlier filing is the odd one -- looks the same as a later filing
    # tagged in thousands throughout, so it is not settled here.
    action <- if (length(third) && same(third, r$closing) && !same(third, r$opening))
                "corrected comparative"
              else "undecided"
    if (action == "corrected comparative") {
      f <- .thousands(r$closing / r$opening)
      rows <- which(line & x$file %in% later & x$elementid == r$elementid &
                      x$basis %in% basis & when)
    } else {
      f <- NA_real_
      rows <- integer()
    }
    if (length(rows)) {
      x$value[rows] <- x$value_tagged[rows] * f
      x$standardised[rows] <- sprintf(
        "unit: x%s, comparative to agree with the earlier filing and this one's own year",
        format(f, big.mark = ",", scientific = FALSE))
    }
    log_rows[[i]] <- data.frame(
      cvr = r$cvr, elementid = r$elementid, period = r$period,
      closed_in = r$closed_in, opened_in = r$opened_in, closing = r$closing,
      opening = r$opening, later_own = if (length(third)) third else NA_real_,
      factor = f, action = action, stringsAsFactors = FALSE)
  }
  log <- tibble::as_tibble(do.call(rbind, log_rows))
  attr(x, "standardisation") <- log
  fixed <- sum(log$action != "undecided")
  cli::cli_alert_success(
    "{fixed} figure{?s} put back in the right unit, {sum(log$action == 'undecided')} undecided.")
  x
}

# The rows of `x` dated as check_continuity() writes a period: an instant as
# one date, a duration as its two.
.period_rows <- function(x, period) {
  if (grepl(" ", period, fixed = TRUE)) {
    p <- strsplit(period, " ", fixed = TRUE)[[1]]
    !is.na(x$startdate) & !is.na(x$enddate) &
      as.character(x$startdate) == p[1] & as.character(x$enddate) == p[2]
  } else {
    !is.na(x$instant) & as.character(x$instant) == period
  }
}

# The power of a thousand nearest a ratio: 1000, 1e6, 0.001, ...
.thousands <- function(ratio) 1000^round(log10(abs(ratio)) / 3)

.empty_standardisation <- function()
  tibble::tibble(cvr = character(), elementid = character(), period = character(),
                 closed_in = as.Date(character()), opened_in = as.Date(character()),
                 closing = numeric(), opening = numeric(), later_own = numeric(),
                 factor = numeric(), action = character())
