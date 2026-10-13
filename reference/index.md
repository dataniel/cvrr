# Package index

## Start here

- [`cvrr`](https://dataniel.github.io/cvrr/reference/cvrr-package.md)
  [`cvrr-package`](https://dataniel.github.io/cvrr/reference/cvrr-package.md)
  : cvrr: from CVR numbers to accounting data

## Find and fetch published reports

- [`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md)
  : Build an Elasticsearch query for CVR annual reports
- [`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)
  : Send a query to the CVR distribution service
- [`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md)
  : Extract CVR search hits as a tibble
- [`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)
  : Download CVR documents

## Read the filings

- [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
  : Read XBRL filings
- [`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md)
  : A pile of filings as the tables an analysis reads

## One table at a time

- [`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md)
  : The company behind a filing: who, how big, audited how, and doing
  what
- [`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md)
  : A statement, line by line
- [`xbrl_movements()`](https://dataniel.github.io/cvrr/reference/xbrl_movements.md)
  : The fixed asset note, movement by movement

## Name and place the facts

- [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
  : Give a filing's facts their names, place and sign convention
- [`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md)
  : Read an XBRL taxonomy package
- [`cvrr_taxonomy_tables`](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md)
  [`cvrr_line`](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md)
  [`cvrr_entry`](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md)
  [`cvrr_default`](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md)
  : The Danish annual report taxonomies, as tables
- [`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md)
  : Derive the figures a filing left out
- [`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)
  : Choose between two figures reported for the same line
- [`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md)
  : The accounting period a filing declares
- [`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md)
  : Read the tables inside a filing's text notes

## Does it add up?

- [`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
  : Reconcile a statement against its own hierarchy
- [`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
  : Reconcile an income statement step by step
- [`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md)
  : Reconcile a dimensional breakdown against the line it breaks down
- [`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md)
  : Reconcile an opening balance and its movements to the closing
  balance
- [`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md)
  : Does the balance a company closed on reopen in the next filing?
- [`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md)
  : Find lines a note says are contained in another line
- [`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
  : Find sign combinations that sum to a target
