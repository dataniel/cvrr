# Does the balance a company closed on reopen in the next filing?

Every other check in this package reads one annual report and asks
whether it agrees with itself. This one compares filings: the balance
sheet a company closed on at the end of one year is the balance it opens
on in the next, and the two figures are filed a year apart.

## Usage

``` r
check_continuity(x, by = "cvr", filing = "year", tol = 1, rel = 0.001)
```

## Arguments

- x:

  Facts from several filings, with `elementid`, `value`, the columns
  named by `by` and `filing`, and `instant` – plus `startdate` and
  `enddate` if the income statement is to be compared as well.

- by:

  Column identifying the company. Default `"cvr"`.

- filing:

  Column identifying the filing, used to order the two statements.
  Default `"year"`; a table from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
  carries `period_end` instead, so pass that.

- tol:

  Absolute tolerance in the reporting currency. Default `1`.

- rel:

  Relative tolerance below which a difference is called rounding.
  Default `0.001`.

## Value

A tibble with one row per figure stated twice: the `by` column,
`elementid`, `period` (the instant, or the span a duration covers), the
two filings and their values, `diff`, `rel`, and `verdict` – `"agrees"`,
`"rounding"`, `"scaled"` where the ratio is a power of a thousand, or
`"differs"`.

## The one check a single filing cannot make

A filing scaled wrongly all the way through is internally perfect. Its
balance balances, its cascade reconciles, every structural test in this
package passes – because everything in it was multiplied by the same
number. Only a figure from outside disagrees.

Across 4,304 Danish filings this found 84 such figures, 8 out by a
thousand and 76 by a thousandth. Nothing else here would have seen them.

## A difference is not always an error

Companies restate. Where more than half a balance sheet's lines disagree
the filer has changed something deliberately – a change of accounting
policy, a correction, a merger – and a statistic needs to know that
rather than treat it as noise. Where one line moves and the rest hold,
it is a correction to that line. The verdicts say which shape it is;
neither is called wrong.

## What is compared

Undimensioned figures, where two filings state the same element for the
same date – a balance by its instant, an income statement line by the
period it covers. Both are things a company says twice: the comparative
column of one filing against the primary column of the one before it.

Comparatives *inside* a single filing are not used. They are the same
document making the same claim twice, and agreeing with itself proves
nothing.

## See also

[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
which checks the same balance through one year rather than across two.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
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
# every filing of every company in one table
x  <- read_xbrl("materiale/xbrl")
cc <- check_continuity(x, filing = "period_end")

cc[cc$verdict == "scaled", ]     # a filing multiplied all the way through
} # }
```
