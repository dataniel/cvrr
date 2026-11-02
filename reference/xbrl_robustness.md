# How robust a company is, and what it could withstand

Takes a panel from
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md)
(or
[`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md))
and says, for each company and year, which of the known signs of
financial vulnerability it shows, and how large a fall its figures could
absorb.

## Usage

``` r
xbrl_robustness(p, group = "class")
```

## Arguments

- p:

  A panel from
  [`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
  or its
  [`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md).

- group:

  Columns that make companies comparable, for `weak_return`. Default
  `"class"`; see
  [`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md).

## Value

`p` with the factor columns, `n_factors`, `gross_profit_buffer` and
`cash_months` added, and the validation in `attr(r, "validation")`.

## The factors

Each is a logical column, `NA` where the figures to judge it are
missing:

- `negative_equity` – equity below nought.

- `capital_lost` – equity below half the contributed capital: the point
  at which Danish company law requires the board to act.

- `thin_equity` – an equity ratio under 15%.

- `two_losses` – a loss this year and the year before.

- `shortterm_heavy` – short-term debt over half the assets.

- `weak_interest_cover` – operating profit under 1.5 times the finance
  expenses.

- `weak_return` – an operating return 5 percentage points or more under
  the median of comparable companies the same year (see `group`).

- `young` – founded less than five years before the end of the year.

- `going_concern_factor` – the auditor, or the filing itself, reports a
  material uncertainty about the company continuing. Where an auditor
  audited or reviewed the accounts and said nothing, it is `FALSE`.
  Where no auditor looked, it is `NA`.

They are the variables of Danmarks Nationalbank's bankruptcy model
(Finansiel stabilitet 2005), with capital lost and going concern added
because a filing states them. `n_factors` counts those that are `TRUE`.

## What it could withstand

- `gross_profit_buffer` – how far the gross profit could fall, as a
  share, before the operating profit is gone, if staff costs and
  depreciation did not move. They usually fall a little with it, so this
  is the smaller end of the buffer. `NA` where there is no operating
  profit to lose.

- `cash_months` – how many months of staff costs the cash covers.

## Have the factors held?

A company that stops filing while the corpus goes on has most often
ceased, so the factors can be held against that. `attr(r, "validation")`
compares, for each factor, the share of companies that filed no further
annual report within two years, with the factor and without it, over the
years for which two later years are in the data. It is a proxy: a
company can also stop filing because it moved its year end, merged, or
left the data for a reason of the data's. It says whether a factor
points the right way, not how likely a failure is.

Over 4,304 filings for 2020-2024, 4 to 6% of company-years without a
given factor were followed by no annual report within two years. With
weak interest cover, a weak return or capital lost it was 2.6 to 2.7
times as many; with negative equity, two losses or a going concern
uncertainty about twice. Short-term debt (1.8), thin equity (1.5) and
youth (1.4) point the same way, more weakly. By the count of factors:
4.8% with none, 13.5% with four or more.

## See also

[`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md),
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md).

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
[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md),
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md),
[`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
r <- xbrl_robustness(xbrl_panel(read_xbrl("materiale/xbrl")))
r[r$n_factors >= 3, c("cvr", "name", "period_end", "n_factors")]
attr(r, "validation")
} # }
```
