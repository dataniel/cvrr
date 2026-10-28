#' What a report on these filings would say, as data
#'
#' Runs the pipeline -- standardise, screen, panel, ratios, robustness -- on
#' the filings given and gathers what a reader should know into one object:
#' tables, and a short list of findings written out as sentences. It is the
#' content of a report without its form, so that [xbrl_report()] can render
#' it and anyone can build a report of their own from the same parts.
#'
#' @section Which report:
#' The data decides, unless `type` does:
#'
#' * `"filing"` -- one company, one year: who it is, its figures, what the
#'   checks and the auditor found, how robust it is.
#' * `"company"` -- one company over several years: the same, as a time
#'   series, and what changed since the year before.
#' * `"cross_section"` -- many companies, one year: what they look like
#'   together, how many show each sign of vulnerability, and which most.
#' * `"panel"` -- many companies over several years: the same, year by year.
#'
#' @section Peers:
#' A company's ratios mean more beside comparable companies'. Pass a panel of
#' them as `peers` -- the rest of a corpus, say -- and each company is ranked
#' among the companies of its `group` the same year. Without peers there is
#' nothing to rank against, and the report says nothing about rank rather
#' than rank a company against itself.
#'
#' @param x A tibble from [read_xbrl()], or from [xbrl_validate()] -- which
#'   is the way to make several reports on the same filings without
#'   validating them for each.
#' @param cvr CVR numbers to report on. `NULL`, the default, reports on every
#'   company in `x`.
#' @param type `"filing"`, `"company"`, `"cross_section"` or `"panel"`; `NULL`
#'   decides from the data.
#' @param peers A panel from [xbrl_panel()] to rank against, or `NULL`.
#' @param group Columns that make companies comparable. Default `"class"`;
#'   see [xbrl_ratios()].
#' @param lang `"da"` (default) or `"en"`, for the sentences.
#'
#' @return A list of class `cvrr_report_data`: `type`, `meta`, `highlights`
#'   (character), and the tables the type has -- for one company `profile`,
#'   `figures`, `ratios`, `robustness`, `findings` and `technical`; for many
#'   `composition`, `distribution`, `robustness`, `vulnerable`, `findings`
#'   and `technical`. `panel` is the robustness panel it was all read from.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' d <- xbrl_report_data(x, cvr = "12345678", peers = xbrl_panel(x))
#' d$highlights
#' xbrl_report(d, "12345678.html")
#'
#' # the whole corpus
#' xbrl_report(xbrl_report_data(x), "corpus.html")
#' }
#'
#' @seealso [xbrl_report()] to render it, and [xbrl_screen()],
#'   [xbrl_panel()], [xbrl_ratios()], [xbrl_robustness()] for the parts.
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_info
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble tibble
#' @importFrom stats median quantile
#' @export
xbrl_report_data <- function(x, cvr = NULL, type = NULL, peers = NULL,
                             group = "class", lang = c("da", "en")) {
  lang <- match.arg(lang)
  if (!"elementid" %in% names(x))
    cli::cli_abort(c("{.arg x} must be the facts from {.fn read_xbrl}.",
                     "i" = "The report screens the filings as well as their figures."))
  if (!is.null(cvr)) {
    cvr <- as.character(cvr)
    x <- x[x$cvr %in% cvr, , drop = FALSE]
    if (!nrow(x))
      cli::cli_abort("No filing in {.arg x} for {.val {cvr}}.")
  }
  cvrs <- unique(x$cvr)

  # Validated once, here or before: the screen and the panel both read it.
  xs <- if (is.null(.validated(x))) suppressMessages(xbrl_validate(x)) else x
  sc <- suppressMessages(xbrl_screen(xs))
  # Both bases: a group's report is about the group, and its consolidated
  # figures are only there if they are asked for.
  p <- suppressMessages(xbrl_panel(xs, basis = c("parent", "consolidated")))

  # Ranked among peers where there are any: the companies themselves, and the
  # peers that are not them.
  base <- p
  if (!is.null(peers)) {
    other <- peers[!peers$cvr %in% cvrs, , drop = FALSE]
    base <- tibble::as_tibble(data.table::rbindlist(list(p, other), fill = TRUE))
    class(base) <- class(p)
  }
  r <- xbrl_robustness(base, group = group)
  validation <- attr(r, "validation")
  r <- r[r$cvr %in% cvrs, , drop = FALSE]
  r <- r[order(r$cvr, r$period_end), , drop = FALSE]
  if (!"basis" %in% names(r)) r$basis <- "parent"

  type <- type %||% .report_type(r)
  type <- match.arg(type, c("filing", "company", "cross_section", "panel"))
  tr <- .report_words(lang)

  meta <- list(
    type = type, lang = lang, companies = length(unique(r$cvr)),
    filings = length(unique(r$file)),
    years = if (nrow(r)) range(r$period_end) else as.Date(c(NA, NA)),
    peers = !is.null(peers), group = group, made = Sys.Date())

  out <- if (type %in% c("filing", "company"))
    .report_company(r, sc, tr, has_peers = !is.null(peers))
  else
    .report_population(r, sc, tr)
  out$technical <- attr(sc, "technical")
  out$validation <- validation
  out$panel <- r
  out <- c(list(type = type, meta = meta), out)
  class(out) <- "cvrr_report_data"
  out
}

# One company in one year, one company over time, many in one year, many
# over time.
.report_type <- function(r) {
  r <- r[r$basis %in% "parent" | !duplicated(r$file), , drop = FALSE]
  nc <- length(unique(r$cvr))
  ny <- length(unique(format(r$period_end, "%Y")))
  if (nc <= 1) return(if (nrow(r) <= 1) "filing" else "company")
  if (ny <= 1) "cross_section" else "panel"
}

# ---- one company --------------------------------------------------------------

.report_company <- function(r, sc, tr, has_peers) {
  # A group's own accounts where the latest filing has them: the group is what
  # a reader of a group's report is asking about, and its findings are there.
  latest <- r$period_end == max(r$period_end)
  b <- if (any(r$basis[latest] == "consolidated")) "consolidated" else "parent"
  r <- r[r$basis == b, , drop = FALSE]
  if (!nrow(r)) return(NULL)
  last <- r[nrow(r), , drop = FALSE]
  prev <- if (nrow(r) > 1) r[nrow(r) - 1, , drop = FALSE] else NULL

  profile <- tibble::tibble(
    item = tr[c("name", "cvr", "period", "form", "class", "employees",
                "founded", "assurance", "opinion", "group")],
    value = c(last$name, last$cvr,
              paste(format(last$period_start), "-", format(last$period_end)),
              last$form %||% NA, last$class %||% NA,
              .fmt_num(last$employees, tr), format(last$founded),
              .value_words(last$assurance, tr), .value_words(last$opinion_kind, tr),
              if (isTRUE(last$group_accounts)) tr[["group_accounts"]]
              else if (isTRUE(last$in_group)) tr[["in_group"]] else tr[["no"]]))

  yr <- format(r$period_end, "%Y")
  pick <- function(cols) {
    cols <- intersect(cols, names(r))
    d <- as.data.frame(r[cols])
    rownames(d) <- NULL
    tibble::as_tibble(cbind(year = yr, d))
  }
  figures <- pick(c("revenue", "gross_profit", "staff_costs", "depreciation",
                    "operating_profit", "net_financials", "tax", "profit",
                    "assets", "equity", "longterm_debt", "shortterm_debt",
                    "cash", "employees"))
  ratio_cols <- c("equity_ratio", "operating_return", "return_on_assets",
                  "return_on_equity", "current_ratio", "staff_share",
                  "gross_profit_growth", "equity_ratio_change")
  if (has_peers) ratio_cols <- c(ratio_cols, "equity_ratio_pct",
                                 "operating_return_pct", "current_ratio_pct")
  ratios <- pick(ratio_cols)
  robustness <- pick(c(.ROBUSTNESS_FACTORS, "n_factors", "gross_profit_buffer",
                       "cash_months"))

  f <- sc[sc$cvr %in% last$cvr, , drop = FALSE]
  findings <- if (nrow(f)) tibble::as_tibble(as.data.frame(
    f[c("period_end", "check", "finding", "severity", "share", "detail")]))
    else NULL
  if (!is.null(findings)) {
    findings$finding <- .finding_words(findings$finding, tr)
    findings$check <- .value_words(findings$check, tr)
    findings$severity <- .value_words(findings$severity, tr)
  }

  list(profile = profile, figures = figures, ratios = ratios,
       robustness = robustness, findings = findings,
       highlights = .company_highlights(last, prev, f, tr, has_peers))
}

# What a reader should know first, as sentences. Each rule is a threshold on
# one figure, and a rule with nothing to say says nothing.
.company_highlights <- function(last, prev, f, tr, has_peers) {
  h <- character()
  add <- function(s) h <<- c(h, s)
  pc <- function(v) .fmt_pct(v, tr)
  num <- function(v) .fmt_num(v, tr)

  # What the auditor said comes first: it is the one judgement made with the
  # books open.
  ok <- last$opinion_kind %||% NA
  if (!is.na(ok) && ok != "clean") add(sprintf(tr[["h_opinion"]], tr[[paste0("op_", ok)]]))
  if (isTRUE(last$going_concern)) add(tr[["h_going"]])

  hi <- f[f$severity %in% "high" & f$period_end %in% last$period_end, , drop = FALSE]
  hi <- hi[hi$check != "auditor", , drop = FALSE]
  if (nrow(hi)) {
    what <- paste(unique(.finding_words(hi$finding, tr)), collapse = "; ")
    add(if (nrow(hi) == 1) sprintf(tr[["h_finding1"]], what)
        else sprintf(tr[["h_findings"]], nrow(hi), what))
  }

  if (!is.na(last$profit) && last$profit < 0)
    add(sprintf(if (isTRUE(last$two_losses)) tr[["h_loss2"]] else tr[["h_loss"]],
                num(-last$profit)))
  if (isTRUE(last$negative_equity)) add(sprintf(tr[["h_negeq"]], num(last$equity)))
  else if (isTRUE(last$capital_lost)) add(tr[["h_caplost"]])

  if (!is.null(prev) && !is.na(last$equity_ratio_change) &&
      abs(last$equity_ratio_change) >= 0.05)
    add(sprintf(if (last$equity_ratio_change < 0) tr[["h_eq_down"]] else tr[["h_eq_up"]],
                pc(prev$equity_ratio), pc(last$equity_ratio)))
  if (!is.na(last$gross_profit_growth) && abs(last$gross_profit_growth) >= 0.10)
    add(sprintf(if (last$gross_profit_growth < 0) tr[["h_gp_down"]] else tr[["h_gp_up"]],
                pc(abs(last$gross_profit_growth))))
  if (!is.na(last$gross_profit_buffer) && last$gross_profit_buffer < 0.10)
    add(sprintf(tr[["h_buffer"]], pc(last$gross_profit_buffer)))
  if (!is.na(last$operating_profit) && last$operating_profit < 0)
    add(tr[["h_oploss"]])
  if (!is.na(last$cash_months) && last$cash_months < 1)
    add(sprintf(tr[["h_cash"]], .fmt_num(last$cash_months, tr, 1)))
  if (has_peers && !is.na(last$equity_ratio_pct %||% NA) && last$equity_ratio_pct < 10)
    add(tr[["h_peer_eq"]])
  if (has_peers && !is.na(last$operating_return_pct %||% NA) && last$operating_return_pct < 10)
    add(tr[["h_peer_ret"]])
  if (last$n_factors >= 3) add(sprintf(tr[["h_factors"]], last$n_factors))
  if (!length(h)) h <- tr[["h_none"]]
  h
}

# ---- many companies ----------------------------------------------------------

.report_population <- function(r, sc, tr) {
  r <- r[r$basis %in% "parent", , drop = FALSE]
  yr <- format(r$period_end, "%Y")
  # The latest year that is complete, not merely the latest: annual reports
  # arrive through the year after, and a year with a twentieth of the usual
  # filings in it describes the companies that file early. Half the busiest
  # year's count is enough to call a year complete.
  per_year <- table(yr)
  full <- names(per_year)[per_year >= 0.5 * max(per_year)]
  last_yr <- max(full)
  now <- r[yr == last_yr, , drop = FALSE]

  tab <- function(v) {
    t <- sort(table(v, useNA = "ifany"), decreasing = TRUE)
    tibble::tibble(value = ifelse(is.na(names(t)), "-", names(t)), n = as.integer(t))
  }
  composition <- list(class = tab(now$class), form = tab(now$form),
                      assurance = tab(now$assurance))

  q <- function(v) {
    v <- v[!is.na(v)]
    if (!length(v)) return(c(NA, NA, NA))
    stats::quantile(v, c(0.25, 0.5, 0.75), names = FALSE)
  }
  vars <- c("equity_ratio", "operating_return", "return_on_assets",
            "current_ratio", "gross_profit_growth")
  distribution <- do.call(rbind, lapply(sort(unique(yr)), function(y) {
    d <- r[yr == y, , drop = FALSE]
    do.call(rbind, lapply(vars, function(v) {
      qq <- q(d[[v]])
      tibble::tibble(year = y, ratio = v, n = sum(!is.na(d[[v]])),
                     q1 = qq[1], median = qq[2], q3 = qq[3])
    }))
  }))

  robustness <- do.call(rbind, lapply(sort(unique(yr)), function(y) {
    d <- r[yr == y, , drop = FALSE]
    shares <- vapply(.ROBUSTNESS_FACTORS, function(f) mean(d[[f]], na.rm = TRUE),
                     numeric(1))
    tibble::as_tibble(c(list(year = y, companies = nrow(d),
                             three_or_more = mean(d$n_factors >= 3)),
                        as.list(shares)))
  }))

  vulnerable <- now[order(-now$n_factors, now$equity_ratio), , drop = FALSE]
  vulnerable <- utils::head(vulnerable[vulnerable$n_factors >= 3, , drop = FALSE], 25)
  vulnerable <- tibble::as_tibble(as.data.frame(vulnerable[intersect(
    c("cvr", "name", "class", "n_factors", "equity_ratio", "operating_return",
      "cash_months"), names(vulnerable))]))

  s <- sc[!duplicated(sc$file), , drop = FALSE]
  findings <- if (nrow(sc)) tibble::as_tibble(as.data.frame(
    utils::head(s[c("cvr", "name", "period_end", "check", "finding", "severity",
                    "share")], 25))) else NULL
  if (!is.null(findings)) {
    findings$finding <- .finding_words(findings$finding, tr)
    findings$check <- .value_words(findings$check, tr)
    findings$severity <- .value_words(findings$severity, tr)
  }

  # The population's own highlights.
  h <- character()
  n <- nrow(now)
  cnt <- function(f) sum(now[[f]] %in% TRUE)
  h <- c(h, sprintf(tr[["p_count"]], length(unique(r$cvr)), length(unique(r$file)),
                    min(yr), max(yr)))
  if (cnt("negative_equity"))
    h <- c(h, sprintf(tr[["p_negeq"]], cnt("negative_equity"), n,
                      .fmt_pct(cnt("negative_equity") / n, tr), last_yr))
  h <- c(h, sprintf(tr[["p_three"]], sum(now$n_factors >= 3), .fmt_pct(mean(now$n_factors >= 3), tr)))
  if (length(full) > 1) {
    m <- tapply(r$equity_ratio[yr %in% full], yr[yr %in% full], stats::median,
                na.rm = TRUE)
    h <- c(h, sprintf(tr[["p_eq_trend"]], .fmt_pct(m[1], tr), names(m)[1],
                      .fmt_pct(m[length(m)], tr), names(m)[length(m)]))
  }
  op <- sum(sc$check == "auditor" & sc$severity == "high")
  if (op) h <- c(h, sprintf(tr[["p_opinion"]], op))
  hi <- length(unique(sc$file[sc$severity == "high" & sc$check != "auditor"]))
  if (hi) h <- c(h, sprintf(tr[["p_findings"]], hi))

  list(composition = composition, distribution = distribution,
       robustness = robustness, vulnerable = vulnerable, findings = findings,
       highlights = h)
}

#' @export
print.cvrr_report_data <- function(x, ...) {
  m <- x$meta
  yrs <- paste(unique(format(m$years, "%Y")), collapse = "-")
  cat(cli::rule(left = cli::style_bold(paste("cvrr report:", x$type)),
                right = sprintf("%d compan%s  ·  %s", m$companies,
                                if (m$companies == 1) "y" else "ies", yrs)),
      "\n", sep = "")
  for (s in x$highlights) cat("  • ", s, "\n", sep = "")
  tabs <- setdiff(names(x), c("type", "meta", "highlights", "panel", "validation"))
  cat("  ", cli::col_grey(paste("Tables:", paste(tabs, collapse = ", "))), "\n", sep = "")
  invisible(x)
}

# ---- numbers and words ---------------------------------------------------------

# The assurance and the opinion, in the report's language.
.value_words <- function(v, tr) {
  if (is.null(v) || length(v) == 0) return(NA_character_)
  if (identical(tr[["dec"]], ".")) return(v)
  da <- c(audit = "revision", "extended review" = "udvidet gennemgang",
          review = "review", compilation = "assistance (uden sikkerhed)",
          none = "ingen", clean = "uden forbehold", qualified = "med forbehold",
          adverse = "afkræftende", disclaimer = "ingen konklusion",
          auditor = "revisor", "balance sheet" = "balance",
          "income statement" = "resultatopgørelse", "cash flow" = "pengestrøm",
          "between filings" = "mellem årsrapporter",
          high = "alvorlig", medium = "middel", low = "lav")
  ifelse(!is.na(v) & v %in% names(da), da[v], v)
}

# A finding's name, in the report's language.
.finding_words <- function(finding, tr) {
  if (identical(tr[["dec"]], ".")) return(finding)
  da <- c("sides differ" = "balancens sider er forskellige",
          "a line stated with two amounts" = "en linje er oplyst med to beløb",
          "step unsolved" = "et trin i resultatopgørelsen går ikke op",
          "step unexplained" = "et trin i resultatopgørelsen er uforklaret",
          "activities differs" = "aktiviteterne summer ikke til ændringen i likvider",
          "rollforward differs" = "likviderne ruller ikke frem",
          "cash vs balance differs" = "pengestrømmens likvider er ikke balancens",
          "borrowed more than owed" = "der er lånt mere, end balancen skylder",
          "written in the other unit" = "et tal er skrevet i forkert enhed",
          "restated" = "en balancepost er ændret mellem to årsrapporter",
          "qualified opinion" = "konklusion med forbehold",
          "adverse opinion" = "afkræftende konklusion", "no opinion" = "ingen konklusion",
          "going concern uncertainty" = "usikkerhed om fortsat drift")
  ifelse(finding %in% names(da), da[finding], finding)
}

.fmt_num <- function(v, tr, digits = 0) {
  if (length(v) == 0 || is.na(v)) return("-")
  s <- formatC(v, format = "f", digits = digits, big.mark = tr[["big"]],
               decimal.mark = tr[["dec"]])
  sub("^-", "−", s)
}
.fmt_pct <- function(v, tr) {
  if (length(v) == 0 || is.na(v)) return("-")
  paste0(.fmt_num(100 * v, tr, 1), tr[["pct"]])
}

.report_words <- function(lang) {
  da <- c(
    big = ".", dec = ",", pct = " %",
    name = "Navn", cvr = "CVR", period = "Regnskabsperiode", form = "Virksomhedsform",
    class = "Regnskabsklasse", employees = "Ansatte", founded = "Stiftet",
    assurance = "Revisors bistand", opinion = "Revisors konklusion", group = "Koncern",
    group_accounts = "Koncernregnskab", in_group = "Del af en koncern", no = "Nej",
    op_qualified = "taget forbehold", op_adverse = "givet en afkræftende konklusion",
    op_disclaimer = "ikke kunnet give en konklusion",
    h_opinion = "Revisor har %s.",
    h_going = "Revisor eller selskabet oplyser væsentlig usikkerhed om fortsat drift.",
    h_findings = "Regnskabet har %d alvorlige fund i kontrollen: %s.",
    h_finding1 = "Regnskabet har et alvorligt fund i kontrollen: %s.",
    h_loss = "Årets resultat er et underskud på %s.",
    h_loss2 = "Årets resultat er et underskud på %s, for andet år i træk.",
    h_negeq = "Egenkapitalen er negativ (%s).",
    h_caplost = "Egenkapitalen er under halvdelen af selskabskapitalen (kapitaltab).",
    h_eq_down = "Soliditeten faldt fra %s til %s.",
    h_eq_up = "Soliditeten steg fra %s til %s.",
    h_gp_down = "Bruttofortjenesten faldt %s fra sidste år.",
    h_gp_up = "Bruttofortjenesten steg %s fra sidste år.",
    h_buffer = "Bruttofortjenesten kan kun falde %s, før driften giver underskud.",
    h_oploss = "Driften giver underskud før finansielle poster.",
    h_cash = "Likviderne dækker %s måneders løn.",
    h_peer_eq = "Soliditeten er blandt de laveste 10 % i sammenligningsgruppen.",
    h_peer_ret = "Afkastet af driften er blandt de laveste 10 % i sammenligningsgruppen.",
    h_factors = "Selskabet har %d af de kendte tegn på finansiel sårbarhed.",
    h_none = "Intet i regnskabet skiller sig ud.",
    p_count = "%d virksomheder og %d regnskaber, %s-%s.",
    p_negeq = "%d af %d virksomheder (%s) har negativ egenkapital i %s.",
    p_three = "%d virksomheder (%s) har tre eller flere tegn på sårbarhed i det seneste år.",
    p_eq_trend = "Den typiske soliditet gik fra %s i %s til %s i %s.",
    p_opinion = "%d regnskaber har en revisorkonklusion med forbehold, afkræftende eller ingen.",
    p_findings = "%d regnskaber har et alvorligt fund i kontrollen af tallene.")
  en <- c(
    big = ",", dec = ".", pct = "%",
    name = "Name", cvr = "CVR", period = "Accounting period", form = "Legal form",
    class = "Accounting class", employees = "Employees", founded = "Founded",
    assurance = "Auditor's involvement", opinion = "Auditor's opinion", group = "Group",
    group_accounts = "Group accounts", in_group = "Part of a group", no = "No",
    op_qualified = "qualified the opinion", op_adverse = "given an adverse opinion",
    op_disclaimer = "been unable to give an opinion",
    h_opinion = "The auditor has %s.",
    h_going = "The auditor or the company reports a material uncertainty about going concern.",
    h_findings = "The accounts have %d serious findings: %s.",
    h_finding1 = "The accounts have a serious finding: %s.",
    h_loss = "The year's result is a loss of %s.",
    h_loss2 = "The year's result is a loss of %s, the second in a row.",
    h_negeq = "Equity is negative (%s).",
    h_caplost = "Equity is under half the contributed capital.",
    h_eq_down = "The equity ratio fell from %s to %s.",
    h_eq_up = "The equity ratio rose from %s to %s.",
    h_gp_down = "The gross profit fell %s from last year.",
    h_gp_up = "The gross profit rose %s from last year.",
    h_buffer = "The gross profit can fall only %s before the operation makes a loss.",
    h_oploss = "The operation makes a loss before financial items.",
    h_cash = "Cash covers %s months of wages.",
    h_peer_eq = "The equity ratio is in the lowest 10% of the comparison group.",
    h_peer_ret = "The operating return is in the lowest 10% of the comparison group.",
    h_factors = "The company shows %d of the known signs of financial vulnerability.",
    h_none = "Nothing in the accounts stands out.",
    p_count = "%d companies and %d annual reports, %s-%s.",
    p_negeq = "%d of %d companies (%s) have negative equity in %s.",
    p_three = "%d companies (%s) show three or more signs of vulnerability in the latest year.",
    p_eq_trend = "The typical equity ratio went from %s in %s to %s in %s.",
    p_opinion = "%d annual reports have a qualified, adverse or missing audit opinion.",
    p_findings = "%d annual reports have a serious finding in the check of their figures.")
  as.list(if (lang == "da") da else en)
}
