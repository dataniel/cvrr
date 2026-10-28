#' Reconcile a statement against its own hierarchy
#'
#' Checks every subtotal in a tidied statement against the lines below it, and
#' says which of three things is true of each: the reported detail adds up, the
#' statement presents the same figures under two groupings, or there is
#' unspecified detail left over.
#'
#' @section Children are not one level down:
#' A filer may report a figure while leaving its intermediate parent empty, so
#' the lines that partition a subtotal are the *nearest reported* descendant on
#' each branch. A fixed depth+1 rule reports discrepancies that are not there.
#'
#' @section Debt is presented twice:
#' A Danish balance sheet lists debt both by counterparty and by maturity, so a
#' subtotal's children can hold the same money twice over. When both groupings
#' are complete the children sum to an exact multiple of the subtotal, but they
#' usually are not: one partition is itemised in full while the other is only
#' partly filled in, and the sum lands somewhere in between.
#'
#' So the test is not a ratio but a search: is there a *subset* of the children
#' that hits the subtotal exactly? If there is, that subset is a complete
#' grouping and the rest is another view of the same figures. The verdict is
#' `"two groupings"` and `n_partition` says how many lines the complete one
#' holds -- a presentation feature, named rather than reported as an error.
#'
#' @section Repeated lines:
#' The same statement line can arrive more than once -- one filing in a sample
#' of 100 reported its cash position six times and its receivables twice, all
#' with the same figure. Repeats that agree are collapsed silently, because
#' nothing turns on them. Repeats that *disagree* are a different matter: the
#' filing states two different amounts for one line, and the verdict says
#' `"conflicting duplicates"` rather than quietly keeping whichever came first.
#'
#' @section The closing identity:
#' Checking each subtotal against the lines below it never reaches the one
#' identity a statement exists to assert: that assets equal liabilities and
#' equity. Those two are not parent and child but siblings of opposite sign
#' under an abstract root, so they are not summed -- they are compared.
#'
#' The rule needs no list of element names. Where a node's reported children
#' split into a debit group and a credit group, the two must be equal, and the
#' verdict is `"sides agree"` or `"sides differ"`. In the Danish balance sheet
#' that is exactly Aktiver against Passiver.
#'
#' The income statement has no such identity: its cascade runs through signed
#' subtotals to Aarets resultat, which is [find_signs()]'s problem, not a sum.
#'
#' @section What an absent line means:
#' The taxonomy offers dozens of alternatives under a subtotal and a company
#' uses a handful. An unreported line means "not applicable", not "unknown", so
#' a residual of zero is the normal and expected result -- it says the reported
#' detail already exhausts the subtotal and can be used as it stands.
#'
#' @param x A tibble from [add_taxonomy()].
#' @param by Columns identifying one statement instance. `NULL`, the default,
#'   uses whichever of `file`, `basis` and `period` the table has -- `file`
#'   because read_xbrl() returns many filings at once, and without it two
#'   companies with the same balance sheet date are checked as one.
#' @param period `"closing"`, the default, checks the year the filing declares
#'   for itself and leaves its comparative out -- a comparative is usually
#'   partial, and its gaps are not the filing's. `NULL` checks every period the
#'   table carries.
#' @param tol Absolute tolerance in the reporting currency. Default `1`.
#'
#' @return A tibble with one row per subtotal that has reported detail:
#'   the `by` columns, `statement`, `code`, `elementid`, `label`, `total`,
#'   `specified` (the sum of the nearest reported descendants), `residual`,
#'   `n_children` and `verdict`.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' checks <- check_statement(x)
#' table(checks$verdict)
#'
#' # what is left unexplained
#' checks[checks$verdict == "unspecified remainder", ]
#' }
#'
#' @seealso [add_taxonomy()], and [find_signs()] for the income statement, whose
#'   lines carry signs and so are not a plain sum.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_statement <- function(x, by = NULL, period = "closing", tol = 1) {
  by <- .default_by(x, by)
  x  <- .closing_only(x, period)
  need <- c("statement", "code", "elementid", "label", "value")
  missing_cols <- setdiff(c(need, by), names(x))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Column{?s} not found in {.arg x}: {.val {missing_cols}}."
    )

  # A fact belonging to no statement has no subtotal to reconcile against.
  # add_taxonomy() keeps those rows -- they are what xbrl_company() reads -- so
  # a check over statements has to leave them out itself.
  d <- x[!is.na(x$value) & !is.na(x$statement) & !is.na(x$code) &
           x$is_line %in% TRUE & !x$abstract %in% TRUE, , drop = FALSE]
  if (nrow(d) == 0)
    return(tibble::as_tibble(data.frame()))

  # A plain data frame for the loop. Indexing a tibble row by row validates
  # every column each time, and on 200 filings that was a large part of the run.
  d <- as.data.frame(d)

  # paste, not interaction(): interaction() takes its factors through `...`,
  # so handing it one list groups everything into a handful of buckets and the
  # checks run across companies that have nothing to do with each other.
  key <- do.call(paste, c(d[c(by, "statement")], sep = "\r"))
  rows <- lapply(split(seq_len(nrow(d)), key), function(i) {
    g <- d[i, , drop = FALSE]
    conflicting <- .conflicting_codes(g, tol)
    g <- g[!duplicated(g$code), , drop = FALSE]
    .check_group(g, by, tol, conflicting)
  })
  tibble::as_tibble(data.table::rbindlist(rows, fill = TRUE))
}

.check_group <- function(g, by, tol, conflicting = character()) {
  # Each line's nearest reported ancestor, once for the group. Asking every
  # subtotal which lines lie below it scanned the whole statement per
  # subtotal; with the ancestor known, a subtotal's children are a lookup.
  up <- .nearest_reported_parent(g$code)
  kids_of <- split(seq_len(nrow(g)), factor(up, levels = g$code))

  # One reported child is enough to check: subtotal minus that child is the
  # unspecified remainder, which is exactly what a statistic needs to see.
  has <- which(lengths(kids_of) > 0)
  if (length(has) == 0)
    return(.check_sides(g, by, tol, structure_of(g), up))

  n_kids    <- lengths(kids_of)[has]
  total     <- g$value[has]
  specified <- vapply(kids_of[has], function(k) sum(g$value[k]), numeric(1))
  residual  <- total - specified
  n_part <- vapply(seq_along(has), function(j)
    if (abs(residual[j]) < tol) n_kids[[j]]
    else as.integer(.subset_hitting(g$value[kids_of[[has[j]]]], total[j], tol)),
    integer(1))

  # A line stated twice with two different amounts makes the subtotal above
  # it unjudgeable: which of the two was meant is not ours to decide.
  clash <- vapply(seq_along(has), function(j)
    any(c(g$code[has[j]], g$code[kids_of[[has[j]]]]) %in% conflicting),
    logical(1))
  verdict <- ifelse(clash, "conflicting duplicates",
             ifelse(abs(residual) < tol, "complete",
             ifelse(!is.na(n_part), "two groupings",
             ifelse(residual > 0, "unspecified remainder", "over-specified"))))

  out <- cbind(
    g[has, by, drop = FALSE],
    data.frame(statement = g$statement[has], code = g$code[has],
               elementid = g$elementid[has], label = g$label[has],
               total = total, specified = unname(specified),
               residual = unname(residual), n_children = unname(n_kids),
               n_partition = n_part, verdict = verdict,
               stringsAsFactors = FALSE),
    row.names = NULL)
  rbind(out, .check_sides(g, by, tol, structure_of(g), up))
}

# The nearest code above each one that is itself in `codes`, or NA. Walks up
# one segment at a time, so it costs the depth of the hierarchy per line and
# not the length of the statement.
.nearest_reported_parent <- function(codes) {
  out <- rep(NA_character_, length(codes))
  cur <- codes
  # A code with no dot left has nowhere further up to go.
  open <- grepl(".", cur, fixed = TRUE)
  while (any(open)) {
    cur[open] <- sub("[.][^.]+$", "", cur[open])
    hit <- open & cur %in% codes
    out[hit] <- cur[hit]
    open <- open & !hit & grepl(".", cur, fixed = TRUE)
  }
  out
}

# The two sides of a statement: where the reported lines under one node split
# into a debit group and a credit group, the groups are compared rather than
# added. Nothing is named; the balance attribute decides.
.check_sides <- function(g, by, tol, roots,
                         up = .nearest_reported_parent(g$code)) {
  out <- lapply(roots, function(rt) {
    # A root is not reported, so its children are the lines below it with no
    # reported line between: their nearest reported ancestor, if any, lies
    # outside it.
    pre <- paste0(rt, ".")
    kids <- g[startsWith(g$code, pre) & (is.na(up) | !startsWith(up, pre)), ,
              drop = FALSE]
    kids <- kids[!is.na(kids$balance), , drop = FALSE]
    if (nrow(kids) < 2) return(NULL)
    dr <- kids$value[kids$balance == "debit"]
    cr <- kids$value[kids$balance == "credit"]
    if (length(dr) == 0 || length(cr) == 0) return(NULL)

    diff <- sum(dr) - sum(cr)
    cbind(
      g[1, by, drop = FALSE],
      data.frame(statement = g$statement[1], code = rt, elementid = NA_character_,
                 label = "debit side vs credit side",
                 total = sum(dr), specified = sum(cr), residual = diff,
                 n_children = nrow(kids), n_partition = NA_integer_,
                 verdict = if (abs(diff) < tol) "sides agree" else "sides differ",
                 stringsAsFactors = FALSE),
      row.names = NULL
    )
  })
  do.call(rbind, rows_or_null(out))
}

# Nodes that have reported lines below them but are not reported themselves:
# the abstract roots a statement hangs from.
structure_of <- function(g) {
  parents <- unique(sub("[.][0-9]{3}$", "", g$code))
  setdiff(parents, g$code)
}

rows_or_null <- function(x) x[!vapply(x, is.null, logical(1))]

# Codes reported more than once with values that do not agree.
.conflicting_codes <- function(g, tol) {
  dup <- unique(g$code[duplicated(g$code)])
  dup[vapply(dup, function(cd) {
    v <- g$value[g$code == cd]
    diff(range(v)) >= tol
  }, logical(1))]
}

# Is there a proper subset of `values` summing to `target`? Returns its size,
# or NA. This is the same meet-in-the-middle search find_signs() runs, with the
# multipliers restricted to {0, 1}: 2^(n/2) per half rather than 2^n.
#
# Prefer the largest such subset. A statement's real grouping is the one that
# itemises most; a small coincidental subset hitting the same figure is not the
# claim being made.
.subset_hitting <- function(values, target, tol) {
  n <- length(values)
  if (n < 2 || n > 40) return(NA_integer_)

  mid <- n %/% 2L
  i1  <- seq_len(mid)
  i2  <- seq.int(mid + 1L, n)

  sols <- .meet_in_middle(values[i1], values[i2], target,
                          max_zeros = n, c1 = rep(1L, length(i1)),
                          c2 = rep(1L, length(i2)), tol = tol)
  if (nrow(sols) == 0) return(NA_integer_)

  sizes <- rowSums(sols == 1L)
  sizes <- sizes[sizes > 0 & sizes < n]   # neither empty nor everything
  if (length(sizes) == 0) return(NA_integer_)
  max(sizes)
}

# The reported lines that partition a subtotal: everything below it that has no
# other reported line between it and the subtotal.
.nearest_children <- function(g, code) {
  below <- g[startsWith(g$code, paste0(code, ".")), , drop = FALSE]
  if (nrow(below) == 0) return(below)
  below[!vapply(below$code, function(cd)
    any(startsWith(cd, paste0(below$code, "."))), logical(1)), , drop = FALSE]
}
