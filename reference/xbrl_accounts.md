# A pile of filings as the tables an analysis reads

Takes the fact table from
[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
and divides it: who the company is, where it is, how the report was
audited, what its statements say, what its fixed asset note shows,
whether any of it adds up, and what management wrote. One named list of
tibbles, every one of them opening with the same key, so that moving
between them needs no looking.

## Usage

``` r
xbrl_accounts(
  x,
  what = NULL,
  basis = c("parent", "consolidated"),
  persons = FALSE,
  taxonomy = NULL
)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

- what:

  Which tables to build. Any of `"company"`, `"audit"`, `"location"`,
  `"checks"`, `"income_statement"`, `"balance"`, `"movements"` and
  `"prose"`; all eight by default.

- basis:

  `"parent"` (default) or `"consolidated"`, for the statements and the
  note. An untagged figure is the parent's – see
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- persons:

  Include the names of the auditor, the boards and the chairman in
  `audit`. Personal data, so off by default – see
  [`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md).

- taxonomy:

  Passed to
  [`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md).
  `NULL` uses the packaged tables.

## Value

A list of tibbles of class `cvrr_accounts`, named by `what` and in that
order. The filings that could not be read are carried through in
`attr(a, "failed")`.

## The key comes first, and is the same everywhere

`cvr`, `name`, `period_start`, `period_end`, in that order, at the front
of every table, and `file` at the back of it – the key is what a reader
joins and groups on, and the file name is what a figure is traced back
to. `name` is repeated rather than left to a join: R keeps one copy of
each distinct string and a pointer per row, so 127,000 balance sheet
lines cost about a megabyte for never having to fetch a company's name
in order to read its figures.

## Why eight tables and not one

The company row is 40 columns wide and they answer different questions.
`development` runs to 486 characters in the median filing, so keeping
the prose beside the accounting class means every glance at the class
drags a paragraph with it. And the verdicts are not attributes of a
company at all; they are what the checks concluded about one filing.

- `company`:

  Who this is: legal form, when it was founded, accounting class,
  employees, currency.

- `location`:

  Where it is: street, postcode, city, country and the registered office
  it states.

- `audit`:

  How the report came to be, and how far to trust its tagging: who
  audited it and with what opinion, who submitted it, when it was
  approved, and which tool wrote the XBRL. With `persons`, the names
  that signed it.

- `checks`:

  What the checks concluded, one row per filing.

- `income_statement`:

  One row per line, in statement order, as reported. See
  [`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md).

- `balance`:

  One row per line, with the lines the filer left out derived and marked
  in `source`. See
  [`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md).

- `movements`:

  The fixed asset note, one row per movement per asset class. See
  [`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md).

- `prose`:

  What management wrote: the activity, the year's development, events
  after the reporting period, mortgages and contingent liabilities.

`what` builds only the tables named, and skips the work they do not
need: the checks are the expensive part, and `what = "company"` still
runs them because that row reports their verdicts, while
`what = "location"` runs none of them.

## Whether it adds up

`income_statement` and `balance` carry `reconciled` on every row, so the
commonest filter – give me only the lines that add up – needs no join.
`movements` carries four verdicts of its own. And `checks` gathers the
per-filing conclusions in one place, at the grain the question is asked:

- `balance_reconciled` – the balance sheet's debit side equals its
  credit side, from
  [`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md).

- `income_reconciled` – no step of the income statement's cascade is
  left unexplained, from
  [`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md).

- `movements_reconciled` – every block of the fixed asset note that
  could be checked rolls forward.

- `movements_cover` – the notes together account for the fixed assets
  the balance sheet carries.

They are four columns and never one verdict, because a filing can pass
any of them and fail the rest: a balance sheet that closes says nothing
about whether the income statement does, and a fixed asset schedule that
rolls forward perfectly for land and buildings says nothing about the
machinery it never mentions. `NA` means there was nothing of that kind
to check, which is not the same as failing.

Each is a summary of something you can go and look at:
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
on one filing's facts gives the income statement's steps one row each,
and `movements` gives the note's blocks one row per movement.

## See also

[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
for what goes in,
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
[`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md)
and
[`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md)
for the tables one at a time,
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
and
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
for the detail behind `reconciled`.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
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
a <- xbrl_accounts(x)
a

a$balance
subset(a$income_statement, reconciled)

# the tables join on the key they share
merge(a$checks, a$audit)

# just the one table, and only the work it needs
xbrl_accounts(x, what = "company")
} # }
```
