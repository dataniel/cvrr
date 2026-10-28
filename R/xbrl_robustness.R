#' How robust a company is, and what it could withstand
#'
#' Takes a panel from [xbrl_panel()] (or [xbrl_ratios()]) and says, for each
#' company and year, which of the known signs of financial vulnerability it
#' shows, and how large a fall its figures could absorb.
#'
#' @section The factors:
#' Each is a logical column, `NA` where the figures to judge it are missing:
#'
#' * `negative_equity` -- equity below nought.
#' * `capital_lost` -- equity below half the contributed capital: the point
#'   at which Danish company law requires the board to act.
#' * `thin_equity` -- an equity ratio under 15%.
#' * `two_losses` -- a loss this year and the year before.
#' * `shortterm_heavy` -- short-term debt over half the assets.
#' * `weak_interest_cover` -- operating profit under 1.5 times the finance
#'   expenses.
#' * `weak_return` -- an operating return 5 percentage points or more under
#'   the median of comparable companies the same year (see `group`).
#' * `young` -- founded less than five years before the end of the year.
#' * `going_concern_factor` -- the auditor, or the filing itself, reports a
#'   material uncertainty about the company continuing. Where an auditor
#'   audited or reviewed the accounts and said nothing, it is `FALSE`. Where
#'   no auditor looked, it is `NA`.
#'
#' They are the variables of Danmarks Nationalbank's bankruptcy model
#' (Finansiel stabilitet 2005), with capital lost and going concern added
#' because a filing states them. `n_factors` counts those that are `TRUE`.
#'
#' @section What it could withstand:
#' * `gross_profit_buffer` -- how far the gross profit could fall, as a share,
#'   before the operating profit is gone, if staff costs and depreciation did
#'   not move. They usually fall a little with it, so this is the smaller
#'   end of the buffer. `NA` where there is no operating profit to lose.
#' * `cash_months` -- how many months of staff costs the cash covers.
#'
#' @section Have the factors held?:
#' A company that stops filing while the corpus goes on has most often
#' ceased, so the factors can be held against that. `attr(r, "validation")`
#' compares, for each factor, the share of companies that filed no further
#' annual report within two years, with the factor and without it, over the
#' years for which two later years are in the data. It is a proxy: a company
#' can also stop filing because it moved its year end, merged, or left the
#' data for a reason of the data's. It says whether a factor points the right
#' way, not how likely a failure is.
#'
#' Over 4,304 filings for 2020-2024, 4 to 6% of company-years without a
#' given factor were followed by no annual report within two years. With weak
#' interest cover, a weak return or capital lost it was 2.6 to 2.7 times as
#' many; with negative equity, two losses or a going concern uncertainty
#' about twice. Short-term debt
#' (1.8), thin equity (1.5) and youth (1.4) point the same way, more weakly.
#' By the count of factors: 4.8% with none, 13.5% with four or more.
#'
#' @param p A panel from [xbrl_panel()], or its [xbrl_ratios()].
#' @param group Columns that make companies comparable, for `weak_return`.
#'   Default `"class"`; see [xbrl_ratios()].
#'
#' @return `p` with the factor columns, `n_factors`, `gross_profit_buffer` and
#'   `cash_months` added, and the validation in `attr(r, "validation")`.
#'
#' @examples
#' \dontrun{
#' r <- xbrl_robustness(xbrl_panel(read_xbrl("materiale/xbrl")))
#' r[r$n_factors >= 3, c("cvr", "name", "period_end", "n_factors")]
#' attr(r, "validation")
#' }
#'
#' @seealso [xbrl_ratios()], [xbrl_panel()].
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom tibble tibble
#' @export
xbrl_robustness <- function(p, group = "class") {
  if (!"equity_ratio" %in% names(p)) p <- xbrl_ratios(p, group = group)
  cls <- class(p)
  prev <- .previous_row(p)
  lgl <- function(cond, ok) ifelse(ok, cond, NA)

  p$negative_equity <- lgl(p$equity < 0, !is.na(p$equity))
  p$capital_lost <- lgl(p$equity < 0.5 * p$contributed_capital,
                        !is.na(p$equity) & !is.na(p$contributed_capital) &
                          p$contributed_capital > 0)
  p$thin_equity <- lgl(p$equity_ratio < 0.15, !is.na(p$equity_ratio))
  last <- ifelse(is.na(prev), NA_real_, p$profit[prev])
  p$two_losses <- lgl(p$profit < 0 & last < 0, !is.na(p$profit) & !is.na(last))
  p$shortterm_heavy <- lgl(p$shortterm_debt_share > 0.5, !is.na(p$shortterm_debt_share))
  p$weak_interest_cover <- lgl(p$operating_profit < 1.5 * p$finance_expenses,
                               !is.na(p$operating_profit) & !is.na(p$finance_expenses) &
                                 p$finance_expenses > 0)
  p$weak_return <- lgl(p$operating_return < p$operating_return_median - 0.05,
                       !is.na(p$operating_return) & !is.na(p$operating_return_median))
  age <- as.numeric(p$period_end - p$founded) / 365.25
  p$young <- lgl(age < 5, !is.na(age))
  # An auditor who audited or reviewed the accounts and said nothing about
  # going concern found no material uncertainty: silence there is a no. Where
  # no auditor looked, silence is not an answer.
  examined <- "assurance" %in% names(p) &
    p$assurance %in% c("audit", "extended review", "review")
  p$going_concern_factor <- ifelse(p$going_concern %in% TRUE, TRUE,
                            ifelse(p$going_concern %in% FALSE | examined, FALSE, NA))

  fac <- .ROBUSTNESS_FACTORS
  p$n_factors <- rowSums(as.data.frame(lapply(fac, function(f) p[[f]] %in% TRUE)))

  p$gross_profit_buffer <- ifelse(!is.na(p$operating_profit) & p$operating_profit > 0 &
                                    !is.na(p$gross_profit) & p$gross_profit > 0,
                                  p$operating_profit / p$gross_profit, NA_real_)
  p$cash_months <- ifelse(!is.na(p$cash) & !is.na(p$staff_costs) & p$staff_costs > 0,
                          12 * p$cash / p$staff_costs, NA_real_)

  attr(p, "validation") <- .validate_factors(p, fac)
  class(p) <- cls
  .key_first(p)
}

.ROBUSTNESS_FACTORS <- c("negative_equity", "capital_lost", "thin_equity",
                         "two_losses", "shortterm_heavy", "weak_interest_cover",
                         "weak_return", "young", "going_concern_factor")

# For each factor: of the company-years with it and without it, the share
# whose company filed no annual report in the two years after. Only years
# with two later years in the data count, so a company is not called gone
# because the data ends.
.validate_factors <- function(p, fac) {
  last_year <- max(as.numeric(format(p$period_end, "%Y")), na.rm = TRUE)
  yr <- as.numeric(format(p$period_end, "%Y"))
  seen <- split(yr, p$cvr)
  later <- vapply(seq_len(nrow(p)), function(i) {
    y <- seen[[p$cvr[i]]]
    any(y > yr[i] & y <= yr[i] + 2)
  }, logical(1))
  use <- yr <= last_year - 2
  if ("basis" %in% names(p)) use <- use & p$basis == "parent"
  gone <- !later
  rows <- lapply(fac, function(f) {
    v <- p[[f]]
    w <- use & v %in% TRUE
    wo <- use & v %in% FALSE
    tibble::tibble(factor = f, with = sum(w), gone_with = mean(gone[w]),
                   without = sum(wo), gone_without = mean(gone[wo]))
  })
  out <- do.call(rbind, rows)
  out$ratio <- out$gone_with / out$gone_without
  out
}
