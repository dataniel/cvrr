# A statement, line by line

Returns one statement of every filing in `x` as it is presented: one row
per line, in statement order, with the lines the filer left out derived
where they can be. This is what an analysis reads – the fact table is
what it is read from.

## Usage

``` r
xbrl_lines(
  x,
  statement = "balance",
  basis = c("parent", "consolidated"),
  fill = TRUE,
  taxonomy = NULL
)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).
  The taxonomy has to be on it: the hierarchy is what names a line the
  filing never mentioned.

- statement:

  Which statement. `"balance"`, `"income"`, `"cashflow"` or `"equity"`,
  or one or more taxonomy statement names for anything else –
  `unique(cvrr_line$statement)` lists them.

- basis:

  `"parent"` (default) or `"consolidated"`. An untagged figure is the
  parent's, because the taxonomy says so – see
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- fill:

  Derive the lines the filing left out. Balance sheet only, for the
  reason above. `FALSE` returns only what was reported.

- taxonomy:

  Passed to
  [`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md).
  `NULL` uses the packaged tables.

## Value

A tibble in statement order, one row per line per filing: the key –
`cvr`, `name`, `period_start`, `period_end` – then `code`, `elementid`,
`label`, `value`, `currency` and `source`, with `file` last. `source` is
`"reported"`, `"derived: identity"`, or one of
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md)'s
values.

`code` is the taxonomy's own numbering and sorts into statement order,
but it is **not** an identifier: 861 of 11,809 codes name a different
element in a different taxonomy version, and 95 do so within one
version. Group a panel on `elementid`.

## Which presentation the filer chose is not your problem

The taxonomy carries the income statement twice, by nature and by
function, the balance sheet in three forms, and a dozen sector-specific
variants besides. A filing uses one of them and says nothing about the
choice. `statement = "income"` accepts whichever it was. Pass a taxonomy
statement name instead of an alias to be exact.

## What is derived, and what is not

The balance sheet is a partition: a subtotal is the sum of its parts, so
a line the filer omitted can be recovered. Two things do the recovering
– five headline identities (`Assets = NoncurrentAssets + CurrentAssets`
and its like), then
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md)
walking the hierarchy – and `source` says which, on every row.

The income statement is **not** a partition. It is a cascade: each
subtotal is the one above it plus and minus the year's items, and the
same figure appears in several steps. Summing components into it would
double-count, so `fill` does nothing outside the balance sheet, and an
income statement comes back as reported.
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
is what says whether it reconciles.

## Conflicting figures are settled first

A filing can tag the same line twice with different values – the same
figure at two precisions, or a nil comparative column.
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)
decides between them before anything is derived, because a subtotal
derived from the losing reading is worse than a missing one.

## See also

[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
which calls this for both statements at once,
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md)
for the derivation itself,
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
and
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
to verify the result adds up.

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
[`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md),
[`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")

xbrl_lines(x, "balance")
xbrl_lines(x, "income")

# what the filings did not state, and what it must have been
b <- xbrl_lines(x, "balance")
b[b$source != "reported", ]
} # }
```
