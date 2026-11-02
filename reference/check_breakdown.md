# Reconcile a dimensional breakdown against the line it breaks down

Where a figure is reported both as a statement line and split across the
members of a dimension – fixed assets by class, equity by reserve – the
parts must add up to the whole. This checks that they do.

## Usage

``` r
check_breakdown(x, by = NULL, period = "closing", tol = 1)
```

## Arguments

- x:

  A tibble from
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
  read with `dimensions = TRUE` so that each dimension has its own
  column.

- by:

  Columns identifying one statement instance. `NULL`, the default, uses
  whichever of `file`, `basis` and `period` the table has – `file`
  because read_xbrl() returns many filings at once, and without it two
  companies with the same balance sheet date are checked as one; add the
  company identifier for a panel.

- period:

  `"closing"`, the default, checks the year the filing declares for
  itself and leaves its comparative out – a comparative is usually
  partial, and its gaps are not the filing's. `NULL` checks every period
  the table carries.

- tol:

  Absolute tolerance in the reporting currency. Default `1`.

## Value

A tibble with one row per element and dimension that is reported both
ways: the `by` columns, `elementid`, `label`, `dimension`, `line` (the
undimensioned figure), `parts` (the members summed), `n_members`,
`ratio` and `verdict` – one of `"agrees"`, `"scaled by 1000"`,
`"scaled by 1/1000"` or `"parts do not cover the line"`.

## Why it is worth checking separately

[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
follows the presentation hierarchy, which runs down the statement. A
breakdown runs the other way, across a dimension, and nothing in the
hierarchy reaches it. It is also where a particular error hides.

A filing in a sample of 300 Greenlandic companies tags its balance sheet
in kroner and its fixed-asset note in thousands, in the same document.
Its additions for the year read `229` and `174` when they are 229,000
and 174,000 kr, which would have entered an investment series at a
thousandth of their size. Nothing else catches it: the unit is
`iso4217:DKK` like every other filing's, `decimals` is consistent, and
the company's registered capital clears its legal floor because the
*balance sheet* is right. Only the note is wrong, and only the filing's
own arithmetic shows it.

So the ratio is the point, not the difference. It is `1` when the
breakdown agrees, `1000` or `0.001` when the two sit on different
scales, and something near but not equal to 1 when the breakdown does
not cover every member.

## See also

[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
for the hierarchy,
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
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
b <- check_breakdown(x)
b[b$verdict != "agrees", ]
} # }
```
