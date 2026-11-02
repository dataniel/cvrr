# Validate the filings once, and carry the work along

Standardises the facts and runs everything the analysis functions need –
who each company is, the checks of the three statements, and the
statements line by line on both bases – and returns the facts with that
work attached.
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
and
[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md)
read it instead of doing it again, so a pipeline pays for the expensive
part once:

## Usage

``` r
xbrl_validate(x)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

## Value

`x`, standardised by
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md),
of class `cvrr_validated`, with the work in `attr(v, "validated")`:
`company`
([`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md)
without prose), `statement`, `cascade` and `cashflow` (the checks),
`lines` (from
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
by basis and statement) and the fingerprints.

## Details

    v <- read_xbrl("materiale/xbrl") |>
      xbrl_validate()
    s <- xbrl_screen(v)
    p <- xbrl_panel(v)
    xbrl_report(xbrl_report_data(v, cvr = "12345678"), "12345678.html")

## Why the facts and not a panel

A panel is one row per company and year and a few dozen variables, and
that is a view, not the data. It leaves out the dimensions and the
notes, every line beyond its variables, where each figure came from –
reported, derived or corrected – the comparatives the unit check reads,
and the auditor's text. So the validated object stays the facts, one row
per fact as
[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
gave them, and the panel is cut from it when asked for.

It is an ordinary tibble, and everything that takes facts takes it.

## When the work still applies

The work is per filing, so a subset of whole filings keeps it:
`v[v$cvr == "12345678", ]` is still validated, for that company. Each
filing's facts are fingerprinted – the number of rows and the sum of the
values – and a filing whose facts no longer match is not trusted: change
a value, or drop some of a filing's rows, and the functions do the work
again from the facts as they stand. Nothing stale is read, and nothing
has to be remembered.

Standardising compares a filing with the company's later filings, and
that comparison was made on everything validated together. A subset
keeps its corrections, which were made with more information than the
subset has.

## See also

[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md),
[`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md),
[`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md),
[`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md).

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
[`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md)
