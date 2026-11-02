# What a report on these filings would say, as data

Runs the pipeline – standardise, screen, panel, ratios, robustness – on
the filings given and gathers what a reader should know into one object:
tables, and a short list of findings written out as sentences. It is the
content of a report without its form, so that
[`xbrl_report()`](https://dataniel.github.io/cvrr/reference/xbrl_report.md)
can render it and anyone can build a report of their own from the same
parts.

## Usage

``` r
xbrl_report_data(
  x,
  cvr = NULL,
  type = NULL,
  peers = NULL,
  group = "class",
  lang = c("da", "en")
)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md),
  or from
  [`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)
  – which is the way to make several reports on the same filings without
  validating them for each.

- cvr:

  CVR numbers to report on. `NULL`, the default, reports on every
  company in `x`.

- type:

  `"filing"`, `"company"`, `"cross_section"` or `"panel"`; `NULL`
  decides from the data.

- peers:

  A panel from
  [`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md)
  to rank against, or `NULL`.

- group:

  Columns that make companies comparable. Default `"class"`; see
  [`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md).

- lang:

  `"da"` (default) or `"en"`, for the sentences.

## Value

A list of class `cvrr_report_data`: `type`, `meta`, `highlights`
(character), and the tables the type has – for one company `profile`,
`figures`, `ratios`, `robustness`, `findings` and `technical`; for many
`composition`, `distribution`, `robustness`, `vulnerable`, `findings`
and `technical`. `panel` is the robustness panel it was all read from.

## Which report

The data decides, unless `type` does:

- `"filing"` – one company, one year: who it is, its figures, what the
  checks and the auditor found, how robust it is.

- `"company"` – one company over several years: the same, as a time
  series, and what changed since the year before.

- `"cross_section"` – many companies, one year: what they look like
  together, how many show each sign of vulnerability, and which most.

- `"panel"` – many companies over several years: the same, year by year.

## Peers

A company's ratios mean more beside comparable companies'. Pass a panel
of them as `peers` – the rest of a corpus, say – and each company is
ranked among the companies of its `group` the same year. Without peers
there is nothing to rank against, and the report says nothing about rank
rather than rank a company against itself.

## See also

[`xbrl_report()`](https://dataniel.github.io/cvrr/reference/xbrl_report.md)
to render it, and
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
[`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md),
[`xbrl_robustness()`](https://dataniel.github.io/cvrr/reference/xbrl_robustness.md)
for the parts.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
[`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md),
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md),
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
[`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md),
[`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md),
[`xbrl_report()`](https://dataniel.github.io/cvrr/reference/xbrl_report.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md),
[`xbrl_robustness()`](https://dataniel.github.io/cvrr/reference/xbrl_robustness.md),
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md),
[`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")
d <- xbrl_report_data(x, cvr = "12345678", peers = xbrl_panel(x))
d$highlights
xbrl_report(d, "12345678.html")

# the whole corpus
xbrl_report(xbrl_report_data(x), "corpus.html")
} # }
```
