# Write a report on the filings as one HTML page

Renders what
[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md)
gathered: the findings in sentences first, then the tables behind them.
The page is a single self-contained file with no scripts, fonts or
images to fetch, so it can be mailed, archived or opened anywhere. It
follows the reader's light or dark setting and is written without pandoc
or any other tool outside R.

## Usage

``` r
xbrl_report(d, file, title = NULL, ...)
```

## Arguments

- d:

  A report from
  [`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md),
  or facts from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md),
  which are passed to it with `...`.

- file:

  Where to write the page.

- title:

  The page's title. By default it names the company, or the number of
  companies.

- ...:

  Passed to
  [`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md)
  when `d` is facts.

## Value

The path written, invisibly.

## See also

[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md)
for the content as data.

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
[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md),
[`xbrl_robustness()`](https://dataniel.github.io/cvrr/reference/xbrl_robustness.md),
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md),
[`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")
xbrl_report(x, "report.html", cvr = "12345678")
} # }
```
