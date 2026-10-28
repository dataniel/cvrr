#' Find sign combinations that sum to a target
#'
#' Given a set of labelled values and a target total, determines which
#' multipliers (`+1`, `-1`, or `0`) to apply to each value so that the signed
#' sum equals the target. Uses a *meet-in-the-middle* search, so the cost is
#' `2 * 3^(n/2)` rather than `3^n`.
#'
#' This reconciles accounting line items whose sign convention is unknown:
#' XBRL amounts often arrive without a meaningful sign, because the convention
#' varies between preparers. An income statement has to add up, and that is
#' enough to recover the signs.
#'
#' @section What "solved" means, and what it does not:
#' Uniqueness is not proof. If the true assignment is excluded -- say more
#' items than `max_zeros` genuinely do not belong -- a coincidental one can fit
#' alone and be reported as certain. Read a `status` of `"unique"` as "only one
#' combination reaches the total", not as "this combination is right".
#'
#' Nothing is dropped. Every input row comes back, and `status` says what
#' happened to its group:
#'
#' * `"unique"` -- exactly one assignment reaches the total.
#' * `"ambiguous"` -- several do. Items that get the *same* sign in all of them
#'   are still determined, so their `sign` is filled in with `certain = TRUE`;
#'   the rest are `NA`. This is a logical consequence, not a guess.
#' * `"unsolved"` -- no assignment reaches the total within `max_zeros`.
#' * `"no_total"` / `"duplicate_total"` -- the group has no row labelled
#'   `total_label`, or more than one.
#'
#' Among competing assignments, those using the fewest zeros are preferred: a
#' solution that uses every reported line item is more plausible than one that
#' discards two. `status` and `n_solutions` describe the group *after* that
#' preference is applied.
#'
#' @param df A data frame containing labels and values.
#' @param label_col Column containing item labels, unquoted or as a string.
#' @param value_col Column containing numeric values, unquoted or as a string.
#' @param total_label Label of the row whose value is the reconciliation
#'   target. Default: `"total"`.
#' @param positive,negative Labels constrained to a non-negative multiplier
#'   (`+1`, or `0` where `max_zeros` allows the item to be dropped) or a
#'   non-positive one (`-1` or `0`). Optional. Labels that match nothing are
#'   reported.
#' @param by Optional grouping columns: unquoted (`by = year`), several
#'   (`by = c(year, firm)`), or as strings. The reconciliation is performed
#'   separately for each group.
#' @param max_zeros Maximum number of zero coefficients allowed in a solution,
#'   i.e. how many items may be excluded. Default: `2L`.
#' @param tol Absolute tolerance when comparing a signed sum to the target.
#'   Default `1e-6`. Filings that round to whole thousands may need more. A
#'   tolerance finer than floating point can resolve at the size of the values
#'   is raised to that resolution -- about 0.001 on a total of a hundred
#'   billion.
#'
#' @return A tibble with one row per input row, carrying the grouping columns,
#'   the label and value columns, and four more: `sign` (the resolved
#'   multiplier, `NA` when unresolved), `certain` (whether every candidate
#'   agreed on it), `n_solutions` and `status`. The value column holds the
#'   signed value, or `NA` where the sign is unresolved.
#'
#' @examples
#' items <- data.frame(
#'   label = c("revenue", "costs", "depreciation", "total"),
#'   value = c(100, 40, 10, 50)
#' )
#' find_signs(items, label, value, total_label = "total")
#'
#' @seealso [read_xbrl()]. The XBRL taxonomy publishes these weights in its
#'   calculation linkbase, which would make this search an independent check
#'   on them. The package does not read the linkbase yet.
#'
#' @importFrom cli cli_abort cli_warn cli_alert_info
#' @importFrom cli cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
find_signs <- function(df, label_col, value_col, total_label = "total",
                       positive = NULL, negative = NULL, by = NULL,
                       max_zeros = 2L, tol = 1e-6) {

  label_nm <- .col_names(substitute(label_col), "label_col")
  value_nm <- .col_names(substitute(value_col), "value_col")
  by_nm    <- .col_names(substitute(by), "by")

  if (length(label_nm) != 1 || length(value_nm) != 1)
    cli::cli_abort("{.arg label_col} and {.arg value_col} must each name one column.")
  missing_cols <- setdiff(c(label_nm, value_nm, by_nm), names(df))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg df}: {.val {missing_cols}}."
    )
  if (!is.numeric(df[[value_nm]]))
    cli::cli_abort(c(
      "{.arg value_col} ({.val {value_nm}}) must be numeric, not {.cls {class(df[[value_nm]])[1]}}.",
      "i" = "XBRL facts arrive as text; convert with {.code as.numeric()} first."
    ))
  if (!is.numeric(tol) || length(tol) != 1 || tol <= 0)
    cli::cli_abort("{.arg tol} must be a single positive number.")

  unknown <- setdiff(c(positive, negative), unique(df[[label_nm]]))
  if (length(unknown) > 0)
    cli::cli_warn(c(
      "{cli::qty(length(unknown))}Label{?s} in {.arg positive}/{.arg negative} not present in the data: {.val {utils::head(unknown, 5)}}.",
      "i" = "The constraint has no effect; check for a typo."
    ))

  groups <- .split_groups(df, by_nm)
  results <- vector("list", length(groups$rows))

  show_progress <- length(groups$rows) > 1
  if (show_progress) cli::cli_progress_bar("Finding signs", total = length(groups$rows))
  for (i in seq_along(groups$rows)) {
    results[[i]] <- .find_signs_group(
      df[groups$rows[[i]], , drop = FALSE], label_nm, value_nm, total_label,
      positive, negative, max_zeros, tol
    )
    if (!is.null(groups$keys))
      results[[i]] <- cbind(groups$keys[i, , drop = FALSE], results[[i]],
                            row.names = NULL)
    if (show_progress) cli::cli_progress_update()
  }
  if (show_progress) cli::cli_progress_done()

  out <- tibble::as_tibble(data.table::rbindlist(results, fill = TRUE))
  .report_status(vapply(results, function(x) x$status[1], character(1)))
  out
}

# One group: solve, apply the fewest-zeros preference, and fill in whatever the
# surviving candidates agree on.
.find_signs_group <- function(g, label_nm, value_nm, total_label,
                              positive, negative, max_zeros, tol) {
  labels <- g[[label_nm]]
  values <- g[[value_nm]]

  frame <- function(sign, status, n_solutions = 0L) {
    sign <- as.integer(sign)          # drop any attributes; they would ride along
    out <- data.frame(labels, values * sign, sign, !is.na(sign),
                      n_solutions, status, stringsAsFactors = FALSE)
    names(out) <- c(label_nm, value_nm, "sign", "certain", "n_solutions", "status")
    out
  }

  total_idx <- which(labels == total_label)
  if (length(total_idx) == 0) return(frame(rep(NA_integer_, length(labels)), "no_total"))
  if (length(total_idx) > 1)  return(frame(rep(NA_integer_, length(labels)), "duplicate_total"))

  # The total is the target, not a line item -- its sign is never in question,
  # so it keeps its value even when the line items cannot be resolved.
  unresolved <- function(status) {
    sign <- rep(NA_integer_, length(labels))
    sign[total_idx] <- 1L
    frame(sign, status)
  }
  if (length(labels) < 2) return(unresolved("unsolved"))

  target <- values[total_idx]
  items  <- values[-total_idx]
  fixed  <- rep(0L, length(items))
  fixed[labels[-total_idx] %in% positive] <-  1L
  fixed[labels[-total_idx] %in% negative] <- -1L

  mid <- length(items) %/% 2L
  i1  <- seq_len(mid)
  i2  <- seq.int(mid + 1L, length(items))

  rows <- max(.sign_grid_rows(fixed[i1]), .sign_grid_rows(fixed[i2]))
  if (rows > 5e6)
    cli::cli_abort(c(
      "Too many items to reconcile: {length(items)} line items would enumerate {format(rows, big.mark = ',')} combinations per half.",
      "i" = "Constrain items with {.arg positive}/{.arg negative}, or split the statement into subtotals."
    ))

  sols <- .meet_in_middle(items[i1], items[i2], target, max_zeros,
                          fixed[i1], fixed[i2], tol = tol)
  if (nrow(sols) == 0) return(unresolved("unsolved"))

  # Prefer assignments that use every item: a solution discarding two line
  # items is a weaker claim than one that uses them all.
  zeros <- rowSums(sols == 0L)
  sols  <- sols[zeros == min(zeros), , drop = FALSE]

  agreed <- apply(sols, 2L, function(x) if (all(x == x[1])) x[1] else NA_integer_)
  sign   <- integer(length(labels))
  sign[-total_idx] <- agreed
  sign[total_idx]  <- 1L

  frame(sign, if (nrow(sols) == 1L) "unique" else "ambiguous", nrow(sols))
}

# Row indices per group plus the key rows, without dplyr. Groups appear in
# sorted key order, matching group_split()/group_keys().
.split_groups <- function(df, by_nm) {
  if (is.null(by_nm)) return(list(rows = list(seq_len(nrow(df))), keys = NULL))

  keys <- unique(df[by_nm])
  keys <- keys[do.call(order, keys), , drop = FALSE]
  f <- do.call(paste, c(df[by_nm], sep = "\r"))
  k <- do.call(paste, c(keys, sep = "\r"))
  list(rows = split(seq_len(nrow(df)), factor(f, levels = k)), keys = keys)
}

# Accept `col`, `c(a, b)`, "col" and c("a", "b") alike. Names from the caller
# are turned into values here, never matched positionally against a formal.
.col_names <- function(expr, arg) {
  if (is.null(expr)) return(NULL)
  if (is.character(expr)) return(as.character(expr))
  if (is.symbol(expr)) return(as.character(expr))
  if (is.call(expr) && identical(expr[[1]], quote(c)))
    return(unlist(lapply(as.list(expr)[-1], .col_names, arg = arg)))
  cli::cli_abort(c(
    "{.arg {arg}} must name columns.",
    "i" = "Write {.code {arg} = column}, {.code {arg} = c(one, two)}, or use strings."
  ))
}

# One closing line saying what the run actually produced. Silence would hide
# that half the groups never reconciled.
.report_status <- function(status) {
  if (length(status) <= 1) return(invisible(NULL))
  tab <- table(factor(status, levels = c("unique", "ambiguous", "unsolved",
                                         "no_total", "duplicate_total")))
  parts <- sprintf("%d %s", as.integer(tab), names(tab))[tab > 0]
  cli::cli_alert_info("{length(status)} group{?s}: {parts}.")
}

