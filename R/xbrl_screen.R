#' Screen a pile of filings for the ones worth reading
#'
#' Runs the package's checks over every filing in `x` and returns what they
#' found, one row per finding, ranked so that the filings worth a closer look
#' come first. It is the question to ask of a corpus before trusting it, or of
#' a company before reading its report: where does this not add up, and how
#' much does it matter?
#'
#' @section What it looks for:
#' Each finding comes from a check that can be run on its own, and `check`
#' names it:
#'
#' * `"auditor"` -- the auditor qualified the opinion, gave an adverse one or
#'   none at all, or drew attention to a material uncertainty about the
#'   company continuing as a going concern ([xbrl_company()]). The first three
#'   are an auditor saying the accounts are wrong or cannot be judged, and
#'   rank with the arithmetic; the last is a risk, not an error.
#' * `"balance sheet"` -- the debit side does not equal the credit side, or
#'   one line is stated twice with two amounts ([check_statement()]).
#' * `"income statement"` -- a step of the cascade that no assignment of
#'   signs explains ([check_cascade()]).
#' * `"cash flow"` -- the statement does not add up, does not roll the cash
#'   forward, or closes on a cash figure the balance sheet does not carry; or
#'   it reports borrowing the balance sheet does not owe, the pattern of a
#'   grant booked as a loan ([check_cashflow()]).
#' * `"between filings"` -- a balance that reopened on a different amount in
#'   the next filing ([check_continuity()]). Income statement comparatives are
#'   left out, because they are reclassified routinely. With
#'   `standardise = FALSE`, also a figure written in the other unit.
#'
#' @section The tagging first, the accounts second:
#' A figure tagged in thousands where the filing is in kroner is a fact about
#' the tagging, not about the company. Screened as it stands it outranks every
#' real finding: in a 4,304-filing corpus, 41 of the 54 serious findings were
#' that, and once the figures are standardised the 13 left are all cash flow
#' statements that do not add up. So by default the figures are standardised first, and the screen
#' looks at the accounts as they were meant. What was corrected, and what
#' could not be settled, is kept apart in `attr(s, "technical")` and named in
#' one line when the screen prints. `standardise = FALSE` screens the figures
#' as tagged, and then a figure in the other unit is a finding of its own.
#'
#' @section How it ranks:
#' By how much a finding would change what a reader takes from the accounts.
#' `share` is the amount against the filing's total assets, and `severity`
#' combines the kind of finding with its size:
#'
#' * `"high"` -- an auditor's qualified, adverse or missing opinion, or the
#'   statements do not hold together: a balance sheet whose
#'   sides differ, a cash flow statement that does not add up, or borrowing
#'   the balance sheet does not owe with its other half found elsewhere in the
#'   statement. Unstandardised, also a figure off by a factor of a thousand.
#' * `"medium"` -- a going concern uncertainty, or something is unexplained
#'   but the statements still close:
#'   borrowing without debt to match, an income statement step no signs
#'   explain, a line stated with two amounts.
#' * `"low"` -- a lead: a figure restated between filings.
#'
#' A finding under `materiality` of total assets moves down one level, so a
#' rounding difference on a large company does not sit above a real one on a
#' small company, and one that ends at `"low"` that way is left out. A
#' finding with no amount keeps its level.
#'
#' @section What it does not do:
#' A finding is a reason to read the report, not a conclusion about it. Every
#' one has an innocent explanation as well as a guilty one, and the checks
#' cannot tell them apart: a restatement can be a correction of policy or of an
#' error, borrowing without debt can be a facility drawn and repaid within the
#' year. The function says where to look.
#'
#' It does not look at the prose or at anything the filing did not tag. A misstatement that is consistent everywhere, scaled or
#' restated throughout, is invisible inside one filing and is found only
#' between filings, so pass several years to see that kind.
#'
#' @param x A tibble from [read_xbrl()]: any number of filings, any number of
#'   companies. Several years of the same company add the checks between
#'   filings. From [xbrl_validate()], the checks it ran are read rather than
#'   run again.
#' @param basis `"parent"` and `"consolidated"`, the default, screens both; a
#'   group's cash flow statement is usually only consolidated.
#' @param what Which checks to run: any of `"auditor"`, `"balance"`,
#'   `"income"`, `"cashflow"` and `"continuity"`. All of them by default.
#' @param materiality Share of total assets under which a finding moves down a
#'   level. Default `0.01`.
#' @param standardise Put the tagging right before screening, with
#'   [xbrl_standardise()]: figures in the wrong unit, and cash flow signs an
#'   activity adds up only reversed. Default `TRUE`. See the section below.
#'
#' @return A tibble with one row per finding, most severe and largest first:
#'   the key (`cvr`, `name`, `period_start`, `period_end`), `basis`, `check`,
#'   `finding`, `amount` (the gap in the reporting currency, where the check
#'   gives one), `share` (`amount` against total assets), `severity`, `detail`
#'   (what the check said, in its own words), the filing's background --
#'   `class`, `form`, `assurance`, `in_group`, `group_accounts`, from
#'   [xbrl_company()] -- and `file`. Filings with no
#'   finding have no rows; `attr(s, "screened")` says how many were looked at.
#'   It prints as one line per filing, its most serious finding first; the
#'   rows underneath are an ordinary tibble.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' s <- xbrl_screen(x)
#' s
#'
#' # the filings with something serious, one row each
#' s[s$severity == "high" & !duplicated(s$file), ]
#' }
#'
#' @seealso [xbrl_accounts()], whose `checks` table answers the same questions
#'   as yes or no; [check_statement()], [check_cascade()], [check_cashflow()]
#'   and [check_continuity()] for the detail behind a finding.
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
xbrl_screen <- function(x, basis = c("parent", "consolidated"),
                        what = c("auditor", "balance", "income", "cashflow",
                                 "continuity"),
                        materiality = 0.01, standardise = TRUE) {
  basis <- match.arg(basis, several.ok = TRUE)
  what <- match.arg(what, several.ok = TRUE)
  need <- c("file", "cvr", "elementid", "value", "period", "period_end", "basis")
  gone <- setdiff(need, names(x))
  if (length(gone))
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} comes from {.fn read_xbrl}, with the taxonomy on it."))

  n <- length(unique(x$file))
  cli::cli_alert_info("Screening {n} filing{?s}.")

  # The tagging first, the accounts second. A figure in the wrong unit is a
  # technicality, and screened as it stands it outranks every real finding:
  # 41 of the 54 serious findings in a 4,304-filing corpus were that.
  # Standardised first, the serious findings are 13, none of them the tagging.
  technical <- NULL
  if (isTRUE(standardise)) {
    if (!"standardised" %in% names(x)) x <- xbrl_standardise(x)
    technical <- attr(x, "standardisation")
    # A subset keeps the attribute of the whole; the log is about these filings.
    if (!is.null(technical) && nrow(technical))
      technical <- technical[technical$file %in% x$file, , drop = FALSE]
  }
  d <- x[x$basis %in% basis, , drop = FALSE]
  # Facts from xbrl_validate() carry the checks already run; read, not rerun.
  w <- .validated(x)
  if (!is.null(w)) w <- .validated_basis(w, basis)
  found <- list()
  # The checks' own output, kept for whoever goes on to build a panel of the
  # same facts: xbrl_panel() reads its trust columns off them instead of
  # running them again.
  checks <- list()

  # Who each filing is, for the auditor's findings and for the background
  # every finding carries: what is unusual for an audited group is ordinary
  # for a micro company nobody audits.
  comp <- w$company %||% suppressMessages(xbrl_company(x, prose = FALSE))
  checks$company <- comp
  if ("auditor" %in% what && nrow(comp)) {
    op <- comp[comp$opinion_kind %in% c("qualified", "adverse", "disclaimer"), ]
    found$opinion <- .finding(op, "auditor",
      c(qualified = "qualified opinion", adverse = "adverse opinion",
        disclaimer = "no opinion")[op$opinion_kind],
      NA_real_, "high", op$opinion)
    gc <- comp[comp$going_concern %in% TRUE, ]
    found$going <- .finding(gc, "auditor", "going concern uncertainty",
                            NA_real_, "medium",
                            "material uncertainty about the company continuing")
  }

  if ("balance" %in% what) {
    st <- w$statement %||% suppressMessages(check_statement(
      d[d$statement %in% .BALANCE_STATEMENTS, , drop = FALSE]))
    checks$statement <- st
    if (nrow(st)) {
      sides <- st[st$verdict %in% "sides differ", , drop = FALSE]
      found$sides <- .finding(sides, "balance sheet", "sides differ",
                              sides$residual, "high",
                              sprintf("debit %s, credit %s", .num(sides$total),
                                      .num(sides$specified)))
      dup <- st[st$verdict %in% "conflicting duplicates", , drop = FALSE]
      dup <- dup[!duplicated(dup[c("file", "basis")]), , drop = FALSE]
      found$dup <- .finding(dup, "balance sheet", "a line stated with two amounts",
                            NA_real_, "medium", paste("under", dup$label))
    }
  }

  if ("income" %in% what) {
    cs <- w$cascade %||% suppressWarnings(suppressMessages(check_cascade(d)))
    checks$cascade <- cs
    if (nrow(cs)) {
      bad <- cs[cs$status %in% c("unsolved", "unexplained"), , drop = FALSE]
      found$income <- .finding(bad, "income statement",
                               paste("step", bad$status), NA_real_, "medium",
                               paste("to", bad$target))
    }
  }

  if ("cashflow" %in% what) {
    cf <- w$cashflow %||% check_cashflow(d)
    checks$cashflow <- cf
    if (nrow(cf)) {
      internal <- cf[cf$check %in% c("activities", "rollforward",
                                     "cash vs balance") &
                       cf$verdict %in% "differs", , drop = FALSE]
      found$cf <- .finding(internal, "cash flow",
                           paste(internal$check, "differs"), internal$residual,
                           "high", NA_character_)
      debt <- cf[cf$verdict %in% "borrowed more than owed", , drop = FALSE]
      found$debt <- .finding(debt, "cash flow", "borrowed more than owed",
                             debt$residual,
                             ifelse(is.na(debt$offset_by), "medium", "high"),
                             ifelse(is.na(debt$offset_by),
                                    sprintf("borrowed %s, debt moved %s",
                                            .num(debt$reported), .num(debt$expected)),
                                    paste("other half:", debt$offset_by)))
    }
  }

  if ("continuity" %in% what && "instant" %in% names(d) &&
      any(duplicated(unique(d[c("cvr", "period_end")])$cvr))) {
    found$cont <- .continuity_findings(d, units = !isTRUE(standardise))
  }

  out <- data.table::rbindlist(found, fill = TRUE)
  if (!nrow(out)) {
    cli::cli_alert_success("No findings in {n} filing{?s}.")
    out <- .empty_screen()
  } else {
    out <- as.data.frame(out)
    assets <- .total_assets(x)
    out$share <- abs(out$amount) / assets[paste(out$file, out$basis)]
    small <- !is.na(out$share) & out$share < materiality
    out$severity[small] <- c(high = "medium", medium = "low", low = "low")[out$severity[small]]
    # A lead too small to matter is not a lead.
    out <- out[!(small & out$severity == "low"), , drop = FALSE]
    rank <- match(out$severity, c("high", "medium", "low"))
    out <- out[order(rank, -ifelse(is.na(out$share), 0, out$share)), , drop = FALSE]
    key <- unique(x[c("file", "cvr", "period_start", "period_end")])
    key <- key[!duplicated(key$file), , drop = FALSE]
    i <- match(out$file, key$file)
    out$cvr <- key$cvr[i]
    out$period_start <- key$period_start[i]
    out$period_end <- key$period_end[i]
    nm <- .filing_names(x)
    out$name <- unname(nm[out$file])
    # The background, from the company row: for filtering and for comparing
    # like with like.
    j <- match(out$file, comp$file)
    for (col in c("class", "form", "assurance", "in_group", "group_accounts"))
      out[[col]] <- if (col %in% names(comp)) comp[[col]][j] else NA
    out <- .key_first(tibble::as_tibble(out))
    hit <- length(unique(out$file))
    cli::cli_alert_success(
      "{nrow(out)} finding{?s} in {hit} of {n} filing{?s}, {sum(out$severity == 'high')} high.")
  }
  attr(out, "screened") <- n
  attr(out, "technical") <- technical
  attr(out, "checks") <- checks
  class(out) <- c("cvrr_screen", class(out))
  out
}

#' @export
print.cvrr_screen <- function(x, n = 10, ...) {
  need <- c("file", "severity", "finding", "share", "cvr", "name", "period_end")
  # A subset that lost the columns, or the class's attributes, is just a table.
  if (!all(need %in% names(x)) || is.null(attr(x, "screened")))
    return(invisible(NextMethod()))

  sev <- c("high", "medium", "low")
  files <- unique(x$file)
  n_sev <- vapply(sev, function(s) length(unique(x$file[x$severity == s])),
                  integer(1))
  head <- sprintf("%s screened  ·  %s with a finding",
                  format(attr(x, "screened"), big.mark = ","),
                  format(length(files), big.mark = ","))
  # cli::rule() rather than cli_rule(): a print method writes to stdout.
  cat(cli::rule(left = cli::style_bold("cvrr screen"), right = head), "\n",
      sep = "")
  if (!length(files)) {
    .print_technical(attr(x, "technical"))
    return(invisible(x))
  }
  cat("  ", paste(sprintf("%s %s", format(n_sev, big.mark = ","), sev),
                  collapse = "  ·  "),
      cli::col_grey("  (filings, by their most serious finding)"), "\n\n",
      sep = "")

  # One line per filing, its most serious finding first -- the rows are
  # already in that order, so the first row of each filing is it.
  first <- x[!duplicated(x$file), , drop = FALSE]
  count <- table(x$file)[first$file]
  show <- utils::head(first, n)
  who <- sprintf("%s %s", show$cvr, format(show$period_end, "%Y"))
  nm <- ifelse(is.na(show$name), "", substr(show$name, 1, 30))
  pct <- ifelse(is.na(show$share), "", sprintf("%.1f%%", 100 * show$share))
  more <- ifelse(count[seq_len(nrow(show))] > 1,
                 sprintf("+%d", count[seq_len(nrow(show))] - 1), "")
  colour <- c(high = cli::col_red, medium = cli::col_yellow, low = cli::col_grey)
  # Padded before it is coloured: ANSI codes count as characters to formatC.
  for (i in seq_len(nrow(show))) {
    tag <- colour[[show$severity[i]]](formatC(show$severity[i], width = -6))
    cat("  ", tag, " ", formatC(who[i], width = -14), " ",
        formatC(nm[i], width = -30), " ", formatC(show$finding[i], width = -26),
        " ", formatC(pct[i], width = 7), " ", cli::col_grey(more[i]), "\n",
        sep = "")
  }
  if (nrow(first) > n)
    cat("  ", cli::col_grey(sprintf("... and %s more filings",
                                   format(nrow(first) - n, big.mark = ","))),
        "\n", sep = "")
  cat("  ", cli::col_grey("Every finding is a row: as.data.frame(x), or filter on severity."),
      "\n", sep = "")
  .print_technical(attr(x, "technical"))
  invisible(x)
}

# The tagging, said once and apart from the findings.
.print_technical <- function(t) {
  if (is.null(t) || !nrow(t)) return(invisible(NULL))
  units <- sum(t$kind == "unit" & t$action != "undecided")
  signs <- sum(t$kind == "sign" & t$action != "undecided")
  open <- sum(t$action == "undecided")
  cat("  ", cli::col_grey(sprintf(
    "Before screening: %d figure%s put back in the right unit, %d sign%s reversed, %d left undecided -- attr(x, \"technical\")",
    units, if (units == 1) "" else "s", signs, if (signs == 1) "" else "s", open)),
    "\n", sep = "")
  invisible(NULL)
}

# One row per finding, in the screen's own columns, from any check's rows.
# Only the file and the basis are taken from the check: not every check
# carries the key, and the key is the filing's, so it is looked up once at
# the end.
.finding <- function(r, check, finding, amount, severity, detail) {
  if (is.null(r) || !nrow(r)) return(NULL)
  k <- nrow(r)
  data.frame(
    file = r$file, basis = if ("basis" %in% names(r)) r$basis else NA_character_,
    check = check, finding = rep_len(finding, k), amount = rep_len(amount, k),
    severity = rep_len(severity, k), detail = rep_len(detail, k),
    stringsAsFactors = FALSE)
}

# Between filings: a figure that does not reopen where it closed. Scaled is a
# figure written in the other unit, and is always worth reading; a change is
# a restatement, and the filing is flagged once, with how much of it moved.
.continuity_findings <- function(d, units = TRUE) {
  keep <- d$is_line %in% TRUE & !is.na(d$value)
  cc <- suppressMessages(check_continuity(d[keep, , drop = FALSE], by = "cvr",
                                          filing = "period_end"))
  if (!nrow(cc)) return(NULL)
  # A figure stated twice belongs to the later filing: it is the one that
  # reopened on something else.
  files <- unique(d[c("cvr", "period_end", "period_start", "file", "basis")])
  files <- files[!duplicated(files[c("cvr", "period_end")]), , drop = FALSE]
  i <- match(paste(cc$cvr, cc$opened_in), paste(files$cvr, files$period_end))
  cc$file <- files$file[i]
  cc$basis <- files$basis[i]
  cc <- cc[!is.na(cc$file), , drop = FALSE]

  # After standardising, what is still in the other unit is a figure no third
  # figure could settle. That is a question about the tagging, listed with the
  # corrections, not a finding about the accounts.
  scaled <- cc[cc$verdict %in% "scaled" & units, , drop = FALSE]
  scaled <- scaled[order(-abs(scaled$diff)), , drop = FALSE]
  scaled <- scaled[!duplicated(scaled$file), , drop = FALSE]
  f1 <- .finding(scaled, "between filings", "written in the other unit",
                 scaled$diff, "high",
                 sprintf("%s: %s, then %s", scaled$elementid, .num(scaled$closing),
                         .num(scaled$opening)))

  # A balance that does not reopen where it closed, not a comparative that
  # moved. Income statement comparatives are reclassified routinely -- staff
  # costs alone were the largest change in 91 restated filings of a
  # 4,304-filing corpus -- and a balance sheet that changes between closing
  # and reopening is the break that matters. A duration's period is written
  # as its two dates, an instant's as one.
  moved <- cc[cc$verdict %in% "differs" & !grepl(" ", cc$period, fixed = TRUE), ,
              drop = FALSE]
  if (!nrow(moved)) return(f1)
  by_file <- split(seq_len(nrow(moved)), moved$file)
  n_all <- table(cc$file)
  big <- vapply(by_file, function(j) j[which.max(abs(moved$diff[j]))], integer(1))
  r <- moved[big, , drop = FALSE]
  share_moved <- lengths(by_file) / as.numeric(n_all[names(by_file)])
  f2 <- .finding(r, "between filings", "restated", r$diff, "low",
                 sprintf("%d of %d figures differ; largest %s", lengths(by_file),
                         as.integer(n_all[names(by_file)]), r$elementid))
  f2$detail <- ifelse(share_moved > 0.5, paste(f2$detail, "(most of the filing)"),
                      f2$detail)
  rbind(f1, f2)
}

# Total assets per filing and basis, the yardstick for every finding.
.total_assets <- function(x) {
  a <- x[x$elementid %in% c("Assets", "LiabilitiesAndEquity") & !is.na(x$value) &
           x$is_line %in% TRUE & !is.na(x$period) & !is.na(x$period_end) &
           x$period == x$period_end, , drop = FALSE]
  a <- a[order(a$elementid), , drop = FALSE]    # Assets before the other side
  a <- a[!duplicated(paste(a$file, a$basis)), , drop = FALSE]
  stats::setNames(abs(a$value), paste(a$file, a$basis))
}

.num <- function(v) format(round(v), big.mark = ",", scientific = FALSE, trim = TRUE)

.empty_screen <- function()
  .key_first(tibble::tibble(
    file = character(), cvr = character(), name = character(),
    period_start = as.Date(character()), period_end = as.Date(character()),
    basis = character(), check = character(), finding = character(),
    amount = numeric(), share = numeric(), severity = character(),
    detail = character()))
