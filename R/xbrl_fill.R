#' Derive the figures a filing left out
#'
#' A filer may report the components of a subtotal without the subtotal, or the
#' subtotal without one of its components. Both are ordinary, and both leave a
#' statistic short of a variable it needs. The presentation hierarchy names
#' every line that belongs, so both can be recovered.
#'
#' @section What is derived, and what is not:
#' Two cases, and only these two.
#'
#' A **subtotal** is derived where the taxonomy places one over lines the filing
#' reports and the subtotal itself is untagged. Its value is the sum of the
#' nearest reported lines beneath it.
#'
#' A **component** is derived where the subtotal is reported, its reported
#' components fall short, and the taxonomy leaves exactly *one* line unaccounted
#' for. The residual is that line. This is how `Anden gæld` comes back: filers
#' routinely give the specified debts and the total and leave the remainder
#' unnamed.
#'
#' Where two or more lines are missing, arithmetic cannot say which of them the
#' remainder belongs to. But a statement has a line whose *purpose* is to hold
#' what is left over -- `Anden gæld`, `Andre tilgodehavender` -- and where that
#' line is among the missing ones, the remainder belongs there by definition
#' rather than by guess. `residual` names those lines; see below.
#'
#' @section Why the residual line has to be named:
#' There is no structural way to find it. `LongtermLiabilitiesOtherThanProvisions`
#' has 37 children in the 2023 taxonomy, three of whose Danish labels begin
#' "Anden" or "Andre": provisions, bond debt, and the catch-all. Only the third
#' is a remainder line; the other two are named categories that happen to start
#' with the same word. Element names carry the same trap -- 67 elements begin
#' `Other`, and most are ordinary categories.
#'
#' Nor does presentation order help: the catch-all sits 28th of the 37, not
#' last. So the map is written out by hand from the labels, it covers the
#' Danish balance sheet, and a caller with a different statement supplies their
#' own. A rule that guessed would put bond debt where trade creditors belong.
#'
#' @section Signs, and why only the balance sheet:
#' This works on lines that add up without a sign convention -- assets,
#' liabilities, equity. The income statement is not filled: its lines carry
#' signs the filer chose, so a residual there is not a value but a value and a
#' direction, and [check_cascade()] is the tool that resolves those.
#'
#' @section A derived figure is not a reported one:
#' Every row comes back with `source`, and the derived ones say how they were
#' arrived at. A statistic that cannot distinguish the two will eventually
#' publish an inference as an observation, so the column is not optional and
#' the derived rows are not silently merged.
#'
#' @param x A tibble from [add_taxonomy()].
#' @param taxonomy A `cvrr_taxonomy` from [read_taxonomy()], or a list of them.
#'   The hierarchy is what names the missing line; the reported facts alone
#'   cannot say which line is absent.
#' @param statement Restrict to these statements. Defaults to the balance
#'   sheet, for the reason above.
#' @param residual Which line receives a remainder that cannot be attributed to
#'   one absent component: a named character vector, subtotal to line.
#'   `"default"` (the default) uses the map for the Danish balance sheet
#'   described below; `NULL` derives only where exactly one component is
#'   missing.
#' @param by Columns identifying one statement. Default
#'   `c("basis", "period")`.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#'
#' @return `x` with derived rows appended and a `source` column added:
#'   `"reported"`, `"derived: sum of components"`, `"derived: residual"` (one
#'   component was missing, so the remainder is that component) or
#'   `"derived: remainder to residual line"` (several were missing, and the
#'   remainder went to the line whose purpose is to hold it).
#'
#' @examples
#' \dontrun{
#' # one filing, so the default grouping is the whole of it
#' x <- read_xbrl("13645183_2024-12-31.xml")
#' filled <- xbrl_fill(x)
#'
#' filled[filled$source != "reported", c("elementid", "label", "value", "source")]
#'
#' # a directory: the grouping has to say which filing a line belongs to
#' xbrl_fill(read_xbrl("materiale/xbrl"), by = c("file", "basis", "period"))
#' }
#'
#' @seealso [check_statement()], which reports the same two situations without
#'   resolving them, and [check_movement()], whose `assume_nil` is the same idea
#'   applied to a schedule's endpoints.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
xbrl_fill <- function(x, taxonomy = NULL, statement = c("BalanceSheetAccountForm",
                                                 "BalanceSheetReportForm"),
                      residual = "default", by = c("basis", "period"),
                      tol = 1) {
  need <- c("statement", "code", "elementid", "value", "schemaref", "is_line")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  if (identical(residual, "default")) residual <- .dk_residual_lines
  if (!is.null(residual) && (is.null(names(residual)) || !is.character(residual)))
    cli::cli_abort(c(
      "{.arg residual} must be a named character vector, {.val default}, or {.code NULL}.",
      "i" = "Names are the subtotal; values are the line that receives its remainder."
    ))

  if (inherits(taxonomy, "cvrr_taxonomy")) taxonomy <- list(taxonomy)
  if (!is.null(taxonomy) &&
      !all(vapply(taxonomy, inherits, logical(1), "cvrr_taxonomy")))
    cli::cli_abort("{.arg taxonomy} must be a {.cls cvrr_taxonomy} or a list of them.")

  x$source <- "reported"
  d <- x[x$is_line & !is.na(x$value), , drop = FALSE]
  if (!is.null(statement)) d <- d[d$statement %in% statement, , drop = FALSE]
  if (nrow(d) == 0) return(tibble::as_tibble(x))

  key   <- do.call(paste, c(d[c(by, "statement")], sep = "\r"))
  keys  <- unique(key)
  refs  <- d$schemaref[match(keys, key)]
  cache <- new.env(parent = emptyenv())

  rows <- lapply(seq_along(keys), function(i) {
    ref <- refs[i]
    if (is.na(ref)) return(NULL)
    g <- d[key == keys[i], , drop = FALSE]
    if (is.null(cache[[ref]])) {
      st0 <- .structure_for(ref, taxonomy)
      if (is.null(st0)) return(NULL)
      cache[[ref]] <- st0
    }
    st <- cache[[ref]]
    st <- st[st$statement == g$statement[1] & !st$abstract, , drop = FALSE]
    if (nrow(st) == 0) return(NULL)
    .fill_one(g, st, by, tol, residual)
  })

  out <- data.table::rbindlist(
    c(list(x), rows[!vapply(rows, is.null, logical(1))]), fill = TRUE)
  tibble::as_tibble(out)
}

# Where a Danish balance sheet puts what is left over. Chosen by hand from the
# labels, because no structural rule finds them: `LongtermLiabilities...` has
# three children whose label begins "Anden" or "Andre", and only one is the
# catch-all -- the others are provisions and bond debt, named categories that
# happen to start with the same word. A rule that guessed would misattribute
# them, so the map is explicit and the caller can replace it.
.dk_residual_lines <- c(
  LongtermLiabilitiesOtherThanProvisions =
    "OtherPayablesIncludingTaxPayablesLiabilitiesOtherThanProvisionsLongterm",
  ShorttermLiabilitiesOtherThanProvisions =
    "OtherPayablesIncludingTaxPayablesLiabilitiesOtherThanProvisionsShortterm",
  LongtermReceivables  = "OtherLongtermReceivables",
  ShorttermReceivables = "OtherShorttermReceivables",
  Provisions           = "OtherProvisions"
)
# Equity is deliberately absent. Mapping its remainder to `OtherReserves`
# placed 631 figures there across the corpus, and a Danish equity remainder is
# conventionally retained earnings -- "Overfoert resultat" -- not other
# reserves. Which of the two is right was not established, and a default that
# systematically files retained earnings under reserves would be the exact
# misattribution this argument exists to avoid. A caller who has checked their
# own population can add it.

# One statement, one period, one basis.
.fill_one <- function(g, st, by, tol, residual) {
  st <- st[!duplicated(st$code), , drop = FALSE]
  reported <- stats::setNames(g$value[!duplicated(g$code)], g$code[!duplicated(g$code)])

  # Each code's children, looked up rather than searched for: the search ran
  # over the whole structure for every code it was asked about, and it is
  # asked about every code and again inside nearest(). split() keeps the
  # structure's own order, so the children come back as they did.
  kids_map <- split(st$code, sub("[.][^.]+$", "", st$code))
  kids_of <- function(cd) {
    k <- kids_map[[cd]]
    if (is.null(k)) character() else k
  }
  # The nearest reported lines beneath a code: a filer may report a figure and
  # leave its own parent empty, so descending only one level would miss it.
  nearest <- function(cd) {
    out <- character()
    stack <- kids_of(cd)
    while (length(stack) > 0) {
      k <- stack[1]; stack <- stack[-1]
      if (k %in% names(reported)) out <- c(out, k) else stack <- c(stack, kids_of(k))
    }
    out
  }

  new <- list()
  row_for <- function(code, value, source) {
    tpl <- g[1, , drop = FALSE]
    i <- match(code, st$code)
    tpl$code <- code
    tpl$elementid <- st$elementid[i]
    tpl$label <- if ("label" %in% names(st)) st$label[i] else NA_character_
    tpl$value <- value
    tpl$source <- source
    tpl
  }

  parents <- st$code[st$code %in% names(kids_map)]

  for (cd in parents) {
    below <- nearest(cd)
    total <- if (length(below) == 0) 0 else sum(reported[below])

    if (!cd %in% names(reported)) {
      # Nothing reported above and nothing below: not a gap, an empty branch.
      if (length(below) == 0) next
      # No subtotal over lines that are there: it is their sum.
      new[[length(new) + 1L]] <- row_for(cd, total, "derived: sum of components")
      next
    }

    gap <- reported[[cd]] - total
    if (abs(gap) <= tol) next
    # A subtotal that exceeds what is specified below it, with exactly one line
    # of the hierarchy unaccounted for: the remainder is that line.
    absent <- setdiff(kids_of(cd), c(below, names(reported)))
    absent <- absent[vapply(absent, function(k)
      length(intersect(nearest(k), names(reported))) == 0, logical(1))]

    if (length(absent) == 1) {
      new[[length(new) + 1L]] <- row_for(absent, gap, "derived: residual")
      next
    }
    # Several lines unaccounted for. The remainder cannot be attributed to any
    # one of them by arithmetic -- but a statement has a line whose purpose is
    # to hold what is left over, and where the caller has named it and it is
    # among the absent, that is where the remainder belongs.
    # `[` not `[[`: a name absent from a character vector is an error under
    # `[[`, and most subtotals are not in the map.
    parent_el <- st$elementid[match(cd, st$code)]
    target <- unname(residual[parent_el])
    if (length(target) != 1 || is.na(target)) next
    at <- absent[match(target, st$elementid[match(absent, st$code)])]
    at <- at[!is.na(at)]
    if (length(at) != 1) next
    new[[length(new) + 1L]] <- row_for(at, gap, "derived: remainder to residual line")
  }

  if (length(new) == 0) return(NULL)
  data.table::rbindlist(new, fill = TRUE)
}
