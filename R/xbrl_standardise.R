#' Put the tagging right: figures in the wrong unit, signs the wrong way
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
#' @section Signs in the cash flow statement:
#' A line in investing or financing whose activity does not add up as
#' tagged, and does add up with that one line reversed, has its sign reversed.
#' The statement itself says which way the filer meant it. The same test is
#' made one level up, of the three activities against the change in cash.
#'
#' What is not touched is as important. A line whose activity adds up as
#' tagged keeps its sign, however its sign looks beside its element, because
#' then the sign means something. A sale of a company reported negative in an
#' investing activity that adds up with it -- Greenland Airports' grant taken
#' to income, in its 2025 group accounts -- is a misclassification for the
#' screen to find, not a sign to correct. Where several lines would each make
#' the activity add up, none is reversed and the case is listed as undecided.
#' Operating is left alone, because its lines are the income statement's own
#' facts.
#'
#' @param x A tibble from [read_xbrl()]. For units, several years of at least
#'   some companies. A company with one filing has no units to compare and
#'   keeps its figures.
#' @param what Which to standardise: `"units"`, `"signs"`, or both, the
#'   default. Units go first, because a figure in the wrong unit would make a
#'   statement fail to add up for a reason of its own.
#' @param tol Absolute tolerance, in the reporting currency, for whether an
#'   activity adds up. Default `1`.
#'
#' @return `x`, with `value` corrected where a figure was in the wrong unit
#'   or had its sign reversed, and the columns `value_tagged` and
#'   `standardised` added. Attribute `"standardisation"` is a tibble with one
#'   row per figure looked at: `kind` (`"unit"` or `"sign"`), the filing, the
#'   company, the element, the date, the figure as tagged and as standardised,
#'   `action` (`"corrected comparative"`, `"flipped sign"` or `"undecided"`)
#'   and `detail`.
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
xbrl_standardise <- function(x, what = c("units", "signs"), tol = 1) {
  what <- match.arg(what, several.ok = TRUE)
  need <- c("file", "cvr", "elementid", "value", "period", "period_end", "basis",
            "is_line", "instant")
  gone <- setdiff(need, names(x))
  if (length(gone))
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} comes from {.fn read_xbrl}, with the taxonomy on it."))

  if (!"value_tagged" %in% names(x)) x$value_tagged <- x$value
  if (!"standardised" %in% names(x)) x$standardised <- NA_character_

  logs <- list()
  if ("units" %in% what) {
    r <- .standardise_units(x)
    x <- r$x
    logs$units <- r$log
  }
  # Signs after units: a sign is judged by whether a statement adds up, and a
  # figure in the wrong unit would make it fail for a reason of its own.
  if ("signs" %in% what && all(c("statement", "code", "balance") %in% names(x))) {
    r <- .standardise_signs(x, tol)
    x <- r$x
    logs$signs <- r$log
  }
  log <- tibble::as_tibble(data.table::rbindlist(
    c(list(.empty_standardisation()), logs), fill = TRUE))
  attr(x, "standardisation") <- log
  if (nrow(log)) {
    done <- log$action %in% c("corrected comparative", "flipped sign")
    cli::cli_alert_success(
      "{sum(done & log$kind == 'unit')} figure{?s} put back in the right unit, {sum(done & log$kind == 'sign')} sign{?s} reversed, {sum(!done)} left undecided.")
  }
  x
}

# ---- units ------------------------------------------------------------------

.standardise_units <- function(x) {
  none <- list(x = x, log = NULL)
  line <- x$is_line %in% TRUE & !is.na(x$value)
  if (!any(duplicated(unique(x[line, c("cvr", "period_end")])$cvr))) return(none)

  cc <- check_continuity(x[line, , drop = FALSE], filing = "period_end")
  sc <- cc[cc$verdict %in% "scaled", , drop = FALSE]
  if (!nrow(sc)) return(none)

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
      kind = "unit", file = later, cvr = r$cvr, elementid = r$elementid,
      period = r$period, value_tagged = r$opening,
      value = if (is.na(f)) r$opening else r$opening * f, action = action,
      detail = sprintf("closed at %s in %s; this filing's own year %s",
                       .std_num(r$closing), format(r$closed_in),
                       if (length(third)) .std_num(third) else "not stated"),
      stringsAsFactors = FALSE)
  }
  list(x = x, log = do.call(rbind, log_rows))
}

# ---- signs in the cash flow statement --------------------------------------

# A line whose sign makes its activity fail to add up, where reversing it --
# and only it -- makes the activity add up. That is a tagging error: the filer
# wrote an outflow as an inflow or the reverse, and the statement itself says
# which. A line whose activity adds up as tagged is left alone however its
# sign looks beside its element, because then the sign means something: a
# sale of a company reported negative, in an investing activity that adds up
# with it, is a misclassification to find, not a sign to correct.
#
# The same test is then made one level up: the activities against the change
# in cash, where exactly one activity reversed makes them agree.
.standardise_signs <- function(x, tol) {
  cfr <- which(x$statement %in% "CashFlowStatement" & x$is_line %in% TRUE &
                 !is.na(x$value) & !is.na(x$period) & !is.na(x$period_end) &
                 x$period == x$period_end & !x$abstract %in% TRUE &
                 !is.na(x$code))
  if (!length(cfr)) return(list(x = x, log = NULL))
  grp <- split(cfr, paste(x$file[cfr], x$basis[cfr], sep = "\r"))
  log <- list()

  # Every copy of a fact: the same element, filing, basis and year, in every
  # statement it is placed in, so the figure stays one figure.
  flip <- function(x, file, basis, el, period_end, why) {
    rows <- which(x$file == file & x$basis == basis & x$elementid == el &
                    x$is_line %in% TRUE & !is.na(x$period) &
                    x$period == period_end)
    x$value[rows] <- -x$value[rows]
    x$standardised[rows] <- ifelse(is.na(x$standardised[rows]), why,
                                   paste(x$standardised[rows], why, sep = "; "))
    x
  }
  note <- function(cf, el, action, detail)
    data.frame(kind = "sign", file = cf$file[1], cvr = cf$cvr[1],
               elementid = el, period = as.character(cf$period_end[1]),
               value_tagged = cf$value[match(el, cf$elementid)],
               value = if (action == "flipped sign")
                 -cf$value[match(el, cf$elementid)] else cf$value[match(el, cf$elementid)],
               action = action, detail = detail, stringsAsFactors = FALSE)

  for (gi in grp) {
    cf <- x[gi, , drop = FALSE]
    cf <- cf[!duplicated(cf$elementid), , drop = FALSE]
    sect <- .cf_section_of(cf)
    out_pos <- .outflows_positive(cf, sect)

    # Lines within investing and financing. Operating is left alone: its
    # lines are the income statement's own facts, and reversing one would
    # reverse it there too.
    for (nm in c("investing", "financing")) {
      i <- match(.CF$sections[[nm]], cf$elementid)
      if (is.na(i)) next
      kids <- which(cf$code %in% .nearest_children(cf, cf$code[i])$code)
      if (!length(kids)) next
      contrib <- .cf_direction(cf$value[kids], cf$balance[kids], out_pos)
      res <- cf$value[i] - sum(contrib)
      if (abs(res) <= tol) next
      # Reversing line k moves the sum by twice its contribution.
      fix <- which(abs(res + 2 * contrib) <= tol & contrib != 0)
      if (length(fix) == 1) {
        el <- cf$elementid[kids[fix]]
        why <- sprintf("sign: reversed, %s adds up only that way", nm)
        x <- flip(x, cf$file[1], cf$basis[1], el, cf$period_end[1], why)
        log[[length(log) + 1L]] <- note(cf, el, "flipped sign", why)
        cf$value[kids[fix]] <- -cf$value[kids[fix]]
      } else if (length(fix) > 1) {
        log[[length(log) + 1L]] <- note(cf, paste(cf$elementid[kids[fix]], collapse = ", "),
          "undecided", sprintf("%s adds up with any one of %d lines reversed",
                               nm, length(fix)))
      }
    }

    # The activities against the change in cash.
    sec_i <- match(.CF$sections, cf$elementid)
    target <- cf$value[match(c(.CF$before_fx, .CF$change), cf$elementid)]
    target <- target[!is.na(target)][1]
    if (is.na(target) || sum(!is.na(sec_i)) < 2) next
    v <- cf$value[sec_i[!is.na(sec_i)]]
    res <- target - sum(v)
    if (abs(res) <= tol) next
    # The exchange rate adjustment explains it already: nothing to reverse.
    fx <- cf$value[match(.CF$fx, cf$elementid)]
    if (!is.na(fx) && abs(res - fx) <= tol) next
    fix <- which(abs(res + 2 * v) <= tol & v != 0)
    if (length(fix) == 1) {
      el <- cf$elementid[sec_i[!is.na(sec_i)][fix]]
      why <- "sign: reversed, the activities sum to the change in cash only that way"
      x <- flip(x, cf$file[1], cf$basis[1], el, cf$period_end[1], why)
      log[[length(log) + 1L]] <- note(cf, el, "flipped sign", why)
    }
  }
  list(x = x, log = if (length(log)) do.call(rbind, log) else NULL)
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
  data.frame(kind = character(), file = character(), cvr = character(),
             elementid = character(), period = character(),
             value_tagged = numeric(), value = numeric(), action = character(),
             detail = character(), stringsAsFactors = FALSE)

.std_num <- function(v) format(round(v), big.mark = ",", scientific = FALSE, trim = TRUE)
