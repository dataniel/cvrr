# Give a filing's facts their names, place and sign convention

Joins facts from
[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
to the taxonomy they declare, so every reported figure arrives with the
statement it belongs to, a stable accounting code, its Danish label,
whether it is debit or credit, and whether it is the group's figure or
the parent company's.

## Usage

``` r
add_taxonomy(x, taxonomy = NULL, dimensions = TRUE)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

- taxonomy:

  A `cvrr_taxonomy` from
  [`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
  or a list of them. `NULL`, the default, uses the taxonomies packaged
  with cvrr – see
  [cvrr_taxonomy_tables](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md)
  – which covers 20121001 to 20251001 and needs nothing on disk. Pass a
  package only for a taxonomy those do not hold.

- dimensions:

  If `TRUE` (default), each dimension present in the data gets its own
  column holding the member that applies, named `dim_` plus the
  dimension's local name – `dim_ClassesOfPropertyPlantAndEquipment`,
  `dim_ConsolidatedSolo`. The prefix is how
  [`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md)
  finds them again without having to guess.

## Value

`x` with `statement`, `code`, `depth`, `label`, `is_total`, `is_leaf`,
`balance`, `periodtype`, `basis`, `basis_source`, `is_line` (whether the
fact is the statement line itself rather than a breakdown of it) and
`period` added.

## Details

[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
calls this itself unless told not to. Reach for it directly when the
filings need a taxonomy package the cvrr tables do not hold, or when the
facts were read once and are to be joined more than one way.

## The join key is the namespace, not the prefix

Filers bind namespace prefixes freely – `d`, `e`, `f`, `g`,
`EOGS_202040000` all appear – and the same letter means different
namespaces in different filings. Joining on the prefix looks equivalent
and silently attaches the wrong element definition, so the join runs on
the namespace URI.

## Parent company versus group

Consolidated figures are tagged with a member of
`ConsolidatedSoloDimension`. Parent-company figures are **not tagged at
all**, and reading their absence as "parent" is only legitimate because
the taxonomy declares a default member for that dimension. This function
reads the declared default rather than assuming one, and records in
`basis_source` whether the filing said so (`"tagged"`) or the default
decided it (`"default"`) – a figure that is the parent's only by default
is worth being able to find again.

## Codes

The code comes from the taxonomy's own numbering: the role URI gives the
statement (`.../role/400.00/BalanceSheetAccountForm`) and the
presentation arcs' `order` values give the levels, so
`400.00.020.010.020` is "Assets, non-current, property plant and
equipment" and sorts into statement order on its own.

## Nothing is dropped

A fact keeps its row whether or not the taxonomy has anything to say
about it. Two kinds do not:

- **Facts in no statement** – company data, the management's review, the
  auditor's report. They are the whole of what
  [`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md)
  reads, so dropping them would mean reading every filing twice. They
  come back with `statement` `NA`.

- **Facts whose taxonomy version is unknown**, because the filing
  declares an entry point newer than the packaged tables. Every taxonomy
  column is `NA` and one warning names the version, so a filing from a
  taxonomy this release has not caught up with degrades to its raw facts
  instead of disappearing.
  [`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md)
  on the published package fixes it.

## One row per statement

An element belongs to every statement that presents it, and many do:
`ProfitLoss` is the income statement's bottom line, the figure the
proposed distribution starts from, and a key figure. A fact therefore
comes back once per statement it appears in. Filter on `statement`
before working with a statement, and never sum across them.

## See also

[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md),
which calls this by default,
[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md)
for the tables built on top of it,
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md).

Other taxonomy:
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
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# normally not needed -- read_xbrl() does it
x <- read_xbrl("materiale/xbrl", taxonomy = FALSE)
x <- add_taxonomy(x)

# a taxonomy version the packaged tables do not cover
add_taxonomy(x, read_taxonomy("XBRL20251001.zip"))
} # }
```
