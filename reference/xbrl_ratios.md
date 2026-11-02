# Key ratios, the change from last year, and the place among peers

Takes a panel from
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md)
and adds what an analysis reads off it: the ratios the statistics
offices publish, how each company moved since its previous filing, and
where it stands among comparable companies the same year.

## Usage

``` r
xbrl_ratios(p, group = "class", min_peers = 5)
```

## Arguments

- p:

  A panel from
  [`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md).

- group:

  Columns of `p` that make companies comparable. Default `"class"`.

- min_peers:

  Smallest group a median and a rank are computed for. Default `5`.

## Value

`p` with the ratios, the changes and the peer columns added.

## The ratios

The definitions are the statistics offices', not corporate finance's, so
that a figure here can be set beside a published one:

- `equity_ratio` – equity / assets (soliditetsgrad).

- `return_on_assets` – profit after tax / assets (afkastningsgrad, as
  Statistics Greenland publishes it).

- `operating_return` – operating profit / assets: the return before
  interest and tax, which is what a company's operation earns on what it
  has.

- `return_on_equity` – profit / equity, `NA` where equity is not
  positive.

- `operating_margin` – operating profit / revenue (overskudsgrad);
  `operating_share_of_gross` the same against the gross profit, which is
  what a class B filing has.

- `current_ratio` – current assets / short-term debt (likviditetsgrad);
  `cash_ratio` cash / short-term debt.

- `debt_ratio` – debt other than provisions / assets;
  `shortterm_debt_share` short-term debt / assets.

- `interest_coverage` – operating profit / finance expenses.

- `staff_share` – staff costs / gross profit (lonkvote). The gross
  profit of a Danish filing is revenue less goods and external costs,
  which is value added at factor cost, so `value_added` is it.

- `value_added_per_employee`, `profit_per_employee`.

A ratio whose denominator is missing, nought, or of the wrong sign for
the ratio to mean anything is `NA`.

## The change from last year

For a company with a filing for the year before – its previous period
ending 11 to 13 months earlier – `gross_profit_growth`,
`revenue_growth`, `assets_growth` and `equity_growth` are the relative
changes and `equity_ratio_change` is the change in percentage points. A
company whose previous figure was not positive has no growth rate,
because a change from a loss is not a percentage.

## Among peers

`group` names the panel's columns that make companies comparable. The
default is the accounting class, because that is in every filing. A
branch of industry is a better comparison and is not in a filing: join
it to the panel on `cvr` and name its column here. For each group and
year, the median of `equity_ratio`, `operating_return`, `current_ratio`
and `return_on_equity` is added, with each company's percentile rank
among its peers (`*_pct`, 0 to 100). A group with fewer than `min_peers`
companies gets neither: a median of three companies is mostly one
company's figure.

## See also

[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
and
[`xbrl_robustness()`](https://dataniel.github.io/cvrr/reference/xbrl_robustness.md)
for how vulnerable a company is.

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
p <- xbrl_panel(read_xbrl("materiale/xbrl"))
r <- xbrl_ratios(p)
r[c("cvr", "period_end", "equity_ratio", "equity_ratio_pct")]

# against a branch of industry from a register extract of your own
p$branch <- register$branch[match(p$cvr, register$cvr)]
r <- xbrl_ratios(p, group = "branch")
} # }
```
