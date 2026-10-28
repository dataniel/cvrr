#' The filings as a panel: one row per company and year
#'
#' Everything before this is about reading filings correctly; this is where
#' they become data to analyse. One row per filing and basis, the statement
#' figures as named variables -- `revenue`, `operating_profit`, `equity`,
#' `cash`, `cf_operating` -- beside who the company is and how far its figures
#' can be trusted. A time series of one company and a cross-section of many are
#' the same table, so whatever is computed from it works on either.
#'
#' @section Where the figures come from:
#' From [xbrl_lines()], not from the facts directly: a line the filer left out
#' of the balance sheet is derived there, a line tagged twice is settled, and
#' after [xbrl_standardise()] a figure in the wrong unit is already in the
#' right one. Each variable is read from a list of elements, the first one the
#' filing reports winning; the lists are in `attr(p, "variables")`.
#'
#' Most Danish filings are accounting class B, which may start the income
#' statement at the gross profit. `revenue` is then `NA`, not an estimate:
#' 13% of a 4,304-filing corpus report it, against 81% the gross profit.
#'
#' @section Signs:
#' One convention throughout. Incomes, balances and subtotals keep their
#' natural sign, so a loss is negative and so is negative equity. Costs are
#' positive amounts: 99% of filers write them so, and the rest have signed
#' them already. Tax is the one cost that is genuinely negative -- a refund, a
#' deferred tax asset -- in a fifth of filings, so where the result before
#' and after tax are both reported it is their difference, which has the
#' right sign by construction, and `net_financials` is likewise the result
#' before tax less the operating result.
#'
#' That makes `net_financials` the complete figure and `finance_income` and
#' `finance_expenses` only the lines called that. Income from subsidiaries and
#' impairment of financial assets are financial items too, and with them left
#' out the two lines account for the result before tax in 77% of the corpus.
#' Use `net_financials` for the total.
#'
#' @section How far to trust a row:
#' `balance_reconciled`, `income_reconciled` and `cashflow_reconciled` are the
#' verdicts of [check_statement()], [check_cascade()] and [check_cashflow()];
#' `corrections` counts the figures [xbrl_standardise()] changed in the
#' filing. A row is kept whatever they say: excluding is the analysis's
#' decision, and it can only be made if the row is there.
#'
#' @param x A tibble from [read_xbrl()].
#' @param basis `"parent"` (default), `"consolidated"`, or both. A filing with
#'   group accounts has a row for each basis asked for.
#' @param standardise Run [xbrl_standardise()] first, if it has not been.
#'   Default `TRUE`.
#'
#' @return A tibble of class `cvrr_panel`: the key (`cvr`, `name`,
#'   `period_start`, `period_end`), `basis`, the figures, the background
#'   (`class`, `form`, `micro`, `founded`, `assurance`, `opinion_kind`,
#'   `going_concern`, `in_group`, `group_accounts`, `employees`, `currency`),
#'   the trust columns,
#'   and `file`. Amounts are in the reporting currency as filed.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' p <- xbrl_panel(x)
#'
#' # one company over time
#' p[p$cvr == "12345678", c("period_end", "gross_profit", "operating_profit", "equity")]
#'
#' # the rows whose statements add up
#' subset(p, balance_reconciled & income_reconciled)
#' }
#'
#' @seealso [xbrl_lines()] for the statements line by line, [xbrl_screen()]
#'   for what does not add up.
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @importFrom tibble as_tibble
#' @export
xbrl_panel <- function(x, basis = "parent", standardise = TRUE) {
  basis <- match.arg(basis, c("parent", "consolidated"), several.ok = TRUE)
  if (!"file" %in% names(x))
    cli::cli_abort(c("{.arg x} has no {.field file} column.",
                     "i" = "It comes from {.fn read_xbrl}."))
  if (isTRUE(standardise) && !"standardised" %in% names(x))
    x <- suppressMessages(xbrl_standardise(x))
  n <- length(unique(x$file))
  cli::cli_alert_info("Building a panel of {n} filing{?s}.")

  rows <- lapply(basis, function(b) .panel_basis(x, b))
  out <- do.call(rbind, rows)
  if (is.null(out) || !nrow(out)) out <- .panel_skeleton()

  # Who the company is: the same for every basis of a filing.
  comp <- suppressMessages(xbrl_company(x, prose = FALSE))
  j <- match(out$file, comp$file)
  for (col in c("name", "class", "form", "micro", "founded", "assurance",
                "opinion_kind", "going_concern", "in_group", "group_accounts",
                "employees", "currency"))
    out[[col]] <- if (col %in% names(comp)) comp[[col]][j] else NA

  # How far to trust it.
  out$balance_reconciled <- NA
  out$income_reconciled <- NA
  out$cashflow_reconciled <- NA
  for (b in basis) {
    k <- out$basis == b
    ok_b <- .reconciles(x, "balance", b)
    ok_i <- .reconciles(x, "income", b)
    ok_c <- .cashflow_verdicts(x, b)$reconciled
    out$balance_reconciled[k] <- unname(ok_b[out$file[k]])
    out$income_reconciled[k] <- unname(ok_i[out$file[k]])
    out$cashflow_reconciled[k] <- unname(ok_c[out$file[k]])
  }
  log <- attr(x, "standardisation")
  done <- if (is.null(log)) character() else
    log$file[log$action %in% c("corrected comparative", "flipped sign")]
  out$corrections <- as.integer(table(factor(done, levels = unique(out$file)))[out$file])

  out <- .key_first(tibble::as_tibble(out))
  out <- out[order(out$cvr, out$period_end, out$basis), , drop = FALSE]
  attr(out, "variables") <- .PANEL_VARS
  class(out) <- c("cvrr_panel", class(out))
  cli::cli_alert_success("{nrow(out)} row{?s}, {length(unique(out$cvr))} compan{?y/ies}.")
  out
}

# Each variable, the statement it is read from, and the elements that can
# carry it, in order of preference. `cost` marks a figure kept as a positive
# amount whatever sign the filer gave it.
.PANEL_VARS <- list(
  revenue                = list(st = "income", el = "Revenue"),
  other_operating_income = list(st = "income", el = "OtherOperatingIncome"),
  gross_profit           = list(st = "income", el = c("GrossProfitLoss", "GrossResult")),
  raw_materials          = list(st = "income", el = c("RawMaterialsAndConsumablesUsed",
                                                      "CostOfSales"), cost = TRUE),
  external_expenses      = list(st = "income", el = c("OtherExternalExpenses",
                                                      "ExternalExpenses"), cost = TRUE),
  staff_costs            = list(st = "income", el = "EmployeeBenefitsExpense", cost = TRUE),
  depreciation           = list(st = "income", el = paste0(
    "DepreciationAmortisationExpenseAndImpairmentLossesOfPropertyPlantAndEquipment",
    "AndIntangibleAssetsRecognisedInProfitOrLoss"), cost = TRUE),
  operating_profit       = list(st = "income", el = "ProfitLossFromOrdinaryOperatingActivities"),
  finance_income         = list(st = "income", el = c("OtherFinanceIncome", "FinanceIncome")),
  finance_expenses       = list(st = "income", el = c("OtherFinanceExpenses",
                                                      "FinanceExpenses"), cost = TRUE),
  profit_before_tax      = list(st = "income", el = "ProfitLossFromOrdinaryActivitiesBeforeTax"),
  tax_reported           = list(st = "income", el = c("TaxExpense",
                                                      "TaxExpenseOnOrdinaryActivities")),
  profit                 = list(st = "income", el = "ProfitLoss"),

  assets                 = list(st = "balance", el = c("Assets", "LiabilitiesAndEquity")),
  noncurrent_assets      = list(st = "balance", el = "NoncurrentAssets"),
  intangible_assets      = list(st = "balance", el = "IntangibleAssets"),
  tangible_assets        = list(st = "balance", el = "PropertyPlantAndEquipment"),
  financial_assets       = list(st = "balance", el = "LongtermInvestmentsAndReceivables"),
  current_assets         = list(st = "balance", el = "CurrentAssets"),
  inventories            = list(st = "balance", el = "Inventories"),
  receivables            = list(st = "balance", el = "ShorttermReceivables"),
  trade_receivables      = list(st = "balance", el = "ShorttermTradeReceivables"),
  cash                   = list(st = "balance", el = "CashAndCashEquivalents"),
  equity                 = list(st = "balance", el = "Equity"),
  contributed_capital    = list(st = "balance", el = "ContributedCapital"),
  provisions             = list(st = "balance", el = "Provisions"),
  longterm_debt          = list(st = "balance", el = "LongtermLiabilitiesOtherThanProvisions"),
  shortterm_debt         = list(st = "balance", el = "ShorttermLiabilitiesOtherThanProvisions"),
  trade_payables         = list(st = "balance", el = "ShorttermTradePayables"),
  bank_debt              = list(st = "balance", el = "ShorttermDebtToBanks"),

  cf_operating           = list(st = "cashflow", el = "CashFlowsFromUsedInOperatingActivities"),
  cf_investing           = list(st = "cashflow", el = "CashFlowsFromUsedInInvestingActivities"),
  cf_financing           = list(st = "cashflow", el = "CashFlowsFromUsedInFinancingActivities")
)

# One basis: the three statements' lines, widened to one row per filing.
.panel_basis <- function(x, basis) {
  st <- c(income = "income", balance = "balance", cashflow = "cashflow")
  lines <- lapply(st, function(s)
    tryCatch(suppressMessages(xbrl_lines(x, s, basis = basis)),
             error = function(e) NULL))
  files <- unique(unlist(lapply(lines, function(l) l$file)))
  if (!length(files)) return(NULL)

  out <- data.frame(file = files, basis = basis, stringsAsFactors = FALSE)
  key <- unique(do.call(rbind, lapply(lines, function(l)
    if (is.null(l) || !nrow(l)) NULL else
      as.data.frame(l[c("file", "cvr", "period_start", "period_end")]))))
  key <- key[!duplicated(key$file), , drop = FALSE]
  i <- match(out$file, key$file)
  out$cvr <- key$cvr[i]
  out$period_start <- key$period_start[i]
  out$period_end <- key$period_end[i]

  for (v in names(.PANEL_VARS)) {
    spec <- .PANEL_VARS[[v]]
    l <- lines[[spec$st]]
    out[[v]] <- if (is.null(l) || !nrow(l)) NA_real_ else
      .first_element(l, out$file, spec$el)
    if (isTRUE(spec$cost)) out[[v]] <- abs(out[[v]])
  }

  # Signed by identity where the identity is there: the difference of two
  # subtotals has the right sign whatever the filer wrote.
  out$tax <- ifelse(!is.na(out$profit_before_tax) & !is.na(out$profit),
                    out$profit_before_tax - out$profit, out$tax_reported)
  out$net_financials <- out$profit_before_tax - out$operating_profit
  out$ebitda <- out$operating_profit + ifelse(is.na(out$depreciation), 0,
                                              out$depreciation)
  out$ebitda[is.na(out$operating_profit)] <- NA
  out$tax_reported <- NULL
  out
}

# For each file, the value of the first element in `els` it reports.
.first_element <- function(l, files, els) {
  v <- rep(NA_real_, length(files))
  for (e in rev(els)) {
    m <- l[l$elementid == e & !is.na(l$value), c("file", "value")]
    m <- m[!duplicated(m$file), , drop = FALSE]
    hit <- match(files, m$file)
    v[!is.na(hit)] <- m$value[hit[!is.na(hit)]]
  }
  v
}

.panel_skeleton <- function() {
  out <- data.frame(file = character(), basis = character(), cvr = character(),
                    period_start = as.Date(character()),
                    period_end = as.Date(character()), stringsAsFactors = FALSE)
  for (v in c(setdiff(names(.PANEL_VARS), "tax_reported"), "tax",
              "net_financials", "ebitda"))
    out[[v]] <- numeric()
  out
}

#' @export
print.cvrr_panel <- function(x, ...) {
  if (!all(c("cvr", "period_end") %in% names(x))) return(invisible(NextMethod()))
  yrs <- range(x$period_end, na.rm = TRUE)
  head <- sprintf("%s rows  ·  %s companies  ·  %s",
                  format(nrow(x), big.mark = ","),
                  format(length(unique(x$cvr)), big.mark = ","),
                  if (all(is.finite(yrs))) paste(unique(format(yrs, "%Y")), collapse = "-") else "")
  cat(cli::rule(left = cli::style_bold("cvrr panel"), right = head), "\n", sep = "")
  NextMethod()
}
