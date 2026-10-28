#' Key ratios, the change from last year, and the place among peers
#'
#' Takes a panel from [xbrl_panel()] and adds what an analysis reads off it:
#' the ratios the statistics offices publish, how each company moved since
#' its previous filing, and where it stands among comparable companies the
#' same year.
#'
#' @section The ratios:
#' The definitions are the statistics offices', not corporate finance's, so
#' that a figure here can be set beside a published one:
#'
#' * `equity_ratio` -- equity / assets (soliditetsgrad).
#' * `return_on_assets` -- profit after tax / assets (afkastningsgrad, as
#'   Statistics Greenland publishes it).
#' * `operating_return` -- operating profit / assets: the return before
#'   interest and tax, which is what a company's operation earns on what it
#'   has.
#' * `return_on_equity` -- profit / equity, `NA` where equity is not positive.
#' * `operating_margin` -- operating profit / revenue (overskudsgrad);
#'   `operating_share_of_gross` the same against the gross profit, which is
#'   what a class B filing has.
#' * `current_ratio` -- current assets / short-term debt (likviditetsgrad);
#'   `cash_ratio` cash / short-term debt.
#' * `debt_ratio` -- debt other than provisions / assets;
#'   `shortterm_debt_share` short-term debt / assets.
#' * `interest_coverage` -- operating profit / finance expenses.
#' * `staff_share` -- staff costs / gross profit (lonkvote). The gross profit
#'   of a Danish filing is revenue less goods and external costs, which is
#'   value added at factor cost, so `value_added` is it.
#' * `value_added_per_employee`, `profit_per_employee`.
#'
#' A ratio whose denominator is missing, nought, or of the wrong sign for the
#' ratio to mean anything is `NA`.
#'
#' @section The change from last year:
#' For a company with a filing for the year before -- its previous period
#' ending 11 to 13 months earlier -- `gross_profit_growth`, `revenue_growth`,
#' `assets_growth` and `equity_growth` are the relative changes and
#' `equity_ratio_change` is the change in percentage points. A company whose
#' previous figure was not positive has no growth rate, because a change from
#' a loss is not a percentage.
#'
#' @section Among peers:
#' `group` names the panel's columns that make companies comparable. The
#' default is the accounting class, because that is in every filing. A branch
#' of industry is a better comparison and is not in a filing: join it to the
#' panel on `cvr` and name its column here. For each group and year, the
#' median of `equity_ratio`, `operating_return`, `current_ratio` and
#' `return_on_equity` is added, with each company's percentile rank among
#' its peers (`*_pct`, 0 to 100). A group with fewer than `min_peers`
#' companies gets neither: a median of three companies is mostly one
#' company's figure.
#'
#' @param p A panel from [xbrl_panel()].
#' @param group Columns of `p` that make companies comparable. Default
#'   `"class"`.
#' @param min_peers Smallest group a median and a rank are computed for.
#'   Default `5`.
#'
#' @return `p` with the ratios, the changes and the peer columns added.
#'
#' @examples
#' \dontrun{
#' p <- xbrl_panel(read_xbrl("materiale/xbrl"))
#' r <- xbrl_ratios(p)
#' r[c("cvr", "period_end", "equity_ratio", "equity_ratio_pct")]
#'
#' # against a branch of industry from a register extract of your own
#' p$branch <- register$branch[match(p$cvr, register$cvr)]
#' r <- xbrl_ratios(p, group = "branch")
#' }
#'
#' @seealso [xbrl_panel()], and [xbrl_robustness()] for how vulnerable a
#'   company is.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom stats ave median
#' @export
xbrl_ratios <- function(p, group = "class", min_peers = 5) {
  need <- c("cvr", "period_end", "assets", "equity", "profit", "operating_profit")
  gone <- setdiff(c(need, group), names(p))
  if (length(gone))
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg p}: {.val {gone}}.",
      "i" = "{.arg p} comes from {.fn xbrl_panel}."))
  cls <- class(p)

  pos <- function(v) ifelse(!is.na(v) & v > 0, v, NA_real_)
  div <- function(a, b) a / pos(b)

  p$equity_ratio <- div(p$equity, p$assets)
  p$return_on_assets <- div(p$profit, p$assets)
  p$operating_return <- div(p$operating_profit, p$assets)
  p$return_on_equity <- div(p$profit, p$equity)
  p$operating_margin <- div(p$operating_profit, p$revenue)
  p$operating_share_of_gross <- div(p$operating_profit, p$gross_profit)
  p$current_ratio <- div(p$current_assets, p$shortterm_debt)
  p$cash_ratio <- div(p$cash, p$shortterm_debt)
  debt <- rowSums(cbind(p$longterm_debt, p$shortterm_debt), na.rm = TRUE)
  debt[is.na(p$longterm_debt) & is.na(p$shortterm_debt)] <- NA
  p$debt_ratio <- div(debt, p$assets)
  p$shortterm_debt_share <- div(p$shortterm_debt, p$assets)
  p$interest_coverage <- div(p$operating_profit, p$finance_expenses)
  p$value_added <- p$gross_profit
  p$staff_share <- div(p$staff_costs, p$gross_profit)
  p$value_added_per_employee <- div(p$gross_profit, p$employees)
  p$profit_per_employee <- div(p$profit, p$employees)

  # Last year's filing of the same company and basis.
  prev <- .previous_row(p)
  growth <- function(v) ifelse(!is.na(prev) & !is.na(v[prev]) & v[prev] > 0,
                               v / v[prev] - 1, NA_real_)
  p$gross_profit_growth <- growth(p$gross_profit)
  p$revenue_growth <- growth(p$revenue)
  p$assets_growth <- growth(p$assets)
  p$equity_growth <- growth(p$equity)
  p$equity_ratio_change <- ifelse(is.na(prev), NA_real_,
                                  p$equity_ratio - p$equity_ratio[prev])

  # Among peers, per group and year.
  yr <- format(p$period_end, "%Y")
  key <- do.call(paste, c(lapply(group, function(g) as.character(p[[g]])),
                          list(yr), sep = "\r"))
  if ("basis" %in% names(p)) key <- paste(key, p$basis, sep = "\r")
  size <- stats::ave(rep(1, nrow(p)), key, FUN = length)
  for (v in c("equity_ratio", "operating_return", "current_ratio", "return_on_equity")) {
    x <- p[[v]]
    ok <- !is.na(x)
    n_ok <- stats::ave(as.numeric(ok), key, FUN = sum)
    med <- stats::ave(x, key, FUN = function(z) stats::median(z, na.rm = TRUE))
    pct <- stats::ave(x, key, FUN = function(z) {
      r <- rep(NA_real_, length(z)); k <- !is.na(z)
      r[k] <- 100 * (rank(z[k]) - 0.5) / sum(k)
      r
    })
    thin <- n_ok < min_peers | size < min_peers
    med[thin] <- NA
    pct[thin | !ok] <- NA
    p[[paste0(v, "_median")]] <- med
    p[[paste0(v, "_pct")]] <- pct
  }
  attr(p, "group") <- group
  class(p) <- cls
  .key_first(p)
}

# For each row, the row of the same company and basis whose period ended 11
# to 13 months before: the previous annual report. NA where there is none.
.previous_row <- function(p) {
  b <- if ("basis" %in% names(p)) p$basis else rep("", nrow(p))
  k <- paste(p$cvr, b)
  prev <- rep(NA_integer_, nrow(p))
  for (idx in split(seq_len(nrow(p)), k)) {
    if (length(idx) < 2) next
    idx <- idx[order(p$period_end[idx])]
    gap <- as.numeric(diff(p$period_end[idx]))
    ok <- gap >= 330 & gap <= 400
    prev[idx[-1][ok]] <- idx[-length(idx)][ok]
  }
  prev
}
