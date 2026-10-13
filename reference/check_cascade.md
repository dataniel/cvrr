# Reconcile an income statement step by step

An income statement is not a sum but a cascade: trading gives a gross
figure, operating costs take it to the result of ordinary activities,
financial items to the result before tax, and tax to the result for the
year. This reconciles each step against its own subtotal.

## Usage

``` r
check_cascade(
  x,
  taxonomy = NULL,
  statement = "income",
  by = NULL,
  period = "closing",
  max_zeros = 1L,
  tol = 1,
  retry = TRUE
)
```

## Arguments

- x:

  A tibble from
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
  filtered to one income statement, or a panel of them.

- taxonomy:

  The `cvrr_taxonomy` the filings declare, or a list of them when they
  span versions – as a single accounting year routinely does. Needed
  because the steps come from the *taxonomy's* hierarchy, not from what
  happens to be reported: a filing that omits its result of ordinary
  activities would otherwise have the line above it mistaken for a
  subtotal.

- statement:

  Which statement the cascade belongs to. `"income"`, the default, is
  the one that is a cascade; pass a taxonomy statement name for another,
  or `NULL` to walk every statement in `x`.

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

- max_zeros:

  Passed to
  [`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md):
  how many items a step may leave out. Default `1L`, since a step holds
  few items.

- tol:

  Absolute tolerance in the reporting currency, or `"decimals"` to take
  it from what the filing claims about its own precision. Default `1`.
  See the section below.

- retry:

  Give a statement the first pass could not settle a second reading, in
  which a line a step did not need is offered to the step below instead
  of being consumed. Only applied where the strict pass failed, so a
  statement that already reconciled is untouched. Default `TRUE`.

## Value

A tibble with one row per step and statement instance: the `by` columns,
`step`, `target` (the subtotal it reconciles to), `n_items`, `status`
from
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md),
and `entry`, the income concept the filing started from. A step a filing
does not have is `"not reported"`; a step whose subtotal is given
without components is `"given"`, `"unchanged"` where the subtotal
carried in equals this one so nothing happened between them, and
`"unexplained"` where they differ with no line tagged to say why.

## Judging a statement by its own precision

`tol = "decimals"` reads the tolerance off the filing. XBRL states the
precision of every fact: `decimals="-3"` means accurate to thousands, so
such a figure carries up to 500 kroner of rounding, and a step of
several adds theirs together.

The failures are concentrated where you would expect: of the 63 filings
whose cascade leaves a step unsolved or unexplained at a one-krone
tolerance, half report at `-3` or coarser, against 6% of the 3,857 that
settle every step.

It still buys very little, and that is worth saying. Over 4,304 filings
a tolerance read off each one recovers 16 of the 57 unsolved steps – out
of close to 11,000 that already solved – and turns one solved step
ambiguous. The default stays at one krone. This is here because it is
the right question to ask of a filing, not because asking it paid.

## Why step by step

Reconciling the whole statement at once fails in both directions. It
fails to solve, because twenty items against a bottom line rarely have
one answer; and worse, it sometimes *appears* to solve by mixing leaf
items, their parents and the running subtotals into a combination that
happens to reach the total. Four or five items against one subtotal is
decidable, and when a step does not reconcile you know which one.

## The reporting boundary is not a gap

Accounting class B may present a gross figure instead of turnover and
its components, and nearly all do – 4,172 of 4,304 filings enter at
`Bruttofortjeneste/Bruttotab` or `Bruttoresultat`, and three at
turnover. The taxonomy says so itself: the trading group has two exits,
`Bruttoresultat` and `Bruttofortjeneste/Bruttotab`. What varies is
therefore which income concept a filing *enters* on, not whether it is
complete.

A filing entering at a gross figure has nothing to reconcile in the
first step – the concept is given, not derived – and its figure is
carried into the second. Reconciling the remaining steps is a complete
result for that filing, and `entry` records where it started.

## How the steps are found

From the presentation hierarchy, not from a list of element names. The
groups are the statement's abstract top-level nodes; within each, the
itemised lines are the ones that are themselves broken down, and the
subtotal is what follows them. The final step is the statement's flat
tail, ending at the last line the filing reports – which is the result
for the year, or the result after minority interests where a filing
gives one.

## See also

[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md),
which does the reconciling, and
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
for the balance sheet, whose lines are a plain sum.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
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
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")
check_cascade(x)

# one presentation only, named as the taxonomy names it
check_cascade(x, statement = "IncomeStatementByFunction")
} # }
```
