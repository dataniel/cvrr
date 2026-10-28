# cvrr

[![R-CMD-check](https://github.com/dataniel/cvrr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/cvrr/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://dataniel.github.io/cvrr)

> **Experimental.** From a list of CVR numbers to analysable accounting
> data, in one package: search Erhvervsstyrelsens distribution service,
> download what it found, and parse the machine-readable filings. Danish and
> Greenlandic companies alike — Greenland's own register was folded into CVR
> in 2018, and its companies file under the same taxonomy. Split out of
> [daos](https://github.com/dataniel/daos), and named for the functions it
> has always been made of.

## Installation

```r
pak::pak("dataniel/cvrr")
```

## The whole route

```r
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
a$cash_flow         # the cash flow statement, as reported
a$movements         # the fixed asset note, movement by movement
a$prose             # what management wrote
```

Four functions to find and fetch, one to read, one to divide up. Nothing in
between is manual: no numeric conversion, no period argument, no binding the
filings together by hand.

Every table opens with the same key — `cvr`, `name`, `period_start`,
`period_end` — and ends with `file`, so moving between them needs no looking
and every figure can be traced back to the document it came from. The three
statements carry `reconciled` on every row, so filtering to the lines that
add up needs no join, and `checks` gathers the per-filing verdicts in one
place.

## Which filings are worth reading?

`xbrl_screen()` runs every check over a pile of filings and returns what
they found, one row per finding, ranked by how much it would change what a
reader takes from the accounts:

```r
s <- xbrl_screen(x)
s[s$severity == "high", ]
```

The checks cover a balance sheet that does not balance, an income statement
step no signs explain, a cash flow statement that does not add up or reports
borrowing the balance sheet does not owe, and figures that do not reopen in
the next year's filing: written in the other unit, or restated. Each finding
carries its amount and its share of total assets, so a rounding difference
at a large company does not outrank a real gap at a small one. Over 4,304
Danish and Greenlandic filings for 2020-2024, 532 have a finding and 54 a
serious one. In 41 of those 54 the serious finding is a figure written in
kroner one year and in thousands the next.

A finding is a reason to read the report, not a conclusion about it.

## A cash flow statement that adds up, and is still wrong

Greenland Airports' 2025 group accounts reported a DKK 400 million state
grant as new long-term borrowing. Every total in the cash flow statement
still added up, because moving an amount between activities leaves the
totals alone. `check_cashflow()` holds the statement against the balance
sheet, the income statement and the fixed asset note, and on that filing it
finds 364 million of borrowing the balance sheet does not owe. It also names
the line in investing that takes the same amount back out: a grant taken to
income, tagged in the XBRL as `SaleOfOtherCompany`.

```r
cf <- check_cashflow(x)
cf[cf$verdict == "borrowed more than owed", ]
```

## Two forms, one of them useful

A filing usually exists as both a PDF and an XML file. The XML is XBRL —
the machine-readable form — and `read_xbrl()` turns it into a tibble with
one row per reported fact: its value, its context dates, its unit, the
namespace that identifies it in the taxonomy, and every dimension the
context carries, `ConsolidatedSoloDimension` included.

The PDF is the human-readable version, and there is no parser for it here.
For older filings, small companies, and reports that are a scan of paper,
the PDF is the only digital trace, and turning one back into a table is a
different kind of work. That is what
[taxmill](https://github.com/dataniel/taxmill) is for.

## Signs

XBRL amounts often arrive without a meaningful sign: costs can be reported
as positive numbers, and the convention varies between preparers.
`find_signs()` recovers them, because an income statement has to
reconcile — it searches for the `+1`/`-1`/`0` assignment that makes the
line items sum to the reported total.

```r
find_signs(income, elementid, value,
           total_label = "ProfitLoss",
           by = c(cvr, period_end))
```

Nothing is dropped: every row comes back with a `status` of `unique`,
`ambiguous`, `unsolved`, `no_total` or `duplicate_total`, and items that
every candidate assignment agreed on are filled in even when the group as a
whole is ambiguous.

The search is tested against an exhaustive one, every assignment
enumerated, on random cases from kroner to a group's hundred billion. That
test found a precision fault that turned unique answers ambiguous on large
amounts, and the fault is fixed. There is no official answer to check it
against. In 13 versions of the Danish taxonomy, 2010-2025, the only
calculation linkbase is a 2020 income statement for one kind of education
institution. Erhvervsstyrelsen publishes no weights for the ordinary
statements. What the taxonomy does publish is each line's debit or credit
marking, and on 8,633 solved income statement lines the recovered sign
agrees with it 99.8% of the time.

## The taxonomy is where the meaning lives

An XBRL instance carries facts and no readable text at all: labels, the
statement hierarchy and the debit/credit markings are in the taxonomy the
filing names in one `schemaRef`. Point `read_taxonomy()` at the package
Erhvervsstyrelsen publishes and the rest follows.

```r
tax  <- read_taxonomy("XBRL20241001.zip")
tidy <- read_xbrl("data/xml/13645183_2024-12-31.xml") |>
  add_taxonomy(tax)

check_statement(tidy)
```

Every figure arrives with a stable accounting code from the taxonomy's own
numbering, its Danish label, whether it is debit or credit, and — decided by
the taxonomy's declared dimension default rather than by guesswork — whether
it is the group's figure or the parent company's.

## Using the service well

`cvr_search()` requires a `contact` email address and sends it as the
`User-Agent` header: Erhvervsstyrelsen asks requests to identify their
sender. The function refuses an empty contact, but it cannot check that the
address is honest — that part is yours. `vignette("cvrr")` covers the rest
of the habits worth having: query volume, `scroll` for complete results,
testing small first, and the legal frame around *reklamebeskyttelse*.

## Functions

In the order the route runs.

**Find and fetch**

| Function | Description |
|----------|-------------|
| `cvr_query()` | Build an Elasticsearch query for published annual reports |
| `cvr_search()` | Send a query to Erhvervsstyrelsens distribution service |
| `cvr_hits()` | Flatten a response into a tibble, one row per document |
| `cvr_download()` | Download the documents found by a search |

**Read, and divide up**

| Function | Description |
|----------|-------------|
| `read_xbrl()` | Read one filing, a list of them, or a directory, into one tibble with the taxonomy on it |
| `xbrl_accounts()` | The filings divided into nine keyed tables: the company, where it is, the audit trail, the checks, the three statements, the fixed asset note and the prose |
| `xbrl_company()` | The company behind a filing: identity, legal form, class, auditor, employees, activity |
| `xbrl_lines()` | One statement, line by line, in statement order |
| `xbrl_movements()` | The fixed asset note as a roll-forward: cost, depreciation and revaluation at each end of the year, and the movements between |

**Name and place the facts**

| Function | Description |
|----------|-------------|
| `add_taxonomy()` | Give a filing's facts their statement, code, label and sign convention |
| `read_taxonomy()` | Open a taxonomy package and read its catalog, labels and defaults |
| `cvrr_line`, `cvrr_entry` | Twelve taxonomies as tables, so no package is needed on disk |
| `xbrl_fill()` | Derive the subtotals and components a filing left out |
| `xbrl_resolve()` | Choose between two figures reported for the same line |
| `xbrl_period()` | Read the accounting period a filing declares for itself |
| `xbrl_note_tables()` | Read the tables inside a filing's text notes |

**Does it add up?**

| Function | Description |
|----------|-------------|
| `xbrl_screen()` | Every check over a pile of filings, findings ranked by how much they matter |
| `check_statement()` | Reconcile every subtotal against the lines below it |
| `check_cascade()` | Reconcile an income statement step by step to the result for the year |
| `check_cashflow()` | Reconcile a cash flow statement, and tie it to the balance sheet, the income statement and the fixed asset note |
| `check_breakdown()` | Reconcile a dimensional breakdown against the line it breaks down |
| `check_movement()` | Reconcile an opening balance and its movements to the closing balance |
| `check_continuity()` | Does the balance a company closed on reopen in the next filing? |
| `check_inclusion()` | Find lines a note says are contained in another |
| `find_signs()` | Recover the signs that reconcile line items to a total |

## Where the package stops

cvrr hands out the accounting figures the filings actually carry, with the
label, the code and the sign convention the taxonomy gives them. Mapping those
onto a particular statistic's variable definitions is yours to make: which
element counts as turnover depends on the definitions in force, and a package
that decided it for you would be wrong the year they changed.

