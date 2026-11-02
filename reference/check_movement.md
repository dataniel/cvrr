# Reconcile an opening balance and its movements to the closing balance

Equity, fixed assets, provisions: an annual report is full of schedules
that start from last year's figure, add and subtract during the year,
and end at this year's. This checks that each one arrives where it says
it does.

## Usage

``` r
check_movement(
  x,
  statement = NULL,
  period = NULL,
  assume_nil = FALSE,
  by = NULL,
  tol = 1
)
```

## Arguments

- x:

  A tibble from
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- statement:

  Restrict to these statements. `NULL` (default) checks every
  presentation group that has the shape of a schedule – see the section
  below on what that includes.

- period:

  The filing's declared accounting period, from
  [`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md).
  Optional, and worth passing: it settles which year the schedule covers
  and which instant is its opening balance, where without it both are
  inferred from the movements' own dates.

- assume_nil:

  Read a single absent balance as zero. See the section below; the
  result marks every schedule this applies to.

- by:

  Columns identifying one schedule beyond its own group and dimension.
  Defaults to `"basis"`; add the company identifier for a panel.

- tol:

  Absolute tolerance in the reporting currency. Default `1`.

## Value

A tibble with one row per schedule: the `by` columns, `group` (the
presentation code the schedule sits under), `dimension` and `member`
where the schedule is broken down, `opening`, `closing`, `n_movements`,
`n_zero` (movements reported as nil, which are excluded from the search
because they say nothing about their own sign), `movements` (whether
they were tagged at this level or summed over the classes below it),
`balances` (whether both were reported or one was assumed nil), and
`status` from
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md).

## Why nothing else catches this

Every other check in the package compares like with like.
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
compares instants to instants,
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
compares durations to durations, and neither touches the identity that
binds them:

    opening (instant) + movements (duration) = closing (instant)

That identity is where a schedule can be wrong while every other figure
in the filing is right – and it is the only place a company states its
investment for the year, which is the figure national accounts want.

## The signs are the filer's

A schedule arrives without a usable sign convention. `DisposalsOf...` is
reported positive and must be subtracted; the reversal of depreciation
on those same disposals is reported negative and must be added, in the
same note. So the movements are handed to
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
with the closing balance as the total and the opening balance pinned
positive – the identity decides the signs, and a schedule that admits no
unique assignment is reported as such rather than guessed at.

## Shape is not intent

Nothing in the Danish taxonomy marks a presentation group as a
roll-forward, so this recognises one by its shape: a single balance
reported at both ends of the period, with movements over that period
beside it. Two kinds of group have that shape without the meaning.

A five-year summary (`KeyFiguresAndFinancialRatios`) sets assets,
equity, capital and provisions side by side at two dates each; nothing
says which of them the profit in the same group is supposed to explain.
Groups holding more than one balance are therefore skipped outright.

A disclosure note (`DisclosureOfRelatedParties`) quotes equity and
profit as context, and that pair *is* the shape of a schedule – but the
note omits every other movement, so the identity cannot close and
reports a failure that says nothing about the filing. Shape alone cannot
tell it from a real equity statement. Pass `statement` to scope the
check where a schedule is actually meant: `StatementOfChangesInEquity`
and the asset notes.

## A balance that is simply blank

By default a schedule is checked only where the balance is reported at
both dates. That is the strict reading, and it is often too strict: an
asset class that started or ended at nothing is routinely left blank
rather than tagged as nil.

`assume_nil = TRUE` reads one absent balance as zero – one, never both,
since a schedule missing both ends is not a schedule. The result says so
in `balances`, because an assumed nil must not travel as a reported one.

What it will not do is infer the *opening* balance from the identity
itself. That would make the check confirm its own assumption, and every
schedule would reconcile.

A group holding two elements that each appear at both dates is not one
schedule and is skipped whatever this is set to.

## See also

[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md),
which resolves the signs, and
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
which checks the same schedules across a dimension rather than through
time.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
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
m <- check_movement(x)

# the schedules that do not arrive where they say
m[m$status != "unique", ]
} # }
```
