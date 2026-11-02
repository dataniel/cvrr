# The company behind a filing: who, how big, audited how, and doing what

The background a set of accounts needs to be usable as statistics –
identity, period, accounting class, auditor, employees, and the
management's own description of what the company does and how the year
went. One row per filing, ready to sit beside
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
and
[`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md).

## Usage

``` r
xbrl_company(x, persons = FALSE, prose = TRUE)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).
  Every field here is read as text, so this is the one table that still
  works on a filing whose taxonomy version the package does not know.

- persons:

  Include the names of the auditor, the executive and supervisory boards
  and the chairman of the general meeting. Off by default; see the
  section above.

- prose:

  Include the free-text fields – the activity description, the year's
  development, events after the reporting period and the expected
  development. They can run to thousands of characters. `FALSE` keeps
  the row narrow for a table of many companies.

## Value

A tibble with one row per filing, every field the filing carries about
itself. A field it does not state is `NA`.

- **Identity:** `cvr`, `name`, `form`, `founded`, `period_start`,
  `period_end`.

- **Where:** `street`, `postcode`, `city`, `country`,
  `registered_office`.

- **Size and class:** `reporting_class`, `class`, `micro`,
  `class_c_elements`, `employees`, `assets_not_owned`, `currency`.

- **Group:** `group_accounts` (the filing has consolidated figures) and
  `in_group` (the company is part of a group: balances with group
  enterprises, shares in them, a subsidiary's exemption under section
  78a, or a note on group accounts).

- **The report:** `report_type`, `general_meeting`, `approved`,
  `signature_place`, `submitter`, `submitter_cvr`, `xbrl_tool`,
  `policies_unchanged`.

- **The audit:** `auditor_assistance` as written and `assurance` as one
  of `"audit"`, `"extended review"`, `"review"`, `"compilation"` or
  `"none"`; `audit_firm`, `audit_firm_cvr`; `opinion` as written and
  `opinion_kind` as `"clean"`, `"qualified"`, `"adverse"` or
  `"disclaimer"`; `going_concern`, whether the auditor or the filing
  reports a material uncertainty about the company continuing;
  `auditor_signed`, `audit_exempt`.

Branch of industry is not in a filing, only in the CVR register. Join it
on `cvr` from a register extract of your own.

- With `prose`: `activity`, `activity_source`, `development`,
  `development_source`, `events_after`, `expected_development`,
  `mortgages`, `contingent_liabilities`.

- With `persons`: `auditor_name`, `auditor_id`, `auditor_description`,
  `executive_board`, `supervisory_board`, `chairman`.

`file` comes last: the path the row was read from.
[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md)
divides these into `company`, `location`, `audit` and `prose`.

## What a filing reliably carries

Measured over 4,304 Danish and Greenlandic filings. Present in every
one: the CVR number, the company's name, the accounting class, the type
of auditor's assistance and the reporting period; the date of the
general meeting is there in all but two. Then, in falling order: the
executive board's names (94%), the address (82%), what the company does
(79%), the audit firm and its CVR number (78%), how the year went (76%),
the average number of employees (74%), when the company was founded
(47%) and its registered office (45%). 99% say something about either
their activity or their year.

The two prose figures are what this function returns, not what any
single element carries – both fall back to a second element, and the
`_source` columns say which answered.

## The industry is not in the filing

The taxonomy has a place for it –
`IndustrySectorForEconomicActivitiesOfEntity` – and **not one filing of
4,304 uses it**. Nor does any use `SizeOfReportingEntityBySector`. A
company's industry has to come from the register instead, where it
arrives as a code and a label in one field. No column is returned for it
here, because a column that is empty in every row is worse than an
absent one: it invites the reader to conclude the industry is unknown
rather than that it was never asked for.

## The legal form is not in the filing either, but the name has it

The taxonomy has no element for the reporting entity's own legal form.
`RelatedEntityLegalForm` exists and is about the companies a filer is
related to; there is nothing that says whether this one is an A/S or an
ApS.

The name almost always does, because company law requires the form to be
part of it. Measured over 4,304 filings, 99.6% carry a recognisable one:
3,330 ApS, 786 A/S, 120 IVS, 41 foundations and a handful of K/S and
P/S. `form` is that reading.

The 17 that miss are mostly foundations named without "Fonden", and
companies whose form is a compound – "Ejendomsaktieselskabet Illuut" –
which is why the spelled-out Danish words are matched inside a word and
the abbreviations are not: "ApS" as a syllable is a coincidence,
"anpartsselskab" is not.

It is a reading of the name, not a reported fact, and it is here because
the alternative is every caller writing the same regular expression.
Where it matters, the register is the authority.

## The activity description, and where it actually sits

The obvious element –
`DisclosureOfMainActivitiesAndAccountingAndFinancialMatters` – is used
by 6% of filings. The one companies actually use is
`DescriptionOfPrimaryActivitiesOfEntity`, "virksomhedens væsentligste
aktiviteter", at 72%. Both are read, the first as a fallback for the
second.

`development` works the same way: the tagged description of the year at
54%, falling back to the management's review as a whole for a further
22% – which is a longer and looser text, so `development_source` says
which was taken.

## Two things the corpus taught this function

**A headcount tagged to the nearest thousand.** Six facts in 4,304
filings carry `decimals = "-3"` on the number of employees, and all six
are the two filings that state 151,000 or 2,286,000 employees. No
plausible fact carries it; the separation is exact. The filer's tool
applied the statement's thousands-scaling to a headcount, and the same
company states 2,296 in another year. Such a count is divided by a
thousand. It moved the corpus mean from 780 employees to 19.8, and the
maximum to Royal Greenland's real 2,296.

**The accounting class is written in the filing's own language.** 13
filings say "Reporting class B" where 4,112 say "Regnskabsklasse B",
which splits a grouping in two without anyone noticing.
`reporting_class` keeps the filing's own words – it is where
"mikrovirksomhed" is visible – and `class` carries just the letter,
which is the same in both languages.

## Persons

A filing names people: the auditor, the executive board, the chairman of
the general meeting. Those are personal data, and an accounts statistic
does not need them – the audit *firm* and its CVR number answer "who
audited this" without naming anyone. So they are left out unless asked
for. Set `persons = TRUE` where there is a reason, and keep in mind that
the result then carries names that should not be redistributed casually.

## See also

[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
which returns this beside the statements, and
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
for the figures.

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
xbrl_company(x)

# with the names of the people who signed
xbrl_company(x, persons = TRUE)
} # }
```
