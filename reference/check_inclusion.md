# Find lines a note says are contained in another line

A function-based income statement reports administrative expenses,
distribution costs and staff costs as separate figures. They are not
always separate amounts: where the staff note says the wages were
expensed under administration, the staff costs are *inside* the
administrative expenses, and adding the two counts them twice.

## Usage

``` r
check_inclusion(
  x,
  note = "DisclosureOfEmployeeBenefitsExpense",
  within = c("AdministrativeExpenses", "DistributionCosts", "CostOfSales")
)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

- note:

  The text block to read. Defaults to the staff cost note.

- within:

  Elements the note may place the costs under. Defaults to the two
  function-based expense lines.

## Value

A tibble with one row per line the note places inside another:
`elementid` (the contained line), `within` (the containing line),
`value` and `within_value` where both are reported, `sole` (whether the
note names this destination alone), and `evidence`, the sentence the
reading rests on. No rows where the note says nothing.

## Why no other check sees it

Both figures are correctly tagged, both belong to the statement, and the
statement still adds up – because the filer only ever counted the money
once. Nothing structural distinguishes this from a filing where the two
are genuinely separate. The only place the difference is stated is the
prose of the note.

## How common it is

Rare, in Danish filings. Across 4,304 filings from 2020-2024, 87 use the
function-based income statement at all, 38 report administrative
expenses and staff costs together, and 3 carry a note naming
administration. Most Danish companies file by nature – gross profit,
then staff costs, then depreciation – where the question does not arise.

That is worth knowing before relying on this: it is a check for a small,
real population, not a widespread correction.

## A cost split between destinations

A note may name several: wages expensed partly under production and
partly under administration. Each is returned as a row with
`sole = FALSE`, because the note says where the money went without
saying how much went to each. Treating such a filing as though the whole
staff cost sat in administration would replace one error with another,
so nothing is apportioned.

## What it does not do

It reports the inclusion; it does not net it out. How to handle a
double-counted line depends on which variable a statistic is building –
an employment cost total wants the staff figure, an operating cost
breakdown wants administration less staff – and that is the caller's
decision.

## See also

[`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
which reads the same notes for their figures rather than their prose.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
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
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("filing.xml")
check_inclusion(x)
} # }
```
