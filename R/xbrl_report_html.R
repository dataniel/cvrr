#' Write a report on the filings as one HTML page
#'
#' Renders what [xbrl_report_data()] gathered: the findings in sentences
#' first, then the tables behind them. The page is a single self-contained
#' file with no scripts, fonts or images to fetch, so it can be mailed,
#' archived or opened anywhere. It follows the reader's light or dark setting
#' and is written without pandoc or any other tool outside R.
#'
#' @param d A report from [xbrl_report_data()], or facts from [read_xbrl()],
#'   which are passed to it with `...`.
#' @param file Where to write the page.
#' @param title The page's title. By default it names the company, or the
#'   number of companies.
#' @param ... Passed to [xbrl_report_data()] when `d` is facts.
#'
#' @return The path written, invisibly.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' xbrl_report(x, "report.html", cvr = "12345678")
#' }
#'
#' @seealso [xbrl_report_data()] for the content as data.
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_alert_success
#' @export
xbrl_report <- function(d, file, title = NULL, ...) {
  if (!inherits(d, "cvrr_report_data")) d <- xbrl_report_data(d, ...)
  if (missing(file) || !is.character(file) || length(file) != 1)
    cli::cli_abort("{.arg file} must be one path to write the page to.")
  tr <- .report_words(d$meta$lang)
  lab <- .report_labels(d$meta$lang)

  title <- title %||% if (d$type %in% c("filing", "company"))
    d$profile$value[1] else sprintf(if (d$meta$lang == "da") "%d virksomheder"
                                    else "%d companies", d$meta$companies)
  yrs <- paste(unique(format(d$meta$years, "%Y")), collapse = "–")
  sub <- paste(c(if (d$type %in% c("filing", "company")) paste("CVR", d$profile$value[2]),
                 yrs, lab[[paste0("type_", d$type)]]), collapse = "  ·  ")

  sec <- function(head, body) if (is.null(body)) "" else
    sprintf("<section><h2>%s</h2>%s</section>", .esc(head), body)
  body <- c(
    sprintf("<header><h1>%s</h1><p class='sub'>%s</p></header>", .esc(title), .esc(sub)),
    sec(lab$highlights, sprintf("<ul class='hl'>%s</ul>",
        paste0("<li>", vapply(d$highlights, .esc, ""), "</li>", collapse = ""))))

  if (d$type %in% c("filing", "company")) {
    body <- c(body,
      sec(lab$profile, .html_table(d$profile, lab, tr, header = FALSE)),
      sec(lab$figures, .html_table(d$figures, lab, tr, wide_years = TRUE)),
      sec(lab$ratios, .html_table(d$ratios, lab, tr, wide_years = TRUE)),
      sec(lab$robustness, .html_table(d$robustness, lab, tr, wide_years = TRUE)),
      sec(lab$findings, if (is.null(d$findings)) NULL else .html_table(d$findings, lab, tr)))
  } else {
    body <- c(body,
      sec(lab$composition, paste0("<div class='row'>", paste(vapply(names(d$composition), function(k)
        sprintf("<div><h3>%s</h3>%s</div>", .esc(lab[[k]] %||% k),
                .html_table(d$composition[[k]], lab, tr)), ""), collapse = ""), "</div>")),
      sec(lab$distribution, .html_table(d$distribution, lab, tr)),
      sec(lab$robustness, .html_table(d$robustness, lab, tr)),
      sec(lab$vulnerable, if (nrow(d$vulnerable)) .html_table(d$vulnerable, lab, tr) else NULL),
      sec(lab$findings, if (is.null(d$findings)) NULL else .html_table(d$findings, lab, tr)))
  }
  t <- d$technical
  if (!is.null(t) && nrow(t))
    body <- c(body, sec(lab$technical, sprintf("<p class='note'>%s</p>%s",
      .esc(lab$technical_note),
      .html_table(t[c("kind", "elementid", "period", "value_tagged", "value", "action")], lab, tr))))
  body <- c(body, sprintf("<footer>%s</footer>", .esc(sprintf(lab$footer, format(d$meta$made)))))

  page <- sprintf(paste0(
    "<!doctype html><html lang='%s'><head><meta charset='utf-8'>",
    "<meta name='viewport' content='width=device-width, initial-scale=1'>",
    "<title>%s</title><style>%s</style></head><body><main>%s</main></body></html>"),
    d$meta$lang, .esc(title), .REPORT_CSS, paste(body, collapse = "\n"))
  writeLines(page, file, useBytes = TRUE)
  cli::cli_alert_success("Report written to {.path {file}}.")
  invisible(file)
}

# A table. With `wide_years`, a table of one row per year is turned so that
# the years are the columns and the figures the rows, which is how a set of
# accounts is read.
.html_table <- function(df, lab, tr, header = TRUE, wide_years = FALSE) {
  if (is.null(df) || !nrow(df)) return("")
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  if (wide_years && "year" %in% names(df)) {
    yrs <- as.character(df$year)
    vars <- setdiff(names(df), "year")
    # The column name passed as a value, not as an argument name: named `v`
    # it was matched to .cell()'s own first formal, and every cell showed the
    # column's name instead of its figure.
    cells <- vapply(vars, function(col)
      vapply(df[[col]], function(val) .cell(val, col, tr), ""),
      character(nrow(df)))
    cells <- matrix(cells, nrow = nrow(df))
    head <- paste0("<th></th>", paste0("<th class='n'>", .esc(yrs), "</th>", collapse = ""))
    rows <- vapply(seq_along(vars), function(j)
      paste0("<tr><th>", .esc(lab[[vars[j]]] %||% vars[j]), "</th>",
             paste0("<td class='n'>", cells[, j], "</td>", collapse = ""), "</tr>"), "")
    return(sprintf("<div class='tw'><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>",
                   head, paste(rows, collapse = "")))
  }
  # A table of quartiles by ratio: each row is formatted as its ratio is -- a
  # current ratio is a multiple, not a percentage -- and named by its label.
  fmt_as <- function(n, i) n
  if ("ratio" %in% names(df) && all(c("q1", "median", "q3") %in% names(df))) {
    rn <- as.character(df$ratio)
    fmt_as <- function(n, i) if (n %in% c("q1", "median", "q3")) rn[i] else n
    df$ratio <- vapply(rn, function(r) lab[[r]] %||% r, "", USE.NAMES = FALSE)
  }
  num <- vapply(df, is.numeric, logical(1))
  head <- if (header) paste0("<thead><tr>", paste0(
    "<th", ifelse(num, " class='n'", ""), ">",
    vapply(names(df), function(n) .esc(lab[[n]] %||% n), ""), "</th>", collapse = ""),
    "</tr></thead>") else ""
  rows <- vapply(seq_len(nrow(df)), function(i)
    paste0("<tr>", paste0("<td", ifelse(num, " class='n'", ""), ">",
      vapply(names(df), function(n) .cell(df[[n]][i], fmt_as(n, i), tr), ""), "</td>", collapse = ""),
      "</tr>"), "")
  sprintf("<div class='tw'><table>%s<tbody>%s</tbody></table></div>", head,
          paste(rows, collapse = ""))
}

# One cell, formatted by what its column is.
.cell <- function(v, v_name, tr) {
  if (length(v) == 0 || (length(v) == 1 && is.na(v))) return("<span class='na'>–</span>")
  if (is.logical(v)) return(if (v) "<span class='yes'>●</span>" else "·")
  if (inherits(v, "Date")) return(.esc(format(v)))
  if (!is.numeric(v)) return(.esc(as.character(v)))
  if (grepl("_pct$", v_name)) return(.fmt_num(v, tr, 0))
  if (grepl("ratio$|return|share|growth|change|buffer|^three_or_more$|^q1$|^median$|^q3$",
            v_name) || v_name %in% .ROBUSTNESS_FACTORS)
    return(if (grepl("^current_ratio|^cash_ratio", v_name)) .fmt_num(v, tr, 2) else .fmt_pct(v, tr))
  if (grepl("months|coverage", v_name)) return(.fmt_num(v, tr, 1))
  .fmt_num(v, tr, 0)
}

.esc <- function(s) {
  s <- gsub("&", "&amp;", as.character(s), fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub("'", "&#39;", s, fixed = TRUE)
}

.report_labels <- function(lang) {
  da <- list(
    type_filing = "ét regnskab", type_company = "tidsserie",
    type_cross_section = "tværsnit", type_panel = "panel",
    highlights = "Det væsentligste", profile = "Virksomheden",
    figures = "Regnskabet", ratios = "Nøgletal", robustness = "Robusthed",
    findings = "Fund i kontrollen", composition = "Sammensætning",
    distribution = "Fordeling af nøgletal", vulnerable = "De mest sårbare",
    technical = "Rettet før analysen",
    technical_note = "Tal tagget i forkert enhed eller med fortegnet den forkerte vej, rettet før beregningerne. Det oprindelige tal står ved siden af.",
    footer = "Lavet med cvrr %s af de offentliggjorte årsrapporter. Et fund er en grund til at læse rapporten, ikke en konklusion om den.",
    item = "", value = "", year = "År", n = "Antal", class = "Regnskabsklasse",
    form = "Virksomhedsform", assurance = "Revisors bistand",
    revenue = "Nettoomsætning", gross_profit = "Bruttofortjeneste",
    staff_costs = "Personaleomkostninger", depreciation = "Afskrivninger",
    operating_profit = "Resultat af primær drift", net_financials = "Finansielle poster, netto",
    tax = "Skat", profit = "Årets resultat", assets = "Aktiver", equity = "Egenkapital",
    longterm_debt = "Langfristet gæld", shortterm_debt = "Kortfristet gæld",
    cash = "Likvide beholdninger", employees = "Ansatte",
    equity_ratio = "Soliditetsgrad", operating_return = "Afkast af driften",
    return_on_assets = "Afkastningsgrad", return_on_equity = "Egenkapitalens forrentning",
    current_ratio = "Likviditetsgrad", staff_share = "Lønkvote",
    gross_profit_growth = "Vækst i bruttofortjeneste", equity_ratio_change = "Ændring i soliditet",
    equity_ratio_pct = "Soliditet, percentil", operating_return_pct = "Afkast, percentil",
    current_ratio_pct = "Likviditet, percentil",
    negative_equity = "Negativ egenkapital", capital_lost = "Kapitaltab",
    thin_equity = "Soliditet under 15 %", two_losses = "To underskud i træk",
    shortterm_heavy = "Kortfristet gæld over halvdelen", weak_interest_cover = "Svag rentedækning",
    weak_return = "Svagt afkast mod gruppen", young = "Under fem år",
    going_concern_factor = "Usikkerhed om fortsat drift", n_factors = "Antal faresignaler",
    gross_profit_buffer = "Buffer i bruttofortjeneste", cash_months = "Måneders løn i kassen",
    period_end = "Periode slut", check = "Kontrol", finding = "Fund", severity = "Alvor",
    share = "Andel af aktiver", detail = "Detalje", ratio = "Nøgletal",
    q1 = "1. kvartil", median = "Median", q3 = "3. kvartil", companies = "Virksomheder",
    three_or_more = "Tre eller flere faresignaler", cvr = "CVR", name = "Navn",
    kind = "Art", elementid = "Element", period = "Dato", value_tagged = "Tagget",
    action = "Handling")
  en <- da
  en[] <- names(en)
  en[c("type_filing", "type_company", "type_cross_section", "type_panel",
       "highlights", "profile", "figures", "ratios", "robustness", "findings",
       "composition", "distribution", "vulnerable", "technical", "technical_note",
       "footer")] <- list("one filing", "time series", "cross-section", "panel",
       "What matters most", "The company", "The accounts", "Ratios", "Robustness",
       "Findings in the checks", "Composition", "Distribution of ratios",
       "The most vulnerable", "Corrected before the analysis",
       "Figures tagged in the wrong unit or with the sign the wrong way, corrected before the calculations. The figure as tagged is beside it.",
       "Made with cvrr %s from the published annual reports. A finding is a reason to read the report, not a conclusion about it.")
  en[c("item", "value")] <- ""
  for (k in setdiff(names(en), names(da)[1:16])) if (identical(en[[k]], k))
    en[[k]] <- gsub("_", " ", sub("^(.)", "\\U\\1", k, perl = TRUE))
  if (lang == "da") da else en
}

.REPORT_CSS <- paste0(
  ":root{--bg:#fbfbfa;--fg:#1d1f21;--muted:#5d6166;--line:#d9dcdf;--accent:#0f6b73;",
  "--warn:#9a5b00;--bad:#a1262d;--card:#ffffff}",
  "@media (prefers-color-scheme:dark){:root{--bg:#15181b;--fg:#e6e8ea;--muted:#a0a6ad;",
  "--line:#30363c;--accent:#5fc3c9;--warn:#e0a84a;--bad:#ef7a80;--card:#1c2024}}",
  "*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);",
  "font:16px/1.5 system-ui,-apple-system,'Segoe UI',sans-serif}",
  "main{max-width:1040px;margin:0 auto;padding:24px 16px 48px}",
  "h1{font-size:1.7rem;margin:0}h2{font-size:1.15rem;margin:32px 0 8px;",
  "border-bottom:2px solid var(--accent);padding-bottom:4px}h3{font-size:1rem;margin:8px 0}",
  ".sub{color:var(--muted);margin:4px 0 0}",
  ".hl{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--accent);",
  "border-radius:8px;padding:12px 16px 12px 32px;margin:0}.hl li{margin:4px 0}",
  ".tw{overflow-x:auto;background:var(--card);border:1px solid var(--line);border-radius:8px}",
  "table{border-collapse:collapse;width:100%;font-size:.92rem}",
  "th,td{padding:6px 10px;border-bottom:1px solid var(--line);text-align:left;white-space:nowrap}",
  "thead th{color:var(--muted);font-weight:600}tbody th{font-weight:500}",
  "tr:last-child td,tr:last-child th{border-bottom:0}",
  ".n{text-align:right;font-variant-numeric:tabular-nums}",
  ".na{color:var(--muted)}.yes{color:var(--bad)}",
  ".row{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}",
  ".note{color:var(--muted);font-size:.92rem}",
  "footer{margin-top:40px;color:var(--muted);font-size:.85rem}")
