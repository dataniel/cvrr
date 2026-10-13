# Choose between two figures reported for the same line

A filing sometimes states one statement line twice with different
amounts.
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
refuses to pick and reports `"conflicting duplicates"`, which leaves the
statement unjudgeable. But the statement has to add up, and that is
usually enough to decide: try each candidate, keep the reading that
reconciles.

## Usage

``` r
xbrl_resolve(x, by = c("basis", "period"), max_readings = 256L, tol = 1)
```

## Arguments

- x:

  A tibble from
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- by:

  Columns identifying one statement. Default `c("basis", "period")`.

- max_readings:

  Give up where the candidates multiply beyond this. Default `256`.

- tol:

  Absolute tolerance in the reporting currency. Default `1`.

## Value

`x` with the losing duplicates dropped and two columns added:
`resolved`, `TRUE` on a line whose value this chose, and `resolution`,
saying how – `"rounding"` where the figures were one number at two
precisions, `"empty context"` where the rival figure was a nil column of
its own, `"arithmetic"` where the sums decided. Lines with no conflict,
and conflicts with no single best reading, come back untouched.

## Most conflicts are rounding

Before any search, duplicates that differ only by rounding are
collapsed. XBRL states the precision of every fact in its `decimals`
attribute, so a filing that tags total assets as `1729466749` at
`decimals="0"` and as `1729467000` at `decimals="-3"` has written one
figure twice, not two figures. The exact one is kept.

## One balance sheet, one context

Then the context. A balance sheet column is a single XBRL context –
assets, equity and the liabilities all carry the same `contextRef`,
because that is what a context is for. One filing in the corpus states
its whole balance sheet twice: once in a context holding the figures,
once in a context holding nothing but nils.

Neither a majority nor the arithmetic separates those two. The counts
are equal, and an empty column adds up perfectly – nought is nought plus
nought. What separates them is that a column of nils is not a statement,
so the rule is kept to exactly that: a context whose every disputed
figure is nil, where another has real ones, is an empty column and not a
reading.

## The same argument as find_signs()

[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
does not guess a sign; it enumerates the assignments and reports the one
that reaches the total, or says there are several. This is the same
search over a different unknown – not which sign a figure carries but
which of two figures was meant – and it holds to the same rule. A
conflict that admits one reconciling reading is resolved. One that
admits several is left alone, because a statement that adds up two ways
has not told us which way it meant.

## Scoring

A candidate reading is scored by how many subtotals it settles:
`complete` and `sides agree` count for it, `sides differ` and
`over-specified` against. The winner must score above zero – a reading
that settles nothing is not a resolution – and must beat every other
outright.

Ties are left unresolved. Over the corpus, breaking them by taking the
first best reading settled seven conflicts, and the picks were visibly
wrong: nil for one company's short-term debt, and a figure for another's
total assets that was neither of the two under dispute. Eight of the
fifteen had a single best reading, and those are the ones worth having.

## What this cannot do

It resolves a conflict; it does not diagnose one. Where a filer has used
one element for two different things – gross and net deferred tax, say –
the arithmetic picks whichever fits the statement, which is the right
figure for the balance sheet and says nothing about why the other is
there.

## See also

[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
which reports the conflict, and
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md),
which derives what is absent rather than choosing between what is
present.

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
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md),
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
[`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md),
[`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("13645183_2024-12-31.xml")
check_statement(x)$verdict                  # "conflicting duplicates"
check_statement(xbrl_resolve(x))$verdict    # "complete"
} # }
```
