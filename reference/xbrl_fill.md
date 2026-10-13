# Derive the figures a filing left out

A filer may report the components of a subtotal without the subtotal, or
the subtotal without one of its components. Both are ordinary, and both
leave a statistic short of a variable it needs. The presentation
hierarchy names every line that belongs, so both can be recovered.

## Usage

``` r
xbrl_fill(
  x,
  taxonomy = NULL,
  statement = c("BalanceSheetAccountForm", "BalanceSheetReportForm"),
  residual = "default",
  by = c("basis", "period"),
  tol = 1
)
```

## Arguments

- x:

  A tibble from
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- taxonomy:

  A `cvrr_taxonomy` from
  [`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
  or a list of them. The hierarchy is what names the missing line; the
  reported facts alone cannot say which line is absent.

- statement:

  Restrict to these statements. Defaults to the balance sheet, for the
  reason above.

- residual:

  Which line receives a remainder that cannot be attributed to one
  absent component: a named character vector, subtotal to line.
  `"default"` (the default) uses the map for the Danish balance sheet
  described below; `NULL` derives only where exactly one component is
  missing.

- by:

  Columns identifying one statement. Default `c("basis", "period")`.

- tol:

  Absolute tolerance in the reporting currency. Default `1`.

## Value

`x` with derived rows appended and a `source` column added:
`"reported"`, `"derived: sum of components"`, `"derived: residual"` (one
component was missing, so the remainder is that component) or
`"derived: remainder to residual line"` (several were missing, and the
remainder went to the line whose purpose is to hold it).

## What is derived, and what is not

Two cases, and only these two.

A **subtotal** is derived where the taxonomy places one over lines the
filing reports and the subtotal itself is untagged. Its value is the sum
of the nearest reported lines beneath it.

A **component** is derived where the subtotal is reported, its reported
components fall short, and the taxonomy leaves exactly *one* line
unaccounted for. The residual is that line. This is how `Anden gæld`
comes back: filers routinely give the specified debts and the total and
leave the remainder unnamed.

Where two or more lines are missing, arithmetic cannot say which of them
the remainder belongs to. But a statement has a line whose *purpose* is
to hold what is left over – `Anden gæld`, `Andre tilgodehavender` – and
where that line is among the missing ones, the remainder belongs there
by definition rather than by guess. `residual` names those lines; see
below.

## Why the residual line has to be named

There is no structural way to find it.
`LongtermLiabilitiesOtherThanProvisions` has 37 children in the 2023
taxonomy, three of whose Danish labels begin "Anden" or "Andre":
provisions, bond debt, and the catch-all. Only the third is a remainder
line; the other two are named categories that happen to start with the
same word. Element names carry the same trap – 67 elements begin
`Other`, and most are ordinary categories.

Nor does presentation order help: the catch-all sits 28th of the 37, not
last. So the map is written out by hand from the labels, it covers the
Danish balance sheet, and a caller with a different statement supplies
their own. A rule that guessed would put bond debt where trade creditors
belong.

## Signs, and why only the balance sheet

This works on lines that add up without a sign convention – assets,
liabilities, equity. The income statement is not filled: its lines carry
signs the filer chose, so a residual there is not a value but a value
and a direction, and
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
is the tool that resolves those.

## A derived figure is not a reported one

Every row comes back with `source`, and the derived ones say how they
were arrived at. A statistic that cannot distinguish the two will
eventually publish an inference as an observation, so the column is not
optional and the derived rows are not silently merged.

## See also

[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
which reports the same two situations without resolving them, and
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
whose `assume_nil` is the same idea applied to a schedule's endpoints.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
[`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md),
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
[`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md),
[`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# one filing, so the default grouping is the whole of it
x <- read_xbrl("13645183_2024-12-31.xml")
filled <- xbrl_fill(x)

filled[filled$source != "reported", c("elementid", "label", "value", "source")]

# a directory: the grouping has to say which filing a line belongs to
xbrl_fill(read_xbrl("materiale/xbrl"), by = c("file", "basis", "period"))
} # }
```
