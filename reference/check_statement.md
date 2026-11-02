# Reconcile a statement against its own hierarchy

Checks every subtotal in a tidied statement against the lines below it,
and says which of three things is true of each: the reported detail adds
up, the statement presents the same figures under two groupings, or
there is unspecified detail left over.

## Usage

``` r
check_statement(x, by = NULL, period = "closing", tol = 1)
```

## Arguments

- x:

  A tibble from
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- by:

  Columns identifying one statement instance. `NULL`, the default, uses
  whichever of `file`, `basis` and `period` the table has – `file`
  because read_xbrl() returns many filings at once, and without it two
  companies with the same balance sheet date are checked as one.

- period:

  `"closing"`, the default, checks the year the filing declares for
  itself and leaves its comparative out – a comparative is usually
  partial, and its gaps are not the filing's. `NULL` checks every period
  the table carries.

- tol:

  Absolute tolerance in the reporting currency. Default `1`.

## Value

A tibble with one row per subtotal that has reported detail: the `by`
columns, `statement`, `code`, `elementid`, `label`, `total`, `specified`
(the sum of the nearest reported descendants), `residual`, `n_children`
and `verdict`.

## Children are not one level down

A filer may report a figure while leaving its intermediate parent empty,
so the lines that partition a subtotal are the *nearest reported*
descendant on each branch. A fixed depth+1 rule reports discrepancies
that are not there.

## Debt is presented twice

A Danish balance sheet lists debt both by counterparty and by maturity,
so a subtotal's children can hold the same money twice over. When both
groupings are complete the children sum to an exact multiple of the
subtotal, but they usually are not: one partition is itemised in full
while the other is only partly filled in, and the sum lands somewhere in
between.

So the test is not a ratio but a search: is there a *subset* of the
children that hits the subtotal exactly? If there is, that subset is a
complete grouping and the rest is another view of the same figures. The
verdict is `"two groupings"` and `n_partition` says how many lines the
complete one holds – a presentation feature, named rather than reported
as an error.

## Repeated lines

The same statement line can arrive more than once – one filing in a
sample of 100 reported its cash position six times and its receivables
twice, all with the same figure. Repeats that agree are collapsed
silently, because nothing turns on them. Repeats that *disagree* are a
different matter: the filing states two different amounts for one line,
and the verdict says `"conflicting duplicates"` rather than quietly
keeping whichever came first.

## The closing identity

Checking each subtotal against the lines below it never reaches the one
identity a statement exists to assert: that assets equal liabilities and
equity. Those two are not parent and child but siblings of opposite sign
under an abstract root, so they are not summed – they are compared.

The rule needs no list of element names. Where a node's reported
children split into a debit group and a credit group, the two must be
equal, and the verdict is `"sides agree"` or `"sides differ"`. In the
Danish balance sheet that is exactly Aktiver against Passiver.

The income statement has no such identity: its cascade runs through
signed subtotals to Aarets resultat, which is
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)'s
problem, not a sum.

## What an absent line means

The taxonomy offers dozens of alternatives under a subtotal and a
company uses a handful. An unreported line means "not applicable", not
"unknown", so a residual of zero is the normal and expected result – it
says the reported detail already exhausts the subtotal and can be used
as it stands.

## See also

[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
and
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
for the income statement, whose lines carry signs and so are not a plain
sum.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
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
checks <- check_statement(x)
table(checks$verdict)

# what is left unexplained
checks[checks$verdict == "unspecified remainder", ]
} # }
```
