#' Choose between two figures reported for the same line
#'
#' A filing sometimes states one statement line twice with different amounts.
#' [check_statement()] refuses to pick and reports `"conflicting duplicates"`,
#' which leaves the statement unjudgeable. But the statement has to add up, and
#' that is usually enough to decide: try each candidate, keep the reading that
#' reconciles.
#'
#' @section Most conflicts are rounding:
#' Before any search, duplicates that differ only by rounding are collapsed.
#' XBRL states the precision of every fact in its `decimals` attribute, so a
#' filing that tags total assets as `1729466749` at `decimals="0"` and as
#' `1729467000` at `decimals="-3"` has written one figure twice, not two
#' figures. The exact one is kept.
#'
#' @section One balance sheet, one context:
#' Then the context. A balance sheet column is a single XBRL context -- assets,
#' equity and the liabilities all carry the same `contextRef`, because that is
#' what a context is for. One filing in the corpus states its whole balance
#' sheet twice: once in a context holding the figures, once in a context
#' holding nothing but nils.
#'
#' Neither a majority nor the arithmetic separates those two. The counts are
#' equal, and an empty column adds up perfectly -- nought is nought plus
#' nought. What separates them is that a column of nils is not a statement, so
#' the rule is kept to exactly that: a context whose every disputed figure is
#' nil, where another has real ones, is an empty column and not a reading.
#'
#' @section The same argument as find_signs():
#' [find_signs()] does not guess a sign; it enumerates the assignments and
#' reports the one that reaches the total, or says there are several. This is
#' the same search over a different unknown -- not which sign a figure carries
#' but which of two figures was meant -- and it holds to the same rule. A
#' conflict that admits one reconciling reading is resolved. One that admits
#' several is left alone, because a statement that adds up two ways has not
#' told us which way it meant.
#'
#' @section Scoring:
#' A candidate reading is scored by how many subtotals it settles: `complete`
#' and `sides agree` count for it, `sides differ` and `over-specified` against.
#' The winner must score above zero -- a reading that settles nothing is not a
#' resolution -- and must beat every other outright.
#'
#' Ties are left unresolved. Over the corpus, breaking them by taking the first
#' best reading settled seven conflicts, and the picks were visibly wrong: nil
#' for one company's short-term debt, and a figure for another's total assets
#' that was neither of the two under dispute. Eight of the fifteen had a single
#' best reading, and those are the ones worth having.
#'
#' @section What this cannot do:
#' It resolves a conflict; it does not diagnose one. Where a filer has used one
#' element for two different things -- gross and net deferred tax, say -- the
#' arithmetic picks whichever fits the statement, which is the right figure for
#' the balance sheet and says nothing about why the other is there.
#'
#' @param x A tibble from [add_taxonomy()].
#' @param by Columns identifying one statement. Default `c("basis", "period")`.
#' @param max_readings Give up where the candidates multiply beyond this.
#'   Default `256`.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#'
#' @return `x` with the losing duplicates dropped and two columns added:
#'   `resolved`, `TRUE` on a line whose value this chose, and `resolution`,
#'   saying how -- `"rounding"` where the figures were one number at two
#'   precisions, `"empty context"` where the rival figure was a nil column of
#'   its own, `"arithmetic"` where the sums decided. Lines with no
#'   conflict, and conflicts with no single best reading, come back untouched.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("13645183_2024-12-31.xml")
#' check_statement(x)$verdict                  # "conflicting duplicates"
#' check_statement(xbrl_resolve(x))$verdict    # "complete"
#' }
#'
#' @seealso [check_statement()], which reports the conflict, and [xbrl_fill()],
#'   which derives what is absent rather than choosing between what is present.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
xbrl_resolve <- function(x, by = c("basis", "period"), max_readings = 256L,
                         tol = 1) {
  need <- c("statement", "code", "elementid", "value", "is_line")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  x$resolved <- FALSE
  x$resolution <- NA_character_
  d <- which(x$is_line & !is.na(x$value) & !x$abstract %in% TRUE)
  if (length(d) == 0) return(tibble::as_tibble(x))

  # Rounding first, because most of what looks like a conflict is not one.
  if ("decimals" %in% names(x)) {
    rd <- .rounded_duplicates(x, d, by, tol)
    if (length(rd$drop) > 0) {
      x$resolved[rd$keep] <- TRUE
      x$resolution[rd$keep] <- "rounding"
      x <- x[-rd$drop, , drop = FALSE]
      d <- which(x$is_line & !is.na(x$value) & !x$abstract %in% TRUE)
    }
  }

  # Then the context. A balance sheet column is one context, so a line whose
  # figure sits outside the one the rest of the statement uses is not a rival
  # reading -- it belongs to another column.
  if ("contextid" %in% names(x)) {
    cd <- .nil_context_duplicates(x, d, by, tol)
    if (length(cd$drop) > 0) {
      x$resolved[cd$keep] <- TRUE
      x$resolution[cd$keep] <- "empty context"
      x <- x[-cd$drop, , drop = FALSE]
      d <- which(x$is_line & !is.na(x$value) & !x$abstract %in% TRUE)
    }
  }

  key <- do.call(paste, c(x[d, c(by, "statement")], sep = "\r"))
  drop <- integer()
  for (k in unique(key)) {
    i <- d[key == k]
    out <- .resolve_group(x[i, , drop = FALSE], by, max_readings, tol)
    if (is.null(out)) next
    drop <- c(drop, i[out$drop])
    x$resolved[i[out$keep]] <- TRUE
    x$resolution[i[out$keep]] <- "arithmetic"
  }
  if (length(drop) > 0) x <- x[-drop, , drop = FALSE]
  tibble::as_tibble(x)
}

# Two facts for one line that differ only by rounding are one figure written
# twice. XBRL says so itself: `decimals` is the precision the filer claims, so
# -3 means "accurate to thousands", and 1,729,466,749 stated at -3 is
# 1,729,467,000. Treating that as a contradiction condemns a filing for being
# precise in one place and round in another.
#
# The exact figure is kept. A rounded one is a claim about the same number, and
# the tighter claim is the one to carry forward.
.rounded_duplicates <- function(x, d, by, tol) {
  key <- do.call(paste, c(x[d, c(by, "statement", "code")], sep = "
"))
  keep <- integer(); drop <- integer()
  for (k in unique(key[duplicated(key)])) {
    i <- d[key == k]
    v <- x$value[i]
    if (diff(range(v)) < tol) next          # agree already; nothing to resolve
    dp <- suppressWarnings(as.numeric(x$decimals[i]))
    dp[is.na(dp) & x$decimals[i] %in% "INF"] <- Inf
    if (anyNA(dp)) next

    # Every value must be the most precise one rounded to its own stated
    # precision. One that is not is a genuine disagreement, not a rounding.
    best <- which.max(dp)
    ok <- vapply(seq_along(i), function(j) {
      if (is.infinite(dp[j])) return(abs(v[j] - v[best]) < tol)
      abs(round(v[best], dp[j]) - v[j]) < tol
    }, logical(1))
    if (!all(ok)) next
    keep <- c(keep, i[best]); drop <- c(drop, i[-best])
  }
  list(keep = keep, drop = drop)
}

# A balance sheet column is one context. Every line of it -- assets, equity,
# the liabilities -- carries the same contextRef, because that is what a
# context is for. One filing in the corpus states its whole balance sheet
# twice: once in a context holding the figures, once in a context holding
# nothing but nils.
#
# Neither a majority nor the arithmetic separates those. The counts are equal,
# and an empty column adds up perfectly -- nought is nought plus nought. What
# separates them is that a column of nils is not a statement. So the rule is
# narrow: a context whose every disputed figure is nil, where another context
# has real ones, is an empty column rather than a rival reading.
.nil_context_duplicates <- function(x, d, by, tol) {
  grp <- do.call(paste, c(x[d, c(by, "statement")], sep = "\r"))
  keep <- integer(); drop <- integer()
  for (k in unique(grp)) {
    i <- d[grp == k]
    code <- x$code[i]
    disputed <- unique(code[duplicated(code)])
    disputed <- disputed[vapply(disputed, function(cdx)
      diff(range(x$value[i[code == cdx]])) >= tol, logical(1))]
    if (length(disputed) == 0) next

    j <- i[code %in% disputed]
    ctx <- x$contextid[j]
    if (length(unique(ctx[!is.na(ctx)])) < 2) next
    nil_ctx <- names(which(vapply(split(x$value[j], ctx),
                                  function(v) all(abs(v) < tol), logical(1))))
    if (length(nil_ctx) == 0 || length(nil_ctx) == length(unique(ctx))) next

    for (cdx in disputed) {
      rows <- i[code == cdx]
      live <- rows[!x$contextid[rows] %in% nil_ctx]
      if (length(live) != 1) next
      keep <- c(keep, live); drop <- c(drop, setdiff(rows, live))
    }
  }
  list(keep = keep, drop = drop)
}

.resolve_group <- function(g, by, max_readings, tol) {
  conflicting <- .conflicting_codes(g, tol)
  if (length(conflicting) == 0) return(NULL)

  # One set of candidate values per conflicting line. Order is the row order
  # within the group, so a chosen reading maps straight back to rows.
  cand <- lapply(conflicting, function(cd) sort(unique(g$value[g$code == cd])))
  if (prod(lengths(cand)) > max_readings) return(NULL)

  grid <- expand.grid(cand, KEEP.OUT.ATTRS = FALSE)
  base <- g[!duplicated(g$code), , drop = FALSE]

  score <- vapply(seq_len(nrow(grid)), function(r) {
    h <- base
    for (j in seq_along(conflicting))
      h$value[h$code == conflicting[j]] <- grid[r, j]
    v <- .check_group(h, by, tol, character())$verdict
    sum(v %in% c("complete", "sides agree")) -
      sum(v %in% c("sides differ", "over-specified"))
  }, numeric(1))

  best <- which(score == max(score))
  # A reading that settles nothing is not a resolution. Requiring a positive
  # score keeps this from "resolving" a statement it never reconciled.
  if (max(score) <= 0) return(NULL)
  # And it must be the only best reading. Taking the first of several ties is
  # a coin toss wearing the clothes of arithmetic: measured over the corpus it
  # chose nil for a company's short-term debt, and an amount for total assets
  # that was neither of the two figures under dispute.
  if (length(best) != 1) return(NULL)

  chosen <- grid[best, , drop = FALSE]
  keep <- integer(); dropped <- integer()
  for (j in seq_along(conflicting)) {
    rows <- which(g$code == conflicting[j])
    hit <- rows[which(g$value[rows] == chosen[[j]])[1]]
    keep <- c(keep, hit)
    dropped <- c(dropped, setdiff(rows, hit))
  }
  list(keep = keep, drop = dropped)
}
