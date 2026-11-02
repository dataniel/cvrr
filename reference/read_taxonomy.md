# Read an XBRL taxonomy package

Opens a taxonomy package – a ZIP, or a directory already unpacked from
one – and returns the object
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
needs to give a filing's facts their names, their place in a statement,
and their sign convention.

## Usage

``` r
read_taxonomy(path, exdir = NULL)
```

## Arguments

- path:

  Path to a taxonomy package `.zip`, or to a directory holding an
  unpacked one.

- exdir:

  Directory to unpack a ZIP into. Defaults to a session temporary
  directory; give a stable path to unpack each package only once. On
  Windows keep it short: the deepest names inside a Danish package are
  long enough that a long `exdir` pushes the total past the
  260-character path limit.

## Value

An object of class `cvrr_taxonomy`: a list with `version`, `path`,
`entrypoints` (the entry point schemas it offers), `defaults` (the
member that applies when a dimension is absent) and the internals
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
uses.

## Why this is a separate step

An XBRL instance carries facts, contexts and units and no readable text
at all. Every label, every statement hierarchy, every debit/credit
marking lives in the taxonomy the filing names in one `link:schemaRef`.
That URI is an *identifier*, not a download address – for Danish filings
the host it points at answers 404 – so the package has to be obtained
separately and resolved locally. `META-INF/catalog.xml` holds the
rewrite rules that map the URI onto a path inside the archive, and this
function follows them.

Get the Danish packages from Erhvervsstyrelsen's *Taksonomier, aktuelle*
and *Taksonomier, historiske* pages. One package per year is needed: the
version a filing declares follows when it was *prepared*, not its
accounting year, so a single year of accounts routinely spans several.

## An archive without a catalog

Some archives in circulation are repacks and carry no
`META-INF/catalog.xml` – the 20171001 taxonomy is only obtainable that
way, and 31 filings of a 4,304-filing corpus declare it.

All the catalog does for these packages is map
`http://archprod.service.eogs.dk/taxonomy/<version>/` onto the directory
the files sit in, and the archive states the version in its own layout.
Where there is no catalog that mapping is reconstructed from the entry
point schemas' location, and a warning says so: it is a convention read
off the archive, not a rule the archive declared.

## See also

[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
to join a filing's facts to it,
[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
to read the filing.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
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
tax <- read_taxonomy("XBRL20241001.zip")
tax$entrypoints
tax$defaults
} # }
```
