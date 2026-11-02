# The filings as a panel: one row per company and year

Everything before this is about reading filings correctly; this is where
they become data to analyse. One row per filing and basis, the statement
figures as named variables – `revenue`, `operating_profit`, `equity`,
`cash`, `cf_operating` – beside who the company is and how far its
figures can be trusted. A time series of one company and a cross-section
of many are the same table, so whatever is computed from it works on
either.

## Usage

``` r
xbrl_panel(x, basis = "parent", standardise = TRUE, .checks = NULL)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md),
  or from
  [`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md),
  whose lines and checks are then read rather than computed again.

- basis:

  `"parent"` (default), `"consolidated"`, or both. A filing with group
  accounts has a row for each basis asked for.

- standardise:

  Run
  [`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md)
  first, if it has not been. Default `TRUE`.

- .checks:

  Internal: the checks
  [`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md)
  has already run on the same facts, as `attr(s, "checks")`, so they are
  not run twice.

## Value

A tibble of class `cvrr_panel`: the key (`cvr`, `name`, `period_start`,
`period_end`), `basis`, the figures, the background (`class`, `form`,
`micro`, `founded`, `assurance`, `opinion_kind`, `going_concern`,
`in_group`, `group_accounts`, `employees`, `currency`), the trust
columns, and `file`. Amounts are in the reporting currency as filed.

## Where the figures come from

From
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
not from the facts directly: a line the filer left out of the balance
sheet is derived there, a line tagged twice is settled, and after
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md)
a figure in the wrong unit is already in the right one. Each variable is
read from a list of elements, the first one the filing reports winning;
the lists are in `attr(p, "variables")`.

Most Danish filings are accounting class B, which may start the income
statement at the gross profit. `revenue` is then `NA`, not an estimate:
13% of a 4,304-filing corpus report it, against 81% the gross profit.

## Signs

One convention throughout. Incomes, balances and subtotals keep their
natural sign, so a loss is negative and so is negative equity. Costs are
positive amounts: 99% of filers write them so, and the rest have signed
them already. Tax is the one cost that is genuinely negative – a refund,
a deferred tax asset – in a fifth of filings, so where the result before
and after tax are both reported it is their difference, which has the
right sign by construction, and `net_financials` is likewise the result
before tax less the operating result.

That makes `net_financials` the complete figure and `finance_income` and
`finance_expenses` only the lines called that. Income from subsidiaries
and impairment of financial assets are financial items too, and with
them left out the two lines account for the result before tax in 77% of
the corpus. Use `net_financials` for the total.

## How far to trust a row

`balance_reconciled`, `income_reconciled` and `cashflow_reconciled` are
the verdicts of
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
and
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md);
`corrections` counts the figures
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md)
changed in the filing. A row is kept whatever they say: excluding is the
analysis's decision, and it can only be made if the row is there.

## See also

[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
for the statements line by line,
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md)
for what does not add up.

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
p <- xbrl_panel(x)

# one company over time
p[p$cvr == "12345678", c("period_end", "gross_profit", "operating_profit", "equity")]

# the rows whose statements add up
subset(p, balance_reconciled & income_reconciled)
} # }
```
