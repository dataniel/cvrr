#' Validate the filings once, and carry the work along
#'
#' Standardises the facts and runs everything the analysis functions need --
#' who each company is, the checks of the three statements, and the
#' statements line by line on both bases -- and returns the facts with that
#' work attached. [xbrl_screen()], [xbrl_panel()], [xbrl_lines()] and
#' [xbrl_report_data()] read it instead of doing it again, so a pipeline pays
#' for the expensive part once:
#'
#' ```r
#' v <- read_xbrl("materiale/xbrl") |>
#'   xbrl_validate()
#' s <- xbrl_screen(v)
#' p <- xbrl_panel(v)
#' xbrl_report(xbrl_report_data(v, cvr = "12345678"), "12345678.html")
#' ```
#'
#' @section Why the facts and not a panel:
#' A panel is one row per company and year and a few dozen variables, and
#' that is a view, not the data. It leaves out the dimensions and the notes,
#' every line beyond its variables, where each figure came from -- reported,
#' derived or corrected -- the comparatives the unit check reads, and the
#' auditor's text. So the validated object stays the facts, one row per fact
#' as [read_xbrl()] gave them, and the panel is cut from it when asked for.
#'
#' It is an ordinary tibble, and everything that takes facts takes it.
#'
#' @section When the work still applies:
#' The work is per filing, so a subset of whole filings keeps it: `v[v$cvr ==
#' "12345678", ]` is still validated, for that company. Each filing's facts are
#' fingerprinted -- the number of rows and the sum of the values -- and a
#' filing whose facts no longer match is not trusted: change a value, or drop
#' some of a filing's rows, and the functions do the work again from the facts
#' as they stand. Nothing stale is read, and nothing has to be remembered.
#'
#' Standardising compares a filing with the company's later filings, and that
#' comparison was made on everything validated together. A subset keeps its
#' corrections, which were made with more information than the subset has.
#'
#' @param x A tibble from [read_xbrl()].
#'
#' @return `x`, standardised by [xbrl_standardise()], of class
#'   `cvrr_validated`, with the work in `attr(v, "validated")`: `company`
#'   ([xbrl_company()] without prose), `statement`, `cascade` and `cashflow`
#'   (the checks), `lines` (from [xbrl_lines()], by basis and statement) and
#'   the fingerprints.
#'
#' @seealso [xbrl_standardise()], [xbrl_screen()], [xbrl_panel()],
#'   [xbrl_report_data()].
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @export
xbrl_validate <- function(x) {
  need <- c("file", "cvr", "elementid", "value", "period", "period_end", "basis",
            "statement")
  gone <- setdiff(need, names(x))
  if (length(gone))
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} comes from {.fn read_xbrl}, with the taxonomy on it."))

  n <- length(unique(x$file))
  cli::cli_alert_info("Validating {n} filing{?s}.")
  if (!"standardised" %in% names(x)) x <- suppressMessages(xbrl_standardise(x))
  attr(x, "validated") <- NULL

  bases <- c("parent", "consolidated")
  d <- x[x$basis %in% bases, , drop = FALSE]
  work <- list(
    company = suppressMessages(xbrl_company(x, prose = FALSE)),
    statement = suppressMessages(check_statement(
      d[d$statement %in% .BALANCE_STATEMENTS, , drop = FALSE])),
    cascade = suppressWarnings(suppressMessages(check_cascade(d))),
    cashflow = check_cashflow(d))
  work$lines <- lapply(stats::setNames(bases, bases), function(b)
    lapply(c(income = "income", balance = "balance", cashflow = "cashflow"),
           function(s) tryCatch(suppressMessages(xbrl_lines(x, s, basis = b)),
                                error = function(e) NULL)))
  work$fingerprint <- .fingerprint(x)

  attr(x, "validated") <- work
  if (!inherits(x, "cvrr_validated")) class(x) <- c("cvrr_validated", class(x))
  log <- attr(x, "standardisation")
  fixed <- if (is.null(log)) 0L else
    sum(log$action %in% c("corrected comparative", "flipped sign"))
  cli::cli_alert_success("{n} filing{?s} validated, {fixed} figure{?s} corrected.")
  x
}

# Rows and the sum of the values, per filing: cheap to take, and changed by
# anything that would change what the work found.
.fingerprint <- function(x) {
  v <- x$value
  v[is.na(v)] <- 0
  r <- rowsum(cbind(1, v), x$file, reorder = FALSE)
  list(n = stats::setNames(r[, 1], rownames(r)),
       sum = stats::setNames(r[, 2], rownames(r)))
}

# The work attached to `x`, cut to the filings `x` holds -- or NULL where
# there is none, or where any filing's facts no longer match what was
# validated.
.validated <- function(x) {
  w <- attr(x, "validated")
  if (is.null(w) || !"file" %in% names(x) || !nrow(x)) return(NULL)
  fp <- .fingerprint(x)
  f <- names(fp$n)
  if (!all(f %in% names(w$fingerprint$n))) return(NULL)
  s0 <- w$fingerprint$sum[f]
  if (any(fp$n != w$fingerprint$n[f]) ||
      any(abs(fp$sum - s0) > 1e-9 * pmax(1, abs(s0)))) return(NULL)

  cut <- function(t) if (is.null(t) || !nrow(t) || !"file" %in% names(t)) t else
    t[t$file %in% f, , drop = FALSE]
  w$company <- cut(w$company)
  w$statement <- cut(w$statement)
  w$cascade <- cut(w$cascade)
  w$cashflow <- cut(w$cashflow)
  w$lines <- lapply(w$lines, function(b) lapply(b, cut))
  w
}

# The same work, for the bases asked for: a check's rows for other bases are
# rows the caller did not ask about.
.validated_basis <- function(w, basis) {
  keep <- function(t) if (is.null(t) || !nrow(t) || !"basis" %in% names(t)) t else
    t[t$basis %in% basis, , drop = FALSE]
  w$statement <- keep(w$statement)
  w$cascade <- keep(w$cascade)
  w$cashflow <- keep(w$cashflow)
  w
}

#' @export
print.cvrr_validated <- function(x, ...) {
  ok <- !is.null(.validated(x))
  head <- sprintf("%s filings  ·  %s",
                  format(length(unique(x$file)), big.mark = ","),
                  if (ok) "validated" else "changed since validation")
  cat(cli::rule(left = cli::style_bold("cvrr facts"), right = head), "\n", sep = "")
  NextMethod()
}
