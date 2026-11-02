# Put the tagging right: figures in the wrong unit, signs the wrong way

A filing tags each figure in kroner, and now and then a line is tagged
in thousands instead – most often in the comparative column, so that
last year's land and buildings of 2,981,848 reappears this year as
2,982. That is a technicality of the tagging, not a fact about the
company, and left in place it reads as the company's accounts changing
by a factor of a thousand. This finds such figures between filings and
puts them back.

## Usage

``` r
xbrl_standardise(x, what = c("units", "signs"), tol = 1)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).
  For units, several years of at least some companies. A company with
  one filing has no units to compare and keeps its figures.

- what:

  Which to standardise: `"units"`, `"signs"`, or both, the default.
  Units go first, because a figure in the wrong unit would make a
  statement fail to add up for a reason of its own.

- tol:

  Absolute tolerance, in the reporting currency, for whether an activity
  adds up. Default `1`.

## Value

`x`, with `value` corrected where a figure was in the wrong unit or had
its sign reversed, and the columns `value_tagged` and `standardised`
added. Attribute `"standardisation"` is a tibble with one row per figure
looked at: `kind` (`"unit"` or `"sign"`), the filing, the company, the
element, the date, the figure as tagged and as standardised, `action`
(`"corrected comparative"`, `"flipped sign"` or `"undecided"`) and
`detail`.

## Which figure is the wrong one

A figure stated in two filings that disagree by a power of a thousand
has two candidates for the mistake. A third figure can decide: the later
filing's own figure for the same line in its own year. If it is of the
earlier filing's order, the later filing disagrees with itself – its
comparative column is in a different unit from its own year – and that
is proof enough. The comparative is corrected.

The opposite case is not settled. When the later filing's two columns
agree and the earlier filing is the odd one, the earlier filing may be
wrong, or the later filing may be tagged in thousands throughout. The
two look the same from here. The figure is listed as undecided and left
as it is.

Over 4,304 filings for 2020-2024, 147 figures were corrected and 49 left
undecided. A filing with a corrected comparative typically had three
lines affected, about a sixth of its comparable balances: a column
tagged in the wrong unit, not a company reporting in thousands.

## What changes

The figure is multiplied or divided by the power of a thousand that
brings it into line, so its own digits are kept and only the unit moves.
Every copy of the fact moves with it: the same element, filing, date and
basis. `value_tagged` keeps the figure as tagged and `standardised` says
why it moved, on every row that did; elsewhere they are the value and
`NA`. Nothing else in the filing is touched.

## Signs in the cash flow statement

A line in investing or financing whose activity does not add up as
tagged, and does add up with that one line reversed, has its sign
reversed. The statement itself says which way the filer meant it. The
same test is made one level up, of the three activities against the
change in cash.

What is not touched is as important. A line whose activity adds up as
tagged keeps its sign, however its sign looks beside its element,
because then the sign means something. A sale of a company reported
negative in an investing activity that adds up with it – Greenland
Airports' grant taken to income, in its 2025 group accounts – is a
misclassification for the screen to find, not a sign to correct. Where
several lines would each make the activity add up, none is reversed and
the case is listed as undecided. Operating is left alone, because its
lines are the income statement's own facts.

## See also

[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
which finds these figures, and
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
which standardises before it screens.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md),
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
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md),
[`xbrl_report()`](https://dataniel.github.io/cvrr/reference/xbrl_report.md),
[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md),
[`xbrl_robustness()`](https://dataniel.github.io/cvrr/reference/xbrl_robustness.md),
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")
x <- xbrl_standardise(x)
attr(x, "standardisation")
x[!is.na(x$standardised), c("cvr", "elementid", "value_tagged", "value")]
} # }
```
