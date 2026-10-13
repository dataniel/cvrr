#' Reconcile an income statement step by step
#'
#' An income statement is not a sum but a cascade: trading gives a gross
#' figure, operating costs take it to the result of ordinary activities,
#' financial items to the result before tax, and tax to the result for the
#' year. This reconciles each step against its own subtotal.
#'
#' @section Judging a statement by its own precision:
#' `tol = "decimals"` reads the tolerance off the filing. XBRL states the
#' precision of every fact: `decimals="-3"` means accurate to thousands, so such
#' a figure carries up to 500 kroner of rounding, and a step of several adds
#' theirs together.
#'
#' The failures are concentrated where you would expect: of the 63 filings
#' whose cascade leaves a step unsolved or unexplained at a one-krone
#' tolerance, half report at `-3` or coarser, against 6% of the 3,857 that
#' settle every step.
#'
#' It still buys very little, and that is worth saying. Over 4,304 filings a
#' tolerance read off each one recovers 16 of the 57 unsolved steps -- out of
#' close to 11,000 that already solved -- and turns one solved step ambiguous.
#' The default stays at one krone. This is here because it is the right
#' question to ask of a filing, not because asking it paid.
#'
#' @section Why step by step:
#' Reconciling the whole statement at once fails in both directions. It fails
#' to solve, because twenty items against a bottom line rarely have one
#' answer; and worse, it sometimes *appears* to solve by mixing leaf items,
#' their parents and the running subtotals into a combination that happens to
#' reach the total. Four or five items against one subtotal is decidable, and
#' when a step does not reconcile you know which one.
#'
#' @section The reporting boundary is not a gap:
#' Accounting class B may present a gross figure instead of turnover and its
#' components, and nearly all do -- 4,172 of 4,304 filings enter at
#' `Bruttofortjeneste/Bruttotab` or `Bruttoresultat`, and three at turnover.
#' The taxonomy says so itself: the trading group has two exits, `Bruttoresultat`
#' and `Bruttofortjeneste/Bruttotab`. What varies is therefore which income
#' concept a filing *enters* on, not whether it is complete.
#'
#' A filing entering at a gross figure has nothing to reconcile in the first
#' step -- the concept is given, not derived -- and its figure is carried into
#' the second. Reconciling the remaining steps is a complete result for that
#' filing, and `entry` records where it started.
#'
#' @section How the steps are found:
#' From the presentation hierarchy, not from a list of element names. The
#' groups are the statement's abstract top-level nodes; within each, the
#' itemised lines are the ones that are themselves broken down, and the
#' subtotal is what follows them. The final step is the statement's flat tail,
#' ending at the last line the filing reports -- which is the result for the
#' year, or the result after minority interests where a filing gives one.
#'
#' @param x A tibble from [add_taxonomy()], filtered to one income statement, or a
#'   panel of them.
#' @param taxonomy The `cvrr_taxonomy` the filings declare, or a list of them
#'   when they span versions -- as a single accounting year routinely does.
#'   Needed because the
#'   steps come from the *taxonomy's* hierarchy, not from what happens to be
#'   reported: a filing that omits its result of ordinary activities would
#'   otherwise have the line above it mistaken for a subtotal.
#' @param statement Which statement the cascade belongs to. `"income"`, the
#'   default, is the one that is a cascade; pass a taxonomy statement name for
#'   another, or `NULL` to walk every statement in `x`.
#' @param by Columns identifying one statement instance. `NULL`, the default,
#'   uses whichever of `file`, `basis` and `period` the table has -- `file`
#'   because read_xbrl() returns many filings at once, and without it two
#'   companies with the same balance sheet date are checked as one; add the company identifier for a panel.
#' @param retry Give a statement the first pass could not settle a second
#'   reading, in which a line a step did not need is offered to the step below
#'   instead of being consumed. Only applied where the strict pass failed, so a
#'   statement that already reconciled is untouched. Default `TRUE`.
#' @param max_zeros Passed to [find_signs()]: how many items a step may leave
#'   out. Default `1L`, since a step holds few items.
#' @param period `"closing"`, the default, checks the year the filing declares
#'   for itself and leaves its comparative out -- a comparative is usually
#'   partial, and its gaps are not the filing's. `NULL` checks every period the
#'   table carries.
#' @param tol Absolute tolerance in the reporting currency, or `"decimals"` to
#'   take it from what the filing claims about its own precision. Default `1`.
#'   See the section below.
#'
#' @return A tibble with one row per step and statement instance: the `by`
#'   columns, `step`, `target` (the subtotal it reconciles to), `n_items`,
#'   `status` from [find_signs()], and `entry`, the income concept the filing
#'   started from. A step a filing does not have is `"not reported"`; a step
#'   whose subtotal is given without components is `"given"`, `"unchanged"`
#'   where the subtotal carried in equals this one so nothing happened between
#'   them, and `"unexplained"` where they differ with no line tagged to say
#'   why.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' check_cascade(x)
#'
#' # one presentation only, named as the taxonomy names it
#' check_cascade(x, statement = "IncomeStatementByFunction")
#' }
#'
#' @seealso [find_signs()], which does the reconciling, and [check_statement()]
#'   for the balance sheet, whose lines are a plain sum.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_cascade <- function(x, taxonomy = NULL, statement = "income", by = NULL,
                          period = "closing", max_zeros = 1L, tol = 1,
                          retry = TRUE) {
  by <- .default_by(x, by)
  need <- c("statement", "code", "depth", "elementid", "value", "is_line", "abstract")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  # Facts belonging to no statement have no cascade to walk. add_taxonomy()
  # keeps them for xbrl_company(); a check over statements drops them.
  d <- x[x$is_line %in% TRUE & !is.na(x$value) & !is.na(x$statement) &
           !is.na(x$code) & x$periodtype %in% "duration", , drop = FALSE]
  d <- .closing_only(d, period)

  # A cascade is what an income statement is. Run over every statement the
  # taxonomy defines, the walk finds an "entry" in places that have none --
  # the number of employees, the submitting agent's CVR number -- and returns
  # 869 rows for one filing where the income statement has four.
  if (!is.null(statement))
    d <- d[d$statement %in% .statement_names(statement), , drop = FALSE]

  if (missing(taxonomy)) taxonomy <- NULL
  if (inherits(taxonomy, "cvrr_taxonomy")) taxonomy <- list(taxonomy)
  if (!is.null(taxonomy) &&
      (!length(taxonomy) || !all(vapply(taxonomy, inherits, logical(1), "cvrr_taxonomy"))))
    cli::cli_abort(c(
      "{.arg taxonomy} must be the {.cls cvrr_taxonomy} these filings declare, or a list of them.",
      "i" = "The steps come from its hierarchy; the reported lines alone do not show where a subtotal sits."
    ))

  # After the arguments are checked, not before: a filter that empties the
  # table must not let a bad argument through unremarked.
  if (nrow(d) == 0) return(tibble::as_tibble(data.frame()))

  # Steps are derived per declared taxonomy, not once: a single accounting year
  # of filings routinely spans several versions, and each states its own
  # hierarchy.
  key  <- do.call(paste, c(d[c(by, "statement")], sep = "|"))
  keys <- unique(key)
  refs <- d$schemaref[match(keys, key)]
  cache <- new.env(parent = emptyenv())

  rows <- lapply(seq_along(keys), function(i) {
    ref <- refs[i]
    if (is.na(ref)) return(NULL)
    if (is.null(cache[[ref]])) {
      st <- .structure_for(ref, taxonomy)
      if (is.null(st)) return(NULL)
      # Only the statements actually in x: an entry point carries the balance
      # sheet and the notes too, and their codes would become steps of their
      # own.
      st <- st[st$statement %in% unique(d$statement), c("code", "elementid")]
      cache[[ref]] <- .cascade_steps(st)
    }
    if (length(cache[[ref]]) == 0) return(NULL)
    g <- d[key == keys[i], , drop = FALSE]
    out <- .cascade_one(g, cache[[ref]], by, max_zeros, tol, FALSE)
    if (!retry) return(out)

    # A second look, for the statements the first one could not settle. The
    # relaxed reading is only ever applied where the strict one failed, so a
    # statement that already reconciled keeps its strict result -- which is
    # what makes this safe. `unexplained` counts as a failure here: a subtotal
    # that does not arrive at the next one is usually a line consumed with a
    # zero coefficient a step too early, which is exactly what the retry hands
    # back. It is worth having: 4,221 filings settle every step without it and
    # 4,239 with it. Run on everything instead of only where it is needed it
    # reaches the same 4,239 and pays for a second pass on every statement.
    unsettled <- function(z)
      sum(z$status %in% c("unsolved", "ambiguous", "unexplained"))
    if (unsettled(out) == 0) return(out)
    again <- .cascade_one(g, cache[[ref]], by, max_zeros, tol, TRUE)
    if (unsettled(again) >= unsettled(out)) return(out)
    again$pass <- "retried"
    again
  })
  tibble::as_tibble(data.table::rbindlist(rows, fill = TRUE))
}

# How far apart two figures may be and still be the same figure, given what the
# filer claims about them. XBRL states precision per fact: `decimals="-3"` means
# accurate to thousands, so such a figure carries up to 500 kroner of rounding.
# A step is the sum of its facts, so its tolerances add.
#
# Judging a statement reported in thousands to the nearest krone is stricter
# than the statement claims to be, and it shows: of the 63 filings whose
# cascade did not settle, half report at -3 or coarser, against 6% of the rest.
.decimals_tolerance <- function(dec, floor = 1) {
  n <- suppressWarnings(as.numeric(dec))
  n[dec %in% "INF"] <- Inf
  n[is.na(n)] <- 0                     # unstated: assume the unit itself
  half <- ifelse(is.infinite(n), 0, 0.5 * 10^(-n))
  max(sum(half), floor)
}

# The cascade, read off the presentation hierarchy.
#
# A group is an abstract node at the top of the statement. Inside it the
# itemised lines are the ones that are themselves broken down; the subtotal is
# whatever follows the last of them. That isolates the trading group's two
# exits -- a gross result or a gross profit -- without naming either.
.cascade_steps <- function(st) {
  st <- st[!duplicated(st$code), ]
  st <- st[order(st$code), ]
  seg <- lengths(strsplit(st$code, ".", fixed = TRUE))
  if (all(seg <= 3)) return(list())

  group_of <- function(cd) paste(strsplit(cd, ".", fixed = TRUE)[[1]][1:3],
                                 collapse = ".")
  groups <- sort(unique(vapply(st$code[seg >= 4], group_of, character(1))))

  steps <- lapply(groups, function(g) {
    inside <- st[startsWith(st$code, paste0(g, ".")), ]
    inside_seg <- lengths(strsplit(inside$code, ".", fixed = TRUE))
    kids <- inside[inside_seg == 4, ]
    if (nrow(kids) == 0) return(NULL)

    # A line that is itself broken down is an item; the subtotal follows them.
    itemised <- vapply(kids$code, function(cd)
      any(startsWith(inside$code, paste0(cd, "."))), logical(1))
    last_itemised <- if (any(itemised)) max(which(itemised)) else 0L
    if (last_itemised == nrow(kids)) return(NULL)

    subtotals <- kids$elementid[seq.int(last_itemised + 1L, nrow(kids))]
    # `flat` where no child was itemised, so every one of them is a candidate
    # subtotal and the group offers no clue which. A by-function statement
    # looks like this: revenue, cost of production, gross result, gross profit,
    # none broken down further. The exit is the last of them a filing reports,
    # not the first -- take the first and the revenue becomes its own subtotal
    # and the whole cascade reads the statement upside down.
    list(name = g, targets = subtotals, flat = last_itemised == 0L,
         inputs = setdiff(inside$elementid, subtotals))
  })
  steps <- steps[!vapply(steps, is.null, logical(1))]

  # The tail: lines at the statement's own level, ending where the filing does.
  tail <- st$elementid[seg == 3]
  if (length(tail) > 1)
    steps <- c(steps, list(list(name = "tail", inputs = tail, targets = tail)))
  steps
}

.cascade_one <- function(d, steps, by, max_zeros, tol, defer_spare = FALSE) {
  carried <- numeric(0)
  entry <- NA_character_
  # Lines belonging to a subtotal the filer never reported, waiting for one
  # that is.
  pending <- character()
  # The first step with a reported target: the filing's entry concept.
  first_step <- TRUE

  rows <- lapply(steps, function(st) {
    reported_targets <- intersect(st$targets, d$elementid)
    if (length(reported_targets) == 0) {
      # The filer did not report this step's subtotal. Its lines are still
      # theirs to explain, so they wait for the next subtotal that is reported
      # rather than being dropped -- which is what "go from the gross profit to
      # the result for the year" means when a signpost along the way is
      # missing.
      pending <<- c(pending, setdiff(st$inputs, names(carried)))
      return(data.frame(step = st$name, target = NA_character_, n_items = 0L,
                        status = "not reported", stringsAsFactors = FALSE))
    }

    # For the tail the target is where the filing stops, not the first match.
    target <- if (identical(st$name, "tail") || isTRUE(st$flat))
      reported_targets[length(reported_targets)] else reported_targets[1]
    total <- d$value[d$elementid == target][1]

    # A group can offer several exits, and a filer may report more than one of
    # them: the tax as `TaxExpenseOnOrdinaryActivities` inside the group as
    # well as, or instead of, `TaxExpense` at the statement's own level. Only
    # one can be this step's subtotal. The others are lines like any other, and
    # belong to the steps below -- without this the tax is claimed by a step
    # that does not use it and never reaches the one that needs it.
    spare_targets <- setdiff(intersect(st$targets, d$elementid), target)
    handed_down <- pending
    want <- setdiff(c(st$inputs, pending), c(target, names(carried)))
    pending <<- spare_targets


    inputs <- d[d$elementid %in% want, , drop = FALSE]
    inputs <- .topmost_codes(inputs[!duplicated(inputs$elementid), , drop = FALSE])

    # A figure handed down from an earlier group must not arrive beside the
    # same amount under another name. A filing tagging its tax both as
    # `TaxExpenseOnOrdinaryActivities` inside the group and as `TaxExpense` at
    # the statement's own level has one tax; give the step both and it is free
    # to discard either, which is two readings differing only in which
    # duplicate they drop -- an ambiguity of the check's own making.
    if (length(handed_down) > 0 && nrow(inputs) > 1) {
      from_above <- inputs$elementid %in% handed_down
      dup <- from_above & vapply(seq_len(nrow(inputs)), function(k)
        any(abs(inputs$value[-k] - inputs$value[k]) < 1), logical(1))
      inputs <- inputs[!dup, , drop = FALSE]
    }

    if (is.na(entry)) entry <<- target

    items <- data.frame(
      label = c(names(carried), inputs$elementid, "__target__"),
      value = c(unname(carried), inputs$value, total), stringsAsFactors = FALSE)
    items <- items[!duplicated(items$label) & !is.na(items$value), ]
    # A line reported as nil says nothing about its own sign -- plus nought and
    # minus nought reach the same total -- so leaving it in only multiplies the
    # readings. The target and whatever was carried in stay whatever they are.
    fixed <- items$label %in% c("__target__", names(carried))
    items <- items[fixed | items$value != 0, , drop = FALSE]

    step_tol <- if (identical(tol, "decimals"))
      .decimals_tolerance(d$decimals[match(items$label, d$elementid)]) else tol

    # No lines left once the nils are out. That is not the end of the matter:
    # the subtotal carried in still has to arrive at this one. Where they agree,
    # nothing happened between them and the identity holds -- a verification,
    # not an absence of one. Where they differ, a figure is missing and no line
    # was tagged to name it, which is a gap and was previously recorded as
    # having nothing to check.
    if (nrow(items) <= 1L + length(carried)) {
      status <- if (length(carried) == 0) "given"
                else if (abs(unname(carried[1]) - total) <= step_tol) "unchanged"
                else "unexplained"
      carried <<- stats::setNames(total, target)
      return(data.frame(step = st$name, target = target, n_items = 0L,
                        status = status, stringsAsFactors = FALSE))
    }

    # Strings rather than bare symbols: find_signs() takes either, and the
    # symbols would read as undefined globals from inside a function.
    # The entry concept is where the filing starts, and a filing that starts at
    # the gross profit has not itemised what is inside it. The taxonomy places
    # the trading group's other lines at codes *before* both of its exits, so
    # they arrive here looking like inputs -- but a company reporting
    # "Bruttofortjeneste" first and "Administrationsomkostninger" beneath it
    # has put them below, and the printed statement is what it means.
    #
    # Only tried where the step actually fails, and the lines still have to add
    # up at the step below, so this cannot make a statement reconcile that does
    # not.
    if (first_step && nrow(items) > 1L + length(carried)) {
      trial <- suppressMessages(find_signs(items, "label", "value",
                                           total_label = "__target__",
                                           positive = names(carried),
                                           max_zeros = max_zeros, tol = step_tol))
      if (!identical(trial$status[1], "unique")) {
        pending <<- c(pending, inputs$elementid)
        carried <<- stats::setNames(total, target)
        first_step <<- FALSE
        return(data.frame(step = st$name, target = target, n_items = 0L,
                          status = "given", stringsAsFactors = FALSE))
      }
    }
    first_step <<- FALSE

    res <- suppressMessages(find_signs(items, "label", "value",
                                       total_label = "__target__",
                                       positive = names(carried),
                                       max_zeros = max_zeros, tol = step_tol))

    # Where the free search finds several readings, the taxonomy has already
    # said which one it means. `xbrli:balance` is credit on income and debit on
    # expense, so it fixes the sign of every line -- what find_signs() searches
    # for is declared. Used only to break a tie: it can turn `ambiguous` into
    # `unique`, never overrule a single answer, and never rescue a step that
    # reached no answer at all.
    if (identical(res$status[1], "ambiguous") && "balance" %in% names(d)) {
      i <- match(inputs$elementid, d$elementid)
      bal <- d$balance[i]
      # `balance` gives the direction of the contribution, not the sign of the
      # figure. Credit adds and debit subtracts -- but a filer who has already
      # written the tax as a negative means it to be added as it stands, and
      # pinning it negative would turn the expense into income. So the sign
      # wanted depends on the sign reported.
      # `max_zeros` stays as it is. Forbidding a line to fall out here sounds
      # right -- where the convention is declared there is nothing to choose --
      # and costs ten filings: some steps genuinely need an item dropped, and
      # a pinned search that cannot drop one returns no answer at all.
      #
      # Two readings of the convention, because filers differ. Most write their
      # costs as positive figures, so debit means subtract. Some write the tax
      # as a negative already, and then it is added as it stands. Both are
      # tried and a single answer from either is taken; where they disagree
      # each is still one answer, and the first that settles the step wins.
      try_pin <- function(adds) {
        p <- suppressMessages(find_signs(
          items, "label", "value", total_label = "__target__",
          positive = c(names(carried), inputs$elementid[!is.na(bal) & adds]),
          negative = inputs$elementid[!is.na(bal) & !adds],
          max_zeros = max_zeros, tol = step_tol))
        if (identical(p$status[1], "unique")) p else NULL
      }
      pinned <- try_pin(bal %in% "credit")
      if (is.null(pinned))
        pinned <- try_pin((bal %in% "credit") == (inputs$value >= 0))
      if (!is.null(pinned)) res <- pinned
    }
    # On the retry, a line the search gave a coefficient of zero is one this
    # step did not need, and it goes back to `pending` for the step below
    # rather than being consumed here. That is how the other operating income
    # -- tagged inside the trading group, printed beneath the operating result
    # -- reaches the step that needs it.
    if (defer_spare && identical(res$status[1], "unique")) {
      spare <- res$label[!is.na(res$sign) & res$sign == 0L]
      pending <<- c(pending, intersect(spare, inputs$elementid))
    }
    carried <<- stats::setNames(total, target)
    data.frame(step = st$name, target = target, n_items = nrow(items) - 1L,
               status = res$status[1], stringsAsFactors = FALSE)
  })

  out <- do.call(rbind, rows)
  cbind(d[1, by, drop = FALSE], out, entry = entry, row.names = NULL)
}

# Within a set of reported lines, the ones with no reported line above them:
# a filer may give staff costs whole or split into wages and pensions, and
# counting both double-counts.
.topmost_codes <- function(d) {
  if (nrow(d) == 0) return(d)
  d[!vapply(d$code, function(cd)
    any(startsWith(cd, paste0(d$code, "."))), logical(1)), , drop = FALSE]
}
