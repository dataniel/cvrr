# The accounting period a filing declares

A filing states its own reporting period as facts, and the preceding one
alongside it. Reading them beats inferring the period from the contexts:
the contexts hold whatever periods the filer happened to tag,
comparatives and note periods included, so the latest is not reliably
the accounting year and the earliest is not reliably its start.

## Usage

``` r
xbrl_period(x)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

## Value

A one-row tibble with `start`, `end`, `prev_start` and `prev_end` as
`Date`. A field the filing does not declare is `NA`. Where a filing
states a date more than once, the first is taken.

## The taxonomy's typo

The preceding period's end is `PredingReportingPeriodEndDate` – not
*Preceding*, which is how its own start date is spelled two elements
earlier. The misspelling is in the published taxonomy, so it is what
filings carry and what this looks for. Both spellings are accepted,
because a filer who corrects it should not be punished for it.

## How often it is there

Across 4,304 Danish filings from 2020-2024 every one declared its
current period, and 3,950 declared the preceding one – a filing states
both dates of a period or neither. So this is a reliable route rather
than a lucky one – but `NA` still comes back where a filing is silent,
and callers should have a fallback rather than assume.

## See also

[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md),
and
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
which uses this to pair an opening balance with the year its movements
cover.

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
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("filing.xml")
p <- xbrl_period(x)

# the opening balance of the year is the closing balance of the one before
p$prev_end
} # }
```
