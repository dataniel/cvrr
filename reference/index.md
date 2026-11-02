# Package index

## Start here

- [`cvrr`](https://dataniel.github.io/cvrr/reference/cvrr-package.md)
  [`cvrr-package`](https://dataniel.github.io/cvrr/reference/cvrr-package.md)
  : cvrr: from CVR numbers to accounting data

## Find and fetch published reports

- [`clean_cvr()`](https://dataniel.github.io/cvrr/reference/clean_cvr.md)
  : Standardise CVR numbers
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

## Analyse

- [`xbrl_validate()`](https://dataniel.github.io/cvrr/reference/xbrl_validate.md)
  : Validate the filings once, and carry the work along
- [`xbrl_panel()`](https://dataniel.github.io/cvrr/reference/xbrl_panel.md)
  : The filings as a panel: one row per company and year
- [`xbrl_ratios()`](https://dataniel.github.io/cvrr/reference/xbrl_ratios.md)
  : Key ratios, the change from last year, and the place among peers
- [`xbrl_robustness()`](https://dataniel.github.io/cvrr/reference/xbrl_robustness.md)
  : How robust a company is, and what it could withstand

## Report

- [`xbrl_report()`](https://dataniel.github.io/cvrr/reference/xbrl_report.md)
  : Write a report on the filings as one HTML page
- [`xbrl_report_data()`](https://dataniel.github.io/cvrr/reference/xbrl_report_data.md)
  : What a report on these filings would say, as data

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

- [`xbrl_screen()`](https://dataniel.github.io/cvrr/reference/xbrl_screen.md)
  : Screen a pile of filings for the ones worth reading
- [`xbrl_standardise()`](https://dataniel.github.io/cvrr/reference/xbrl_standardise.md)
  : Put the tagging right: figures in the wrong unit, signs the wrong
  way
- [`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md)
  : Reconcile a statement against its own hierarchy
- [`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
  : Reconcile an income statement step by step
- [`check_cashflow()`](https://dataniel.github.io/cvrr/reference/check_cashflow.md)
  : Reconcile a cash flow statement, and tie it to the balance sheet
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
