# cvrr: from CVR numbers to accounting data

Danish annual reports are public documents, and Erhvervsstyrelsen
publishes them through a free distribution service. `cvrr` is the route
from a list of CVR numbers to data you can analyse: build a query, send
it, flatten the response, download the documents, and parse the
machine-readable ones.

## The pipeline

Six calls from a list of CVR numbers to the tables an analysis reads.
Each takes what the previous one returned.

    library(cvrr)

    cvr_query(
      cvr          = c("12345678", "87654321"),
      enddate_from = "2020-01-01",
      enddate_to   = "2024-12-31"
    ) |>
      cvr_search(contact = "you@example.com") |>
      cvr_hits() |>
      cvr_download("materiale/xbrl")

    # a whole directory, taxonomy and all
    x <- read_xbrl("materiale/xbrl")

    a <- xbrl_accounts(x)
    a$company           # who the company is
    a$location          # where it is
    a$audit             # who audited it, who filed it, with what tool
    a$checks            # whether any of it adds up
    a$income_statement  # lines, in statement order
    a$balance           # lines, with the ones the filer left out derived
    a$movements         # the fixed asset note, movement by movement
    a$prose             # what management wrote

Every table opens with the same key – `cvr`, `name`, `period_start`,
`period_end` – so moving between them needs no looking.

Everything else in the package is either a step of that route taken on
its own, or a way of asking whether a filing's figures add up.

## Two forms, one useful

A filing usually exists as both a PDF and an XML file. The XML is XBRL,
the machine-readable form, and
[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
turns it into a tibble with one row per reported fact, its context and
its unit. That is the whole route: no manual step.

The PDF is the human-readable version, and there is no parser for it
here. For older filings, small companies, and scanned reports it is the
only digital trace, and turning one back into a table is a different
kind of work – `taxmill` is about that.

## What the filing does not say

An instance carries facts, contexts and units – and no readable text.
Every label, the statement hierarchy, and the debit/credit marking of
each element live in the taxonomy the filing names in a single
`schemaRef`. That URI is an identifier, not a download address, so the
package is obtained separately and resolved locally:
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md)
opens it,
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
joins a filing to it, and
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
reconciles the result.

It also settles a question the instance answers only by omission. Group
figures are tagged; parent-company figures are not tagged at all, and
reading their absence correctly depends on the dimension default the
taxonomy declares.

## Signs

XBRL amounts often arrive without a meaningful sign: costs can be
reported as positive numbers, and the convention varies between
preparers.
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
recovers them, because an income statement has to reconcile – it
searches for the `+1`/`-1`/`0` assignment that makes the line items sum
to the reported total. It knows nothing about XBRL and works on any
labelled values with a total.

## Using the service well

[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)
requires a `contact` email address and sends it as the `User-Agent`
header, because Erhvervsstyrelsen asks requests to identify their
sender. The function refuses an empty contact, but it cannot check that
the address is honest – that part is yours.
[`vignette("cvrr")`](https://dataniel.github.io/cvrr/articles/cvrr.md)
covers the rest of the habits worth having: query volume, `scroll` for
complete results, testing small first, and the legal frame.

## The functions

- **Find and fetch:**
  [`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
  [`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md),
  [`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
  [`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)

- **Read:**
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
  – one filing, a list of them, or a directory, with the taxonomy
  resolved on the way in

- **Divide up:**
  [`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
  and
  [`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md),
  [`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
  and
  [`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md)
  for one table at a time

- **Name and place:**
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
  [`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
  [cvrr_taxonomy_tables](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md)

- **Derive:**
  [`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md)
  and
  [`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md),
  which
  [`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
  uses and which can be run on their own

- **Reconcile:**
  [`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
  [`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
  [`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
  [`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
  [`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
  [`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
  [`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)

- **Read the notes:**
  [`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
  [`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md)

The package stops at the accounting figures. Mapping them onto a
statistic's own variable definitions is the user's to make, and depends
on the definitions in force.

## See also

Useful links:

- <https://dataniel.github.io/cvrr>

- <https://github.com/dataniel/cvrr>

- Report bugs at <https://github.com/dataniel/cvrr/issues>

## Author

**Maintainer**: Daniel Madsen <danielmadsen@live.dk>

Authors:

- Daniel Madsen <danielmadsen@live.dk>
