# Read the tables inside a filing's text notes

A note in an XBRL filing is a text block, and text blocks often hold the
note as escaped HTML – table markup and all. This finds those tables and
returns their cells, so a specification the filer never tagged can still
be read.

## Usage

``` r
xbrl_note_tables(x, elementid = NULL)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

- elementid:

  Which note to read. A single element name, several, or `NULL`
  (default) for every text block that contains a table.

## Value

A tibble in long form, one row per numeric cell: `elementid`, `table`
(its position in the note), `row`, `label` (the row's leading text
cell), `column`, `column_label` (the header above it, which in an
accounting note is the year) and `value`. A note with no table
contributes nothing.

## When this is worth doing

Where a company tags its staff costs only as a total, the split into
wages, pensions and social security usually still appears in
`DisclosureOfEmployeeBenefitsExpense`. Across a corpus of 4,304 Danish
filings, 1,302 report the total alone; 1,065 of those carry the note,
and 325 carry it as a table. The same holds for fixed-asset notes.

Whether the markup survives is the filing agent's choice, not the
format's: some flatten the table to a run of words before writing it
into the instance, and nothing can be recovered from those. About a
fifth of filings keep it.

## Numbers as accountants write them

Danish notes use `.` as the thousands separator and `,` for decimals,
wrap negatives in parentheses, and write a dash for nil. All four are
read. Anything else returns `NA` rather than a guess – a cell that
cannot be parsed is not a zero, and neither is an empty one: treating
blank layout cells as zeros invents columns and shifts every figure to
their right.

## See also

[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).
Validate what comes back against a tagged total before using it: a table
that does not add up has been misread.

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
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("filing.xml")
notes <- xbrl_note_tables(x, "DisclosureOfEmployeeBenefitsExpense")

# a specification is only usable if it sums to the figure that was tagged
sum(notes$value[notes$column == 1])
} # }
```
