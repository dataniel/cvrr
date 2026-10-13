#' Reconcile an opening balance and its movements to the closing balance
#'
#' Equity, fixed assets, provisions: an annual report is full of schedules that
#' start from last year's figure, add and subtract during the year, and end at
#' this year's. This checks that each one arrives where it says it does.
#'
#' @section Why nothing else catches this:
#' Every other check in the package compares like with like.
#' [check_statement()] compares instants to instants, [check_cascade()] compares
#' durations to durations, and neither touches the identity that binds them:
#'
#' ```
#' opening (instant) + movements (duration) = closing (instant)
#' ```
#'
#' That identity is where a schedule can be wrong while every other figure in
#' the filing is right -- and it is the only place a company states its
#' investment for the year, which is the figure national accounts want.
#'
#' @section The signs are the filer's:
#' A schedule arrives without a usable sign convention. `DisposalsOf...` is
#' reported positive and must be subtracted; the reversal of depreciation on
#' those same disposals is reported negative and must be added, in the same
#' note. So the movements are handed to [find_signs()] with the closing balance
#' as the total and the opening balance pinned positive -- the identity decides
#' the signs, and a schedule that admits no unique assignment is reported as
#' such rather than guessed at.
#'
#' @section Shape is not intent:
#' Nothing in the Danish taxonomy marks a presentation group as a
#' roll-forward, so this recognises one by its shape: a single balance
#' reported at both ends of the period, with movements over that period beside
#' it. Two kinds of group have that shape without the meaning.
#'
#' A five-year summary (`KeyFiguresAndFinancialRatios`) sets assets, equity,
#' capital and provisions side by side at two dates each; nothing says which
#' of them the profit in the same group is supposed to explain. Groups holding
#' more than one balance are therefore skipped outright.
#'
#' A disclosure note (`DisclosureOfRelatedParties`) quotes equity and profit as
#' context, and that pair *is* the shape of a schedule -- but the note omits
#' every other movement, so the identity cannot close and reports a failure
#' that says nothing about the filing. Shape alone cannot tell it from a real
#' equity statement. Pass `statement` to scope the check where a schedule is
#' actually meant: `StatementOfChangesInEquity` and the asset notes.
#'
#' @section A balance that is simply blank:
#' By default a schedule is checked only where the balance is reported at both
#' dates. That is the strict reading, and it is often too strict: an asset
#' class that started or ended at nothing is routinely left blank rather than
#' tagged as nil.
#'
#' `assume_nil = TRUE` reads one absent balance as zero -- one, never both,
#' since a schedule missing both ends is not a schedule. The result says so in
#' `balances`, because an assumed nil must not travel as a reported one.
#'
#' What it will not do is infer the *opening* balance from the identity itself.
#' That would make the check confirm its own assumption, and every schedule
#' would reconcile.
#'
#' A group holding two elements that each appear at both dates is not one
#' schedule and is skipped whatever this is set to.
#'
#' @param x A tibble from [add_taxonomy()].
#' @param period The filing's declared accounting period, from
#'   [xbrl_period()]. Optional, and worth passing: it settles which year the
#'   schedule covers and which instant is its opening balance, where without
#'   it both are inferred from the movements' own dates.
#' @param assume_nil Read a single absent balance as zero. See the section
#'   below; the result marks every schedule this applies to.
#' @param statement Restrict to these statements. `NULL` (default) checks
#'   every presentation group that has the shape of a schedule -- see the
#'   section below on what that includes.
#' @param by Columns identifying one schedule beyond its own group and
#'   dimension. Defaults to `"basis"`; add the company identifier for a panel.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#'
#' @return A tibble with one row per schedule: the `by` columns, `group` (the
#'   presentation code the schedule sits under), `dimension` and `member` where
#'   the schedule is broken down, `opening`, `closing`, `n_movements`,
#'   `n_zero` (movements reported as nil, which are excluded from the search
#'   because they say nothing about their own sign), `movements` (whether they
#'   were tagged at this level or summed over the classes below it), `balances`
#'   (whether both were reported or one was assumed nil), and `status` from
#'   [find_signs()].
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' m <- check_movement(x)
#'
#' # the schedules that do not arrive where they say
#' m[m$status != "unique", ]
#' }
#'
#' @seealso [find_signs()], which resolves the signs, and [check_breakdown()],
#'   which checks the same schedules across a dimension rather than through
#'   time.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_movement <- function(x, statement = NULL, period = NULL,
                           assume_nil = FALSE, by = NULL, tol = 1) {
  # Not `period`: a schedule spans the period, so grouping by it would split a
  # schedule's opening balance from the movements that explain it.
  by <- .default_by(x, by, want = c("file", "basis"))
  need <- c("code", "elementid", "periodtype", "period", "value",
            "startdate", "enddate")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  d <- x[!is.na(x$value) & !is.na(x$periodtype), , drop = FALSE]
  if (!is.null(statement)) d <- d[d$statement %in% statement, , drop = FALSE]
  if (nrow(d) == 0) return(tibble::as_tibble(data.frame()))

  # A schedule is one presentation group, one dimension member, one basis. The
  # member matters: a note runs a separate schedule per asset class, and they
  # share their element names.
  dims <- grep("^dim_", names(d), value = TRUE)
  dims <- setdiff(dims, "dim_ConsolidatedSolo")
  d$..member <- if (length(dims) == 0) NA_character_ else
    apply(d[dims], 1, function(r) {
      k <- which(!is.na(r))
      if (length(k) == 0) NA_character_ else paste0(names(r)[k[1]], "=", r[k[1]])
    })
  d$..group <- sub("[.][0-9]{3}$", "", d$code)

  key <- do.call(paste, c(d[c(by, "..group")], sep = "\r"))
  rows <- unlist(lapply(unique(key), function(k)
    .movement_group(d[key == k, , drop = FALSE], by, tol, period, assume_nil)),
    recursive = FALSE)
  tibble::as_tibble(data.table::rbindlist(
    rows[!vapply(rows, is.null, logical(1))], fill = TRUE))
}

# One presentation group: a schedule per dimension member, plus the total.
.movement_group <- function(g, by, tol, period = NULL, assume_nil = FALSE) {
  members <- unique(g$..member)
  lapply(members, function(m) {
    rows <- if (is.na(m)) is.na(g$..member) else !is.na(g$..member) & g$..member == m
    .movement_one(g[rows, , drop = FALSE], by, tol, period = period,
                  assume_nil = assume_nil,
                  # The total's own movements are often left untagged while
                  # the classes carry them. Where that happens the members are
                  # what the total column of the note says, so they are summed
                  # -- and the identity then tests that sum as well.
                  parts = if (is.na(m)) g[!is.na(g$..member), , drop = FALSE])
  })
}

.movement_one <- function(g, by, tol, parts = NULL, period = NULL,
                          assume_nil = FALSE) {
  flow <- g[g$periodtype == "duration" & !is.na(g$enddate), , drop = FALSE]
  bal  <- g[g$periodtype == "instant", , drop = FALSE]
  # One balance, or this is not a schedule. A five-year summary carries
  # assets, equity, capital and provisions side by side at two dates each,
  # which has the shape of a roll-forward and none of its meaning: there is no
  # saying which of the figures the flows in the group are meant to explain.
  if (length(unique(bal$elementid)) != 1) return(NULL)

  # The period comes from the movements, never from the balances. A filing
  # carries the comparative year as well, so the instants alone offer four
  # dates; taking the earliest and the latest would span two years while the
  # flows cover one, and the identity could not hold whatever the filer did.
  ends <- sort(unique(c(flow$enddate, parts$enddate)), decreasing = TRUE)
  # A declared period beats an inferred one, and every filing declares its own.
  if (!is.null(period) && !is.na(period$end))
    ends <- c(as.character(period$end), setdiff(ends, as.character(period$end)))
  for (e in ends) {
    f <- flow[flow$enddate %in% e, , drop = FALSE]
    src <- rep("tagged", nrow(f))

    if (!is.null(parts) && nrow(parts) > 0) {
      p <- parts[parts$periodtype == "duration" & parts$enddate %in% e &
                   !parts$elementid %in% f$elementid, , drop = FALSE]
      if (nrow(p) > 0) {
        agg <- stats::aggregate(list(value = p$value),
                                by = list(elementid = p$elementid,
                                          startdate = p$startdate), FUN = sum)
        f <- rbind(f[c("elementid", "startdate", "value")],
                   agg[c("elementid", "startdate", "value")])
        src <- c(src, rep("summed over classes", nrow(agg)))
      }
    }
    if (nrow(f) == 0) next

    # Some filers date the opening balance to the first day of the year, others
    # to the last day of the one before. Both mean the same instant. A movement
    # tagged without a start date leaves neither available, and the declared
    # period is then the only thing that says where the year began.
    s <- f$startdate[1]
    opens <- if (is.na(s)) character() else c(s, .day_before(s))
    if (!is.null(period) && identical(as.character(period$end), e))
      opens <- c(opens, as.character(period$start), as.character(period$prev_end))
    opens <- unique(opens[!is.na(opens)])
    if (length(opens) == 0) next
    # Unique: a filer may tag the opening instant under both dates, and two
    # tags of one figure is still one figure.
    opening <- unique(bal$value[bal$period %in% opens])
    closing <- unique(bal$value[bal$period %in% e])

    # A schedule that started or ended at nothing is often simply left blank,
    # so an absent balance is read as nil where `assume_nil` allows it -- but
    # only one of the two, because a schedule missing both ends is not a
    # schedule. `balances` says which figures were observed, so an assumed nil
    # never travels as a reported one.
    assumed <- character()
    if (assume_nil && length(opening) == 0 && length(closing) == 1) {
      opening <- 0; assumed <- "opening"
    } else if (assume_nil && length(closing) == 0 && length(opening) == 1) {
      closing <- 0; assumed <- "closing"
    }
    if (length(opening) != 1 || length(closing) != 1) next

    keep <- !duplicated(f$elementid)
    f <- f[keep, , drop = FALSE]
    src <- src[keep]

    # A movement of zero says nothing about its own sign, and leaving it in
    # would make every schedule that has one report as ambiguous. It is dropped
    # from the search and counted instead.
    nz <- f$value != 0
    f <- f[nz, , drop = FALSE]
    src <- src[nz]
    if (nrow(f) == 0) next

    items <- data.frame(
      label = c("..opening", f$elementid, "..closing"),
      value = c(opening, f$value, closing), stringsAsFactors = FALSE)

    # No item may be discarded. Elsewhere in the package dropping a line is a
    # reasonable allowance, because a filer can report a figure that belongs to
    # a grouping the subtotal does not cover. A schedule is not like that: the
    # filer put each movement there to explain the change, so a solution that
    # ignores one is not a reading of the schedule but a coincidence.
    res <- suppressMessages(find_signs(items, "label", "value",
                                       total_label = "..closing",
                                       positive = "..opening",
                                       max_zeros = 0L, tol = tol))
    return(cbind(
      g[1, by, drop = FALSE],
      data.frame(group = g$..group[1], balance = bal$elementid[1],
                 member = g$..member[1], period = e,
                 opening = opening, closing = closing, n_movements = nrow(f),
                 n_zero = sum(!nz),
                 movements = if (all(src == "tagged")) "tagged" else
                   "summed over classes",
                 balances = if (length(assumed) == 0) "reported" else
                   paste(assumed, "assumed nil"),
                 status = res$status[1], stringsAsFactors = FALSE),
      row.names = NULL))
  }
  NULL
}

.day_before <- function(d) {
  x <- suppressWarnings(as.Date(d))
  if (is.na(x)) NA_character_ else as.character(x - 1)
}
