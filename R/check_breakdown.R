#' Reconcile a dimensional breakdown against the line it breaks down
#'
#' Where a figure is reported both as a statement line and split across the
#' members of a dimension -- fixed assets by class, equity by reserve -- the
#' parts must add up to the whole. This checks that they do.
#'
#' @section Why it is worth checking separately:
#' [check_statement()] follows the presentation hierarchy, which runs down the
#' statement. A breakdown runs the other way, across a dimension, and nothing
#' in the hierarchy reaches it. It is also where a particular error hides.
#'
#' A filing in a sample of 300 Greenlandic companies tags its balance sheet in
#' kroner and its fixed-asset note in thousands, in the same document. Its
#' additions for the year read `229` and `174` when they are 229,000 and
#' 174,000 kr, which would have entered an investment series at a thousandth of
#' their size. Nothing else catches it: the unit is `iso4217:DKK` like every
#' other filing's, `decimals` is consistent, and the company's registered
#' capital clears its legal floor because the *balance sheet* is right. Only
#' the note is wrong, and only the filing's own arithmetic shows it.
#'
#' So the ratio is the point, not the difference. It is `1` when the breakdown
#' agrees, `1000` or `0.001` when the two sit on different scales, and
#' something near but not equal to 1 when the breakdown does not cover every
#' member.
#'
#' @param x A tibble from [add_taxonomy()], read with `dimensions = TRUE` so that
#'   each dimension has its own column.
#' @param by Columns identifying one statement instance. `NULL`, the default,
#'   uses whichever of `file`, `basis` and `period` the table has -- `file`
#'   because read_xbrl() returns many filings at once, and without it two
#'   companies with the same balance sheet date are checked as one; add the company identifier for a panel.
#' @param period `"closing"`, the default, checks the year the filing declares
#'   for itself and leaves its comparative out -- a comparative is usually
#'   partial, and its gaps are not the filing's. `NULL` checks every period the
#'   table carries.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#'
#' @return A tibble with one row per element and dimension that is reported
#'   both ways: the `by` columns, `elementid`, `label`, `dimension`, `line`
#'   (the undimensioned figure), `parts` (the members summed), `n_members`,
#'   `ratio` and `verdict` -- one of `"agrees"`, `"scaled by 1000"`,
#'   `"scaled by 1/1000"` or `"parts do not cover the line"`.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' b <- check_breakdown(x)
#' b[b$verdict != "agrees", ]
#' }
#'
#' @seealso [check_statement()] for the hierarchy, [add_taxonomy()].
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_breakdown <- function(x, by = NULL, period = "closing", tol = 1) {
  by <- .default_by(x, by)
  x  <- .closing_only(x, period)
  need <- c("elementid", "label", "value", "is_line")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  dims <- .dimension_columns(x)
  if (length(dims) == 0) return(tibble::as_tibble(data.frame()))

  # A fact comes back once per statement that presents it, so the same
  # breakdown would be reported once per statement. It is a property of the
  # element, not of the statement, so collapse them.
  x <- x[!is.na(x$value), , drop = FALSE]
  x <- x[!duplicated(x[c(by, "elementid", "contextid")]), , drop = FALSE]
  rows <- lapply(dims, function(d) .check_one_dimension(x, d, dims, by, tol))
  tibble::as_tibble(data.table::rbindlist(rows, fill = TRUE))
}

.check_one_dimension <- function(x, d, dims, by, tol) {
  # Only facts split along this one dimension: a fact carrying a second
  # breakdown as well would be counted once per member of each, and the sum
  # would exceed the line for a reason that has nothing to do with scale.
  others <- setdiff(dims, d)
  only_d <- !is.na(x[[d]]) &
    (length(others) == 0 | Reduce(`&`, lapply(others, function(o) is.na(x[[o]])), TRUE))

  parts <- x[only_d, , drop = FALSE]
  line  <- x[x$is_line %in% TRUE & !is.na(x$statement), , drop = FALSE]
  if (nrow(parts) == 0 || nrow(line) == 0) return(NULL)

  key <- function(z) do.call(paste, c(z[c(by, "elementid")], sep = "\r"))
  parts_key <- key(parts)
  line_key  <- key(line)

  shared <- intersect(unique(parts_key), unique(line_key))
  if (length(shared) == 0) return(NULL)

  out <- lapply(shared, function(k) {
    p <- parts[parts_key == k, , drop = FALSE]
    p <- p[!duplicated(p[[d]]), , drop = FALSE]
    l <- line[line_key == k, , drop = FALSE]
    if (length(unique(l$value)) != 1) return(NULL)   # conflicting line, not ours

    total <- l$value[1]
    sum_p <- sum(p$value)
    ratio <- if (sum_p == 0) NA_real_ else total / sum_p

    verdict <- if (abs(total - sum_p) < tol) "agrees"
               else if (!is.na(ratio) && abs(ratio - 1000) < 10) "scaled by 1000"
               else if (!is.na(ratio) && abs(ratio - 0.001) < 1e-5) "scaled by 1/1000"
               else "parts do not cover the line"

    cbind(
      l[1, by, drop = FALSE],
      data.frame(elementid = l$elementid[1], label = l$label[1], dimension = d,
                 line = total, parts = sum_p, n_members = nrow(p),
                 ratio = ratio, verdict = verdict, stringsAsFactors = FALSE),
      row.names = NULL
    )
  })
  do.call(rbind, rows_or_null(out))
}

# The columns add_taxonomy() spread out, found by their prefix rather than by
# excluding everything else: a caller who adds a character column of their own
# would otherwise have it checked as a dimension.
.dimension_columns <- function(x) {
  d <- grep("^dim_", names(x), value = TRUE)
  # ConsolidatedSolo is not a breakdown: it is already the `basis` column and
  # sits in `by`, so comparing its members against the line is circular.
  setdiff(d, "dim_ConsolidatedSolo")
}
