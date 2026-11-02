# Screen a pile of filings for the ones worth reading

Runs the package's checks over every filing in `x` and returns what they
found, one row per finding, ranked so that the filings worth a closer
look come first. It is the question to ask of a corpus before trusting
it, or of a company before reading its report: where does this not add
up, and how much does it matter?

## Usage

``` r
xbrl_screen(
  x,
  basis = c("parent", "consolidated"),
  what = c("auditor", "balance", "income", "cashflow", "continuity"),
  materiality = 0.01,
  standardise = TRUE
)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md):
  any number of filings, any number of companies. Several years of the
  same company add the checks between filings. From
  [`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md),
  the checks it ran are read rather than run again.

- basis:

  `"parent"` and `"consolidated"`, the default, screens both; a group's
  cash flow statement is usually only consolidated.

- what:

  Which checks to run: any of `"auditor"`, `"balance"`, `"income"`,
  `"cashflow"` and `"continuity"`. All of them by default.

- materiality:

  Share of total assets under which a finding moves down a level.
  Default `0.01`.

- standardise:

  Put the tagging right before screening, with
  [`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md):
  figures in the wrong unit, and cash flow signs an activity adds up
  only reversed. Default `TRUE`. See the section below.

## Value

A tibble with one row per finding, most severe and largest first: the
key (`cvr`, `name`, `period_start`, `period_end`), `basis`, `check`,
`finding`, `amount` (the gap in the reporting currency, where the check
gives one), `share` (`amount` against total assets), `severity`,
`detail` (what the check said, in its own words), the filing's
background – `class`, `form`, `assurance`, `in_group`, `group_accounts`,
from
[`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md)
– and `file`. Filings with no finding have no rows;
`attr(s, "screened")` says how many were looked at. It prints as one
line per filing, its most serious finding first; the rows underneath are
an ordinary tibble.

## What it looks for

Each finding comes from a check that can be run on its own, and `check`
names it:

- `"auditor"` – the auditor qualified the opinion, gave an adverse one
  or none at all, or drew attention to a material uncertainty about the
  company continuing as a going concern
  ([`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md)).
  The first three are an auditor saying the accounts are wrong or cannot
  be judged, and rank with the arithmetic; the last is a risk, not an
  error.

- `"balance sheet"` – the debit side does not equal the credit side, or
  one line is stated twice with two amounts
  ([`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)).

- `"income statement"` – a step of the cascade that no assignment of
  signs explains
  ([`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)).

- `"cash flow"` – the statement does not add up, does not roll the cash
  forward, or closes on a cash figure the balance sheet does not carry;
  or it reports borrowing the balance sheet does not owe, the pattern of
  a grant booked as a loan
  ([`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md)).

- `"between filings"` – a balance that reopened on a different amount in
  the next filing
  ([`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md)).
  Income statement comparatives are left out, because they are
  reclassified routinely. With `standardise = FALSE`, also a figure
  written in the other unit.

## The tagging first, the accounts second

A figure tagged in thousands where the filing is in kroner is a fact
about the tagging, not about the company. Screened as it stands it
outranks every real finding: in a 4,304-filing corpus, 41 of the 54
serious findings were that, and once the figures are standardised the 13
left are all cash flow statements that do not add up. So by default the
figures are standardised first, and the screen looks at the accounts as
they were meant. What was corrected, and what could not be settled, is
kept apart in `attr(s, "technical")` and named in one line when the
screen prints. `standardise = FALSE` screens the figures as tagged, and
then a figure in the other unit is a finding of its own.

## How it ranks

By how much a finding would change what a reader takes from the
accounts. `share` is the amount against the filing's total assets, and
`severity` combines the kind of finding with its size:

- `"high"` – an auditor's qualified, adverse or missing opinion, or the
  statements do not hold together: a balance sheet whose sides differ, a
  cash flow statement that does not add up, or borrowing the balance
  sheet does not owe with its other half found elsewhere in the
  statement. Unstandardised, also a figure off by a factor of a
  thousand.

- `"medium"` – a going concern uncertainty, or something is unexplained
  but the statements still close: borrowing without debt to match, an
  income statement step no signs explain, a line stated with two
  amounts.

- `"low"` – a lead: a figure restated between filings.

A finding under `materiality` of total assets moves down one level, so a
rounding difference on a large company does not sit above a real one on
a small company, and one that ends at `"low"` that way is left out. A
finding with no amount keeps its level.

## What it does not do

A finding is a reason to read the report, not a conclusion about it.
Every one has an innocent explanation as well as a guilty one, and the
checks cannot tell them apart: a restatement can be a correction of
policy or of an error, borrowing without debt can be a facility drawn
and repaid within the year. The function says where to look.

It does not look at the prose or at anything the filing did not tag. A
misstatement that is consistent everywhere, scaled or restated
throughout, is invisible inside one filing and is found only between
filings, so pass several years to see that kind.

## See also

[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
whose `checks` table answers the same questions as yes or no;
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md)
and
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md)
for the detail behind a finding.

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
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md),
[`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")
s <- xbrl_screen(x)
s

# the filings with something serious, one row each
s[s$severity == "high" & !duplicated(s$file), ]
} # }
```
