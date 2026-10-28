#' Reconcile a cash flow statement, and tie it to the balance sheet
#'
#' A cash flow statement can be wrong in a way its own arithmetic never shows.
#' Move an amount from one activity to another and every total still adds up:
#' the three activities still sum to the change in cash, and the change still
#' carries last year's cash to this year's. So this asks two kinds of question.
#' Does the statement agree with itself? And does it agree with the balance
#' sheet it was drawn up from?
#'
#' @section The case it was written for:
#' In its 2025 group accounts, Greenland Airports -- Mittarfeqarfiit A/S (CVR
#' 12859724) reported "Optagelse af langfristet gaeld" of DKK 1,157 million
#' under financing. The group's long-term liabilities, read off the balance
#' sheet in the same filing, rose by 793 million. The other 364 million was not
#' debt. It shows up again in investing, as "Indtaegtsfoert anlaegstilskud"
#' -364 million, a grant taken to income, tagged in the XBRL as
#' `SaleOfOtherCompany`. Taking a grant to income moves no cash at all, and a
#' sale does not take cash out. Sermitsiaq reported the misclassification in
#' September 2026, and the company said it would correct it in the next year's
#' report.
#'
#' Every internal check passes on that filing. The activities sum to the change
#' in cash, the change rolls forward, and the closing cash equals the balance
#' sheet's to the krone. The error shows up only when the cash flow is held
#' against the balance sheet, and that comparison is what this function adds.
#'
#' @section The checks:
#' One row per check per filing, in `check`:
#'
#' * `"activities"` -- operating, investing and financing sum to the change in
#'   cash, before the effect of exchange rates where the filing states it.
#' * `"rollforward"` -- the opening cash plus the change is the closing cash.
#'   Whether the change already includes the exchange rate adjustment is the
#'   filer's reading, so both are tried, and `"agrees, adjusted"` with
#'   `adjustment = "exchange rates"` says the adjustment was needed.
#' * `"cash vs balance"` -- the closing cash in the cash flow statement is the
#'   cash in the balance sheet. A filing may count securities as cash and an
#'   overdraft against it, so `"agrees, adjusted"` means one of those
#'   adjustments closes the gap and `adjustment` names it.
#' * `"untagged: investing"`, `"untagged: financing"` -- how much of an
#'   activity's total no tagged line accounts for. On its own this is not an
#'   error: a filer may leave a line untagged, or tag it with an element the
#'   taxonomy places elsewhere. But a reclassification has to leave one
#'   somewhere, and this is where it lands.
#' * `"sign: investing"`, `"sign: financing"` -- one row per line whose sign
#'   contradicts its element: a sale, a proceeds or a raising of debt that
#'   took cash out. `elementid` names the line. Mistagging is common and
#'   usually harmless, so this is a lead and not a verdict on the filing.
#' * `"debt vs balance"` -- net borrowing in the cash flow statement against the
#'   change in long-term liabilities, including their short-term part, in the
#'   balance sheet.
#' * Six more ties to the rest of the filing, each comparing magnitudes:
#'   `"depreciation vs income"` (the add-back against the income statement's
#'   charge), `"purchases vs note: tangible"` and `"... intangible"` (cash
#'   spent against the fixed asset note's additions), `"capital vs equity"`
#'   (a cash capital increase against the change in contributed capital and
#'   share premium), `"dividends vs proposed"` (paid this year against
#'   proposed at the end of the last) and `"inventories vs balance"`. The
#'   verdict is `"agrees"`, `"cash flow larger"` or `"cash flow smaller"`.
#'
#' The ties differ from the internal checks in one respect. Each has a known
#' reason to differ -- an asset leased rather than bought, debt converted to
#' equity, an extraordinary dividend -- so they are judged within `rel` rather
#' than to the krone, and the verdict says which way a gap runs, because the
#' direction is what tells a reason from a mistake.
#'
#' For debt, `"owed more than borrowed"` is the common case: the liability
#' grew by more than the cash raised, and a lease explains it. `"fell more than
#' repaid"` is a reclassification or a conversion. `"borrowed more than owed"`
#' is the rare and interesting one: net cash raised as debt that the balance
#' sheet does not show as debt, which is the pattern of a grant booked as a
#' loan. Before a gap is reported, the readings a filer plausibly meant are
#' tried: short-term bank debt counted as borrowing, an untagged financing
#' remainder as an untagged repayment, and all of financing less what went to
#' and from the owners. `adjustment` names the reading that closed it.
#'
#' Where a gap here is matched, within the same room and in the other direction, by an
#' untagged remainder or a contrary line outside financing, `offset_by` names
#' it. A reclassification moves an amount from one activity to another and
#' leaves the total unchanged, so it shows up as two equal and opposite gaps.
#'
#' @section How often it fires:
#' Of 4,304 Danish filings for 2020-2024, 328 tag a cash flow statement. The
#' class B companies that make up most of the corpus may leave it out. Across
#' those 328:
#'
#' * the activities sum to the change in cash in 320 of 336 statements, and
#'   the roll-forward closes in 313 of 325, 35 of them only with the exchange
#'   rate adjustment;
#' * `"borrowed more than owed"` is reported for 10 of the 196 filings with
#'   debt to check. That is a lead and not a finding: a loan drawn and repaid
#'   within the year, or debt classified differently in the two statements,
#'   can look the same from the outside;
#' * a gap matched by an equal and opposite line elsewhere is found once, in
#'   the harmless direction: debt that grew 1.3 million more than was
#'   borrowed, beside an untagged 1.3 million in investing, which looks like
#'   an asset bought on credit. `"borrowed more than owed"` with its other
#'   half named, the signature of a grant booked as a loan, is found in none.
#'   Greenland Airports' 2025 group accounts, read separately, show it to the
#'   krone.
#'
#' Planted in the 61 clean statements that tag their borrowing, a grant booked
#' as a loan is flagged in 34 at 5% of the borrowing, 48 at 10% and 54 at
#' 35%, while the internal checks still pass in 60 of the 61. At 5% the planted
#' gap is the size of the room itself, so many fall inside it: `rel` is the
#' price of not flagging every lease.
#'
#' @section The signs are the filer's, read through the taxonomy:
#' Filers write an outflow either as a negative figure or as a positive one
#' under an outflow element, and both conventions are common. The taxonomy's
#' `balance` attribute says which element is which: debit is an inflow, credit
#' an outflow. Which convention a filing uses is read from its own gross
#' outflows. If most of them are positive, an outflow element is subtracted
#' as it stands. Otherwise every figure is taken as reported.
#'
#' Neither reading uses `abs()`. A filer who tags an increase in capital as a
#' negative `CashCapitalReduction` meant an inflow, and the arithmetic should
#' treat it that way. The sign check is what reports the tag.
#'
#' @param x A tibble from [read_xbrl()], with the taxonomy on it.
#' @param by Columns identifying one statement instance. `NULL`, the default,
#'   uses whichever of `file` and `basis` the table has.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#' @param rel Relative tolerance for `"debt vs balance"`, as a share of the
#'   larger of the two figures. Debt moves for reasons that move no cash, and a
#'   krone's tolerance would flag every company with a lease. Default `0.05`.
#'
#' @return A tibble with one row per check and statement instance: the `by`
#'   columns, the key, `check`, `reported` (the figure the cash flow statement
#'   gives), `expected` (what the rest of the filing says it should be),
#'   `residual` (`reported - expected`), `adjustment`, `offset_by` and
#'   `verdict`. A filing with no cash flow statement has no rows.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' cf <- check_cashflow(x)
#'
#' # the internal arithmetic
#' table(cf$check, cf$verdict)
#'
#' # cash raised as debt that the balance sheet does not show as debt
#' cf[cf$verdict == "borrowed more than owed", ]
#' }
#'
#' @seealso [check_statement()] and [check_cascade()] for the other two
#'   statements, [check_continuity()] for figures stated in two filings.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_cashflow <- function(x, by = NULL, tol = 1, rel = 0.05) {
  by <- .default_by(x, by, want = c("file", "basis"))
  need <- c("statement", "code", "elementid", "value", "balance", "is_line",
            "period", "period_end", "period_start")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(c(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}.",
      "i" = "{.arg x} comes from {.fn read_xbrl}, with the taxonomy on it."))

  # Undimensioned figures only. A fact is repeated once for every statement the
  # taxonomy places its element in, so the cash in the balance sheet and the
  # cash in the cash flow statement are the same row seen twice -- which is why
  # this looks figures up by element, not by statement.
  d <- x[x$is_line %in% TRUE & !is.na(x$value) & !is.na(x$period) &
           !x$abstract %in% TRUE, , drop = FALSE]
  has_cf <- d$statement %in% "CashFlowStatement" &
    d$elementid %in% .CF$sections
  if (!any(has_cf)) return(tibble::as_tibble(data.frame()))

  # The fixed asset note states its additions per asset class, and a class is a
  # dimension, so those facts are not lines and have to be fetched beside them.
  a <- x[x$elementid %in% unlist(.CF_ADDITIONS) & !is.na(x$value) &
           !is.na(x$period) & !x$is_line %in% TRUE, , drop = FALSE]
  a_key <- do.call(paste, c(a[by], sep = "\r"))

  # Split once rather than compare the key on every pass: a corpus is over a
  # million facts, and a thousand filings scanning all of them is minutes.
  key <- do.call(paste, c(d[by], sep = "\r"))
  todo <- unique(key[has_cf])
  idx <- split(seq_len(nrow(d)), key)[todo]
  a_idx <- split(seq_len(nrow(a)), a_key)
  pb <- .file_progress(todo, "  checking cash flows")
  rows <- lapply(todo, function(k) {
    .file_tick(pb)
    ai <- a_idx[[k]]
    .cashflow_one(d[idx[[k]], , drop = FALSE],
                  a[if (is.null(ai)) integer() else ai, , drop = FALSE],
                  by, tol, rel)
  })
  .file_done(pb)
  out <- tibble::as_tibble(data.table::rbindlist(rows, fill = TRUE))
  .key_first(out)
}

# The elements the checks are built from. Named by element, not by code: the
# cash flow statement's codes moved by one group between the 2012 and the 2024
# taxonomy, and every element here kept its name.
.CF <- list(
  sections = c(operating = "CashFlowsFromUsedInOperatingActivities",
               investing = "CashFlowsFromUsedInInvestingActivities",
               financing = "CashFlowsFromUsedInFinancingActivities"),
  before_fx = "IncreaseDecreaseOfCashAndCashEquivalentsBeforeEffectOfExchangeRateChanges",
  change    = "NetIncreaseDecreaseInCashAndCashEquivalents",
  fx        = "ExchangeRateAdjustmentsCashAndCashEquivalents",
  cash      = "CashAndCashEquivalentsConcerningCashflowStatement",

  # Borrowing and repayment. The general element first: a filer reporting it
  # and the specific ones beside it is giving a breakdown, and summing both
  # counts the borrowing twice.
  raised_all  = "ProceedsFromLongtermLiabilitiesClassifiedAsFinancingActivities",
  raised      = c("RaisingOfDebtToCreditInstitutions", "RaisingOfMortgageDebt",
                  "ConclusionOfLeaseObligations", "RaisingOfDebtToGroupEnterprises",
                  "RaisingOfDebtToAssociates",
                  "IncurrenceOfDebtToParticipatingInterests",
                  "RaisingOfLongtermDebt"),
  repaid_all  = "RepaymentsOfLongtermLiabilitiesClassifiedAsFinancingActivities",
  repaid      = c("RepaymentOfDebtToCreditInstitutions", "RepaymentOfMortgageDebt",
                  "ReductionOfLeaseCommitments", "RepaymentOfDebtToGroupEnterprises",
                  "RepaymentOfDebtToAssociates",
                  "RepaymentOfDebtToParticipatingInterests",
                  "RepaymentOfOtherLongtermPayables"),

  # What the balance sheet says the debt was. The short-term part is a
  # long-term loan falling due within the year, and repaying it is still
  # repaying long-term debt.
  debt       = c("LongtermLiabilitiesOtherThanProvisions",
                 "ShorttermPartOfLongtermLiabilitiesOtherThanProvisions"),
  # Short-term borrowing, which a filer may count as debt raised.
  short_debt = c("ShorttermDebtToBanks", "ShorttermMortgageDebt",
                 "ShorttermDebtToOtherCreditInstitutions"),
  # The owners' part of financing, which is not debt.
  equity_in  = c("CashCapitalIncrease", "SaleOfTreasuryShares"),
  equity_out = c("CashCapitalReduction", "PurchaseOfTreasurySharesCashFlow",
                 "DividendsPaidClassifiedAsFinancingActivities",
                 "DividendPaidCashFlow", "CostsRelatedToChangesInContributedCapital"),
  bs_cash    = "CashAndCashEquivalents",
  # What a filing may count as cash, or against it.
  cash_plus  = c(securities = "SharesIncludedAsCashAndCashEquivalents"),
  cash_minus = c(overdraft = "ShorttermDebtToBanksCashFlowsStatement",
                 `bank debt` = "ShorttermDebtToBanks")
)

.cashflow_one <- function(g, adds, by, tol, rel) {
  end   <- g$period_end[1]
  start <- g$period_start[1]
  prev  <- if ("prev_end" %in% names(g)) g$prev_end[1] else as.Date(NA)
  if (is.na(end)) return(NULL)

  # One value per element and date. A filing that states a figure twice with
  # two amounts is check_statement()'s to report; here the first one stands.
  at <- function(id, when) {
    v <- g$value[g$elementid == id & g$period %in% when]
    if (length(v)) v[1] else NA_real_
  }
  now <- function(id) at(id, end)
  # The opening balance is dated the last day of the year before, or the first
  # day of this one -- filers use both, and some use both in one filing.
  opening <- function(id) {
    for (w in list(prev, start - 1, start)) {
      if (is.na(w)) next
      v <- at(id, w)
      if (!is.na(v)) return(v)
    }
    NA_real_
  }

  rows <- list()
  add <- function(check, reported, expected, verdict, adjustment = NA_character_,
                  elementid = NA_character_)
    rows[[length(rows) + 1L]] <<- data.frame(
      check = check, elementid = elementid, reported = reported,
      expected = expected, residual = reported - expected,
      adjustment = adjustment, offset_by = NA_character_, verdict = verdict,
      stringsAsFactors = FALSE)
  agrees <- function(a, b) !is.na(a) && !is.na(b) && abs(a - b) <= tol

  # -- the activities sum to the change in cash
  sec <- vapply(.CF$sections, now, numeric(1))
  before <- now(.CF$before_fx)
  change <- now(.CF$change)
  # Some taxonomies date the exchange rate adjustment at the start of the
  # year, as though it were a balance.
  fx <- at(.CF$fx, end)
  if (is.na(fx) && !is.na(start)) fx <- at(.CF$fx, start)

  # Whether `NetIncreaseDecrease...` includes the exchange rate adjustment is
  # the filer's reading, not the element's. Its name says net, but 35 of the 47
  # roll-forwards in the corpus that fail without the adjustment close to the
  # krone with it -- Danish practice prints "Aendring i likvider" first and
  # the adjustment beneath it. Both readings are tried, here and below, and
  # `adjustment` says which one closed.
  target <- if (!is.na(before)) before else change
  if (!is.na(target) && sum(!is.na(sec)) >= 2) {
    s <- sum(sec, na.rm = TRUE)
    if (agrees(s, target)) {
      add("activities", s, target, "agrees")
    } else if (!is.na(fx) && agrees(s + fx, target)) {
      add("activities", s + fx, target, "agrees, adjusted", "exchange rates")
    } else {
      # The other convention: outflow activities written as positive figures.
      # Every sign pattern of three activities is tried, and only one that
      # closes exactly counts.
      add("activities", s, target,
          if (.signs_close(sec[!is.na(sec)], target, tol)) "agrees, unsigned"
          else "differs")
    }
  }

  # -- last year's cash, plus the change, is this year's
  cash_end <- now(.CF$cash)
  cash_open <- opening(.CF$cash)
  if (!is.na(cash_end) && !is.na(cash_open) && !is.na(change)) {
    roll <- cash_open + change
    if (agrees(roll, cash_end)) {
      add("rollforward", roll, cash_end, "agrees")
    } else if (!is.na(fx) && agrees(roll + fx, cash_end)) {
      add("rollforward", roll + fx, cash_end, "agrees, adjusted",
          "exchange rates")
    } else {
      add("rollforward", roll, cash_end, "differs")
    }
  }

  # -- the closing cash is the balance sheet's
  bs <- now(.CF$bs_cash)
  if (!is.na(cash_end) && !is.na(bs)) {
    if (agrees(cash_end, bs)) {
      add("cash vs balance", cash_end, bs, "agrees")
    } else {
      plus  <- vapply(.CF$cash_plus, now, numeric(1))
      minus <- vapply(.CF$cash_minus, now, numeric(1))
      cand <- c(stats::setNames(plus, names(.CF$cash_plus)),
                stats::setNames(-abs(minus), names(.CF$cash_minus)))
      cand <- cand[!is.na(cand) & cand != 0]
      hit <- .first_closing_subset(cand, cash_end - bs, tol)
      if (is.null(hit)) {
        add("cash vs balance", cash_end, bs, "differs")
      } else {
        add("cash vs balance", cash_end, bs + sum(cand[hit]),
            "agrees, adjusted", paste(names(cand)[hit], collapse = " + "))
      }
    }
  }

  # -- what the tagged lines leave of each activity
  cf <- g[g$statement %in% "CashFlowStatement" & g$period %in% end, , drop = FALSE]
  cf <- cf[!duplicated(cf$elementid), , drop = FALSE]
  sect <- .cf_section_of(cf)
  out_pos <- .outflows_positive(cf, sect)
  untagged <- c(investing = NA_real_, financing = NA_real_)
  for (nm in names(untagged)) {
    tot <- sec[[nm]]
    i <- match(.CF$sections[[nm]], cf$elementid)
    if (is.na(tot) || is.na(i)) next
    kids <- .nearest_children(cf, cf$code[i])
    if (nrow(kids) == 0) next
    part <- sum(.cf_direction(kids$value, kids$balance, out_pos))
    untagged[[nm]] <- tot - part
    add(paste0("untagged: ", nm), tot, part,
        if (agrees(tot, part)) "complete" else "untagged remainder")
  }

  # -- lines whose sign contradicts their element
  contrary <- .contrary_lines(cf, sect, out_pos, tol)
  for (j in seq_len(nrow(contrary)))
    add(paste0("sign: ", contrary$section[j]), contrary$value[j], NA_real_,
        "against its element", elementid = contrary$elementid[j])

  # -- borrowing against the debt the balance sheet shows
  # Signed the way every other line here is, not by abs(). A raising of debt
  # reported negative is a repayment: filers tag the net change in a bank
  # facility as `RaisingOfDebtToCreditInstitutions`, and read as its absolute
  # value it was borrowing -- four of the first fourteen leads this check
  # raised on the corpus were that, and not the filings.
  flow <- function(id, inflow) {
    v <- now(id)
    if (is.na(v)) NA_real_ else if (inflow) v else .cf_direction(v, "credit", out_pos)
  }
  pick <- function(all_of, specific, inflow) {
    v <- flow(all_of, inflow)
    if (!is.na(v)) return(v)
    v <- vapply(specific, flow, numeric(1), inflow = inflow)
    if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE)
  }
  raised <- pick(.CF$raised_all, .CF$raised, TRUE)
  repaid <- pick(.CF$repaid_all, .CF$repaid, FALSE)
  debt_end  <- vapply(.CF$debt, now, numeric(1))
  debt_open <- vapply(.CF$debt, opening, numeric(1))
  if ((!is.na(raised) || !is.na(repaid)) && !is.na(debt_end[1]) &&
      !is.na(debt_open[1])) {
    # A missing short-term part is nil at both ends, not unknown: a filing with
    # no long-term loan falling due has nothing to tag there.
    net <- sum(raised, repaid, na.rm = TRUE)
    moved <- sum(debt_end, na.rm = TRUE) - sum(debt_open, na.rm = TRUE)

    # Everything financing did that was not the owners': what is left of the
    # activity once capital, dividends and treasury shares are taken out. It
    # catches the repayment a filer put on a line of its own making.
    owners <- c(stats::setNames(vapply(.CF$equity_in, flow, numeric(1), inflow = TRUE),
                                .CF$equity_in),
                stats::setNames(vapply(.CF$equity_out, flow, numeric(1), inflow = FALSE),
                                .CF$equity_out))
    # Two elements for the same dividend: the first one reported is it.
    div <- intersect(c("DividendsPaidClassifiedAsFinancingActivities",
                       "DividendPaidCashFlow"), names(owners)[!is.na(owners)])
    if (length(div) > 1) owners[div[-1]] <- NA
    non_owner <- sec[["financing"]] - sum(owners, na.rm = TRUE)

    # The most charitable reading wins. Where the line between long- and
    # short-term debt runs is the filer's to draw, and a loan raised long and
    # drawn on short moves between them; a repayment is as often left untagged
    # as tagged. Each reading below is one a filer plausibly meant, and a gap
    # is reported only where none of them closes it. Over the 196 filings in
    # the corpus with debt to check, the readings, the direction below and the
    # signs above took the flags from 44 rows to 10 filings. Greenland Airports
    # is flagged under every reading.
    st_debt <- vapply(.CF$short_debt, function(id) now(id) - opening(id),
                      numeric(1))
    moved_all <- moved + sum(st_debt, na.rm = TRUE)
    readings <- c(
      narrow     = net - moved,
      with_short = net - moved_all,
      untagged   = if (!is.na(untagged[["financing"]]))
                     net + untagged[["financing"]] - moved else NA_real_,
      all_financing = if (!is.na(non_owner)) non_owner - moved_all else NA_real_)
    readings <- readings[!is.na(readings)]
    gap <- readings[which.min(abs(readings))]
    room <- max(tol, rel * max(abs(net), abs(moved)))
    add("debt vs balance", net, net - gap,
        if (abs(gap) <= room) "agrees"
        # The one that matters: cash raised that the balance sheet does not
        # owe. Only where there was net borrowing to begin with -- a debt that
        # fell by more than was repaid is a reclassification or a conversion,
        # not money from nowhere.
        else if (gap > 0 && net > 0) "borrowed more than owed"
        else if (gap > 0) "fell more than repaid"
        else "owed more than borrowed",
        adjustment = if (abs(gap) <= room && names(gap) != "narrow")
          sub("_", " ", names(gap)) else NA_character_)

    # A reclassification leaves the total alone, so the gap reappears with the
    # opposite sign outside financing: as an untagged remainder, or as a line
    # whose sign contradicts its element.
    if (abs(gap) > room) {
      # paste() of two empty vectors is one string, not none, so the names
      # are built only where there is something to name.
      lead <- if (nrow(contrary)) paste0(contrary$section, ": ",
                                         contrary$elementid) else character()
      other <- c(stats::setNames(untagged, paste("untagged", names(untagged))),
                 stats::setNames(contrary$value, lead))
      other <- other[!is.na(other) & !startsWith(names(other), "untagged financing") &
                       !startsWith(names(other), "financing:")]
      # Within the same room the debt was allowed: the gap is only known to
      # that precision, because the debt it is measured against moves for
      # reasons of its own. Matched to the krone, a grant planted in filings
      # whose debt agreed within 5% was paired with its other half in about
      # half of them; the Greenland filing is exact either way.
      hit <- names(other)[abs(other + gap) <= room]
      if (length(hit)) rows[[length(rows)]]$offset_by <- hit[1]
    }
  }

  # -- the other ties to the rest of the filing
  for (tie in .CF_TIES) {
    v <- tie$cash(now, opening)
    w <- tie$other(now, opening, function(ids) .note_additions(adds, ids, end))
    if (is.na(v) || is.na(w) || (v == 0 && w == 0)) next
    v <- abs(v)
    w <- abs(w)
    room <- max(tol, rel * max(v, w))
    add(tie$check, v, w,
        if (abs(v - w) <= room) "agrees"
        else if (v > w) "cash flow larger" else "cash flow smaller")
  }

  if (length(rows) == 0) return(NULL)
  out <- do.call(rbind, rows)
  keys <- intersect(c(by, .KEYS), names(g))
  cbind(g[rep(1L, nrow(out)), keys, drop = FALSE], out, row.names = NULL)
}

# What the fixed asset note says was added during the year, by kind of asset.
.CF_ADDITIONS <- list(
  tangible   = c(element = "AdditionsToPropertyPlantAndEquipment",
                 dimension = "ClassesOfPropertyPlantAndEquipmentDimension"),
  intangible = c(element = "AdditionsToIntangibleAssets",
                 dimension = "ClassesOfIntangibleAssetsDimension"))

# Additions for the year: the undimensioned total where the note gives one,
# else the sum over its asset classes. A fact broken down by any other
# dimension as well is a part of a class, and summing it would count it twice.
.note_additions <- function(adds, kind, end) {
  spec <- .CF_ADDITIONS[[kind]]
  a <- adds[adds$elementid == spec[["element"]] & adds$period %in% end, ,
            drop = FALSE]
  if (nrow(a) == 0) return(NA_real_)
  dims <- gsub("(^|;)[^;]*ConsolidatedSolo[^;]*", "", a$dimensions)
  dims <- sub("^;", "", dims)
  whole <- is.na(a$dimensions) | !nzchar(dims)
  if (any(whole)) return(a$value[whole][1])
  by_class <- grepl(paste0(":", spec[["dimension"]], "$"), dims)
  if (!any(by_class)) return(NA_real_)
  a <- a[by_class, , drop = FALSE]
  sum(a$value[!duplicated(a$explicit_member)])
}

# The cash flow statement against the rest of the filing, line by line. Each
# is a figure the statement states and a figure something else in the same
# filing implies, and the comparison is of magnitudes: which sign the filer
# gave the cash figure is the sign check's business, not this one's.
#
# None of these is an identity. Each has a known reason to differ, and which
# way a gap runs is what tells a reason from a mistake:
#
# * depreciation -- the cash flow adds back what the income statement charged.
#   Either way is odd; the two are usually the same fact read twice.
# * capex -- additions exceed purchases when an asset arrives without cash,
#   as a lease or through an acquisition. Purchases exceeding additions is the
#   odd direction: cash spent on assets the note never received.
# * capital -- equity can grow without cash, by converting debt. Cash raised
#   as capital that the balance sheet's capital does not show is the odd one.
# * dividends -- what was paid this year is what was proposed at the end of
#   the last, unless an extraordinary dividend was paid in between.
# * inventories -- the change in the cash flow is the change in the balance
#   sheet, less what an acquisition brought in.
.CF_TIES <- local({
  delta <- function(now, opening, id) now(id) - opening(id)
  first <- function(now, ids) {
    for (id in ids) { v <- now(id); if (!is.na(v)) return(v) }
    NA_real_
  }
  list(
    list(check = "depreciation vs income",
         cash  = function(now, opening)
           now("DepreciationAmortisationExpenseAndImpairmentLossesOfPropertyPlantAndEquipmentAndIntangibleAssets"),
         other = function(now, opening, additions)
           now("DepreciationAmortisationExpenseAndImpairmentLossesOfPropertyPlantAndEquipmentAndIntangibleAssetsRecognisedInProfitOrLoss")),
    list(check = "purchases vs note: tangible",
         cash  = function(now, opening)
           now("PurchaseOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities"),
         other = function(now, opening, additions) additions("tangible")),
    list(check = "purchases vs note: intangible",
         cash  = function(now, opening)
           now("PurchaseOfIntangibleAssetsClassifiedAsInvestingActivities"),
         other = function(now, opening, additions) additions("intangible")),
    list(check = "capital vs equity",
         cash  = function(now, opening) now("CashCapitalIncrease"),
         other = function(now, opening, additions) {
           cc <- delta(now, opening, "ContributedCapital")
           sp <- delta(now, opening, "SharePremium")
           if (is.na(cc)) NA_real_ else cc + (if (is.na(sp)) 0 else sp)
         }),
    list(check = "dividends vs proposed",
         cash  = function(now, opening)
           first(now, c("DividendsPaidClassifiedAsFinancingActivities",
                        "DividendPaidCashFlow")),
         other = function(now, opening, additions)
           opening("ProposedDividendRecognisedInEquity")),
    list(check = "inventories vs balance",
         cash  = function(now, opening) now("DecreaseIncreaseInInventories"),
         other = function(now, opening, additions)
           delta(now, opening, "Inventories"))
  )
})

# Which activity each line of the statement sits under, read off the codes the
# filing's own taxonomy gives the three section totals.
.cf_section_of <- function(cf) {
  out <- rep(NA_character_, nrow(cf))
  for (nm in names(.CF$sections)) {
    i <- match(.CF$sections[[nm]], cf$elementid)
    if (is.na(i)) next
    out[startsWith(cf$code, paste0(cf$code[i], "."))] <- nm
  }
  out
}

# Gross flows under investing and financing whose sign says the opposite of
# their element: a sale, a proceeds or a raising of debt that took cash out.
#
# Only the gross flows. A change in working capital, an adjustment or an
# "other" line takes either sign by its nature, so none of those is judged.
# An inflow element reported negative is contrary under either convention. An
# outflow element reported negative is ambiguous -- the filer may be writing
# outflows as negative throughout -- so it is judged only where most of the
# filing's other outflows are positive, and the convention is therefore known.
.contrary_lines <- function(cf, cf_section, out_pos, tol) {
  none <- data.frame(section = character(), elementid = character(),
                     value = numeric(), stringsAsFactors = FALSE)
  keep <- .gross_flow(cf, cf_section) & abs(cf$value) > tol
  if (!any(keep)) return(none)
  v <- cf$value[keep]
  bal <- cf$balance[keep]
  bad <- (bal %in% "debit" & v < 0) | (out_pos & bal %in% "credit" & v < 0)
  if (!any(bad)) return(none)
  data.frame(section = cf_section[keep][bad], elementid = cf$elementid[keep][bad],
             value = v[bad], stringsAsFactors = FALSE)
}

.gross_flow <- function(cf, cf_section)
  cf_section %in% c("investing", "financing") &
    !grepl("^Other|Adjustment|AssetsMeantForSale|^Details|Component",
           cf$elementid) &
    !cf$elementid %in% .CF$sections

# Does this filing write its outflows as positive figures? Yes when more of
# its gross outflows are positive than not. With none to go by, the figures
# are read as signed and taken as reported.
.outflows_positive <- function(cf, cf_section) {
  outs <- cf$value[.gross_flow(cf, cf_section) & cf$balance %in% "credit" &
                     cf$value != 0]
  length(outs) >= 1 && mean(outs > 0) > 0.5
}

# What a line contributes to its activity. Where the filing writes outflows
# as positive figures, an outflow element is subtracted as it stands -- so an
# outflow element reported negative adds, which is what the filer meant by
# it. Where the filing signs its figures, every one is taken as reported.
.cf_direction <- function(value, balance, out_pos)
  if (out_pos) ifelse(balance %in% "credit", -value, value) else value

# Is there a sign pattern of `v` that sums to `target`? Three activities have
# eight, so all of them are tried.
.signs_close <- function(v, target, tol) {
  n <- length(v)
  if (n == 0 || n > 10) return(FALSE)
  s <- as.matrix(expand.grid(rep(list(c(1, -1)), n)))
  any(abs(s %*% v - target) <= tol)
}

# The smallest set of adjustments that closes a gap, as indices into `cand`, or
# NULL. Smallest first: one named reason is a better account than three.
.first_closing_subset <- function(cand, gap, tol) {
  n <- length(cand)
  if (n == 0) return(NULL)
  for (k in seq_len(n)) {
    for (idx in utils::combn(n, k, simplify = FALSE)) {
      if (abs(sum(cand[idx]) - gap) <= tol) return(idx)
    }
  }
  NULL
}
