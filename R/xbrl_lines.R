#' A statement, line by line
#'
#' Returns one statement of every filing in `x` as it is presented: one row per
#' line, in statement order, with the lines the filer left out derived where
#' they can be. This is what an analysis reads -- the fact table is what it is
#' read from.
#'
#' @section Which presentation the filer chose is not your problem:
#' The taxonomy carries the income statement twice, by nature and by function,
#' the balance sheet in three forms, and a dozen sector-specific variants
#' besides. A filing uses one of them and says nothing about the choice.
#' `statement = "income"` accepts whichever it was. Pass a taxonomy statement
#' name instead of an alias to be exact.
#'
#' @section What is derived, and what is not:
#' The balance sheet is a partition: a subtotal is the sum of its parts, so a
#' line the filer omitted can be recovered. Two things do the recovering --
#' five headline identities (`Assets = NoncurrentAssets + CurrentAssets` and
#' its like), then [xbrl_fill()] walking the hierarchy -- and `source` says
#' which, on every row.
#'
#' The income statement is **not** a partition. It is a cascade: each subtotal
#' is the one above it plus and minus the year's items, and the same figure
#' appears in several steps. Summing components into it would double-count, so
#' `fill` does nothing outside the balance sheet, and an income statement comes
#' back as reported. [check_cascade()] is what says whether it reconciles.
#'
#' @section Conflicting figures are settled first:
#' A filing can tag the same line twice with different values -- the same
#' figure at two precisions, or a nil comparative column. [xbrl_resolve()]
#' decides between them before anything is derived, because a subtotal derived
#' from the losing reading is worse than a missing one.
#'
#' @param x A tibble from [read_xbrl()]. The taxonomy has to be on it: the
#'   hierarchy is what names a line the filing never mentioned.
#' @param statement Which statement. `"balance"`, `"income"`, `"cashflow"` or
#'   `"equity"`, or one or more taxonomy statement names for anything else --
#'   `unique(cvrr_line$statement)` lists them.
#' @param basis `"parent"` (default) or `"consolidated"`. An untagged figure is
#'   the parent's, because the taxonomy says so -- see [add_taxonomy()].
#' @param fill Derive the lines the filing left out. Balance sheet only, for
#'   the reason above. `FALSE` returns only what was reported.
#' @param taxonomy Passed to [xbrl_fill()]. `NULL` uses the packaged tables.
#'
#' @return A tibble in statement order, one row per line per filing: the key --
#'   `cvr`, `name`, `period_start`, `period_end` -- then `code`, `elementid`,
#'   `label`, `value`, `currency` and `source`, with `file` last. `source` is
#'   `"reported"`, `"derived: identity"`, or one of [xbrl_fill()]'s values.
#'
#'   `code` is the taxonomy's own numbering and sorts into statement order, but
#'   it is **not** an identifier: 861 of 11,809 codes name a different element
#'   in a different taxonomy version, and 95 do so within one version. Group a
#'   panel on `elementid`.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#'
#' xbrl_lines(x, "balance")
#' xbrl_lines(x, "income")
#'
#' # what the filings did not state, and what it must have been
#' b <- xbrl_lines(x, "balance")
#' b[b$source != "reported", ]
#' }
#'
#' @seealso [xbrl_accounts()], which calls this for both statements at once,
#'   [xbrl_fill()] for the derivation itself, [check_statement()] and
#'   [check_cascade()] to verify the result adds up.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble tibble
#' @export
xbrl_lines <- function(x, statement = "balance",
                       basis = c("parent", "consolidated"), fill = TRUE,
                       taxonomy = NULL) {
  basis <- match.arg(basis)
  want  <- .statement_names(statement)

  need <- c("file", "statement", "code", "elementid", "value", "is_line",
            "basis", "period", "period_end")
  gone <- setdiff(need, names(x))
  if (length(gone) > 0)
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} comes from {.fn read_xbrl}. With {.code taxonomy = FALSE} it needs {.fn add_taxonomy} first."))

  # The currency is read from the whole filing, not from the statement. Three
  # filings report in USD throughout with one stray DKK fact tagged elsewhere,
  # and a balance sheet that never sees it would call them pure USD.
  cur <- vapply(split(x$unit, x$file),
                function(u) .filing_currency(list(unit = u)), character(1))
  nm <- .filing_names(x)

  d <- x[x$statement %in% want & x$basis %in% basis, , drop = FALSE]
  if (nrow(d) == 0) return(.empty_lines())

  # The closing balance, not the comparative: the filing's own declared period
  # end is a column, so this needs no argument and no guessing.
  #
  # Written so a fact with no date of its own drops out rather than becoming a
  # row of NAs: `NA == date` is NA, and a data frame indexed by NA yields a
  # phantom row.
  d <- d[!is.na(d$period) & !is.na(d$period_end) &
           d$period == d$period_end, , drop = FALSE]

  # A dimensioned figure is a part of the line, not the line. Everything below
  # depends on this: derive a subtotal from breakdowns as well as lines and it
  # is counted twice.
  d <- d[d$is_line %in% TRUE, , drop = FALSE]
  if (nrow(d) == 0) return(.empty_lines())

  # Filling is a balance-sheet operation. On a cascade it double-counts.
  fill <- isTRUE(fill) && all(want %in% .BALANCE_STATEMENTS)

  # A bar over the filings, because this is where the seconds go: on a corpus
  # the balance sheet takes over a minute, and a stage that shows nothing while
  # it runs reads as a hang.
  grp <- split(d, d$file)
  pb  <- .file_progress(grp, "  solving lines")
  out <- lapply(grp, function(g) {
    .file_tick(pb)
    .lines_one(g, taxonomy = taxonomy, fill = fill, want = want,
               currency = unname(cur[g$file[1]]),
               name = unname(nm[g$file[1]]))
  })
  .file_done(pb)
  tibble::as_tibble(data.table::rbindlist(out, fill = TRUE))
}

# One filing. Split first, then solve: the identities and the hierarchy walk
# are statements of one company's arithmetic, and running them over a bound
# table would derive a line for one filing out of another's figures.
.lines_one <- function(d, taxonomy, fill, want, currency, name) {
  d <- tryCatch(xbrl_resolve(d, by = c("basis", "period")),
                error = function(e) d)
  if (!"source" %in% names(d)) d$source <- "reported"

  if (fill) {
    # The identities run first, on what the filing actually reported. Running
    # them after the hierarchy walk lets a wrong subtotal stand: given a total
    # and its short-term part, the walk derives the total again from the one
    # child it can see -- 500 where the answer is 600 -- and an identity that
    # trusts it inherits the error.
    d <- .solve_identities(d, .structure_for(
      if ("schemaref" %in% names(d)) d$schemaref[1] else NA_character_,
      taxonomy))
    # xbrl_fill() resets `source`, and the identity rows have to keep theirs.
    # Carried on a column of its own rather than matched back afterwards: the
    # rows it appends get NA there, and every row it did not touch still has
    # the source it arrived with. Matching on `paste(elementid, value)` -- what
    # this did before -- keys on a floating-point number rendered as text, and
    # collides whenever two lines of a statement hold the same amount.
    d$.source_in <- d$source
    f <- tryCatch(
      xbrl_fill(d, taxonomy = taxonomy, statement = want,
                by = c("basis", "period")),
      error = function(e) NULL)
    if (!is.null(f) && nrow(f) > 0) {
      keep <- !is.na(f$.source_in)
      f$source[keep] <- f$.source_in[keep]
      d <- f
    }
    d$.source_in <- NULL
  }

  d <- d[!is.na(d$value) & !d$abstract %in% TRUE, , drop = FALSE]
  d <- d[!duplicated(d[c("elementid", "value", "source")]), , drop = FALSE]
  d <- d[order(d$code), , drop = FALSE]
  if (nrow(d) == 0) return(.empty_lines())

  # No `depth`: it is the number of segments in `code` less two, every time, so
  # it is a second name for something already in the row.
  .key_first(tibble::tibble(
    file = d$file, cvr = d$cvr, name = name,
    period_start = d$period_start, period_end = d$period_end,
    code = d$code, elementid = d$elementid,
    label = d$label, value = d$value, currency = currency,
    source = d$source))
}

.empty_lines <- function()
  .key_first(tibble::tibble(
                 file = character(), cvr = character(), name = character(),
                 period_start = as.Date(character()),
                 period_end = as.Date(character()),
                 code = character(), elementid = character(),
                 label = character(), value = numeric(),
                 currency = character(), source = character()))

# The Danish balance sheet's headline identities, and solving each for its one
# unknown.
#
# `xbrl_fill()` cannot do this. It sums the nearest reported lines beneath a
# subtotal, and beneath `LiabilitiesOtherThanProvisions` the taxonomy offers
# thirty-three children that present the same debts twice over: once by kind --
# mortgage, bank, trade -- and once by term, long and short. Summing the
# nearest reported of both counts every krone twice, so the remainder is never
# nought and nothing is ever derived. On one filing the sum came to 1,220,678
# against a subtotal of 610,339: exactly double.
#
# These five identities are partitions rather than presentations, so they can
# be solved. Measured on the corpus, each holds to within a krone for 99-100%
# of the filings that state every one of its terms, and between them they reach
# the lines a statistic actually asks for.
.BALANCE_IDENTITIES <- list(
  list(total = "Assets",
       parts = c("NoncurrentAssets", "CurrentAssets")),
  list(total = "LiabilitiesAndEquity",
       parts = c("Equity", "Provisions", "LiabilitiesOtherThanProvisions")),
  list(total = "LiabilitiesOtherThanProvisions",
       parts = c("LongtermLiabilitiesOtherThanProvisions",
                 "ShorttermLiabilitiesOtherThanProvisions")),
  list(total = "NoncurrentAssets",
       parts = c("IntangibleAssets", "PropertyPlantAndEquipment",
                 "LongtermInvestmentsAndReceivables")),
  list(total = "CurrentAssets",
       parts = c("Inventories", "ShorttermReceivables", "ShorttermInvestments",
                 "CashAndCashEquivalents"))
)

# Solve each identity for its single unknown, repeatedly: a term recovered from
# one identity is a known term in the next. Three passes settle the chain from
# the balance sheet total down to long-term debt.
.solve_identities <- function(b, st) {
  if (is.null(st) || nrow(b) == 0) return(b)
  for (pass in 1:3) {
    known <- stats::setNames(b$value, b$elementid)
    known <- known[!is.na(known)]
    added <- FALSE
    for (z in .BALANCE_IDENTITIES) {
      have_t <- z$total %in% names(known)
      have_p <- z$parts %in% names(known)
      if (have_t && sum(!have_p) == 1) {
        miss <- z$parts[!have_p]
        v <- known[[z$total]] - sum(known[z$parts[have_p]])
        b <- .add_identity_row(b, st, miss, v)
        added <- TRUE
      } else if (!have_t && all(have_p)) {
        b <- .add_identity_row(b, st, z$total, sum(known[z$parts]))
        added <- TRUE
      }
    }
    if (!added) break
  }
  b
}

# A solved line, placed in the statement by its own code so it sorts where it
# belongs. An element the taxonomy does not place is not invented.
.add_identity_row <- function(b, st, elementid, value) {
  i <- match(elementid, st$elementid)
  if (is.na(i)) return(b)
  r <- b[1, , drop = FALSE]
  r$code <- st$code[i]
  r$elementid <- elementid
  r$label <- st$label[i]
  r$value <- value
  r$source <- "derived: identity"
  if ("abstract" %in% names(r)) r$abstract <- FALSE
  rbind(b, r)
}
