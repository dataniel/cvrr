# Read XBRL filings

Reads one filing, a vector of them, or a whole directory, and returns a
single tibble with one row per reported fact. The taxonomy is resolved
as the filings are read, so labels, the statement hierarchy and the
debit/credit marking arrive with the facts rather than in a second step.

## Usage

``` r
read_xbrl(path, taxonomy = TRUE, recurse = TRUE, encoding = "UTF-8")
```

## Arguments

- path:

  A directory, a path to a single filing, or a vector of either.
  Directories contribute every `.xml` file they hold.

- taxonomy:

  Resolve the taxonomy while reading. `TRUE`, the default, uses the
  tables packaged with cvrr – see
  [cvrr_taxonomy_tables](https://dataniel.github.io/cvrr/reference/cvrr_taxonomy_tables.md).
  Pass a `cvrr_taxonomy` from
  [`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md)
  for a version those do not cover, or `FALSE` for the facts alone;
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
  does the same job afterwards.

- recurse:

  Descend into subdirectories. Default `TRUE`, because filings are
  usually filed by year.

- encoding:

  Character encoding of the files. Defaults to `"UTF-8"`.

## Value

A [`tibble`](https://tibble.tidyverse.org/reference/tibble.html) with
one row per fact: `file`, `cvr`, `period_start`, `period_end`,
`prev_start`, `prev_end`, `elementid` (local name), `prefix` and
`namespace`, `contextid`, `fact` (the text as tagged) and `value` (the
same figure as a number, `NA` where the fact is text), `unitid`, `unit`,
`decimals`, `schemaref`, `startdate`, `enddate`, `instant`, `dimensions`
and `explicit_member`. With `taxonomy`, the columns
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
adds. Dates are `Date`.

## What an instance does and does not contain

An XBRL instance holds facts, contexts and units – and no human-readable
text at all. That is by design: the meaning of every element lives in
the *taxonomy* the filing points to with a single `link:schemaRef`.
Labels, the statement hierarchy and the debit/credit balance are
published there, and
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
is what joins them on. XBRL also has a place for calculation weights,
and the Danish taxonomy leaves it empty for the ordinary statements –
see
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md).

Because the taxonomy is keyed by qualified name, the element's namespace
is returned alongside its local name. A Danish filing binds six or more
namespaces at once (`fsa` for the financial statements, `gsd` for
company data, `mrv` for management's review, `arr` for the auditor's
report, ...), and `elementid` alone cannot be looked up.

## Many filings, one table

Every row carries the filing it came from: `file`, `cvr` and the four
dates of `period_start`, `period_end`, `prev_start` and `prev_end`. That
is what makes a directory of filings usable as one table, and it is why
nothing downstream takes a `period` argument any more – the period is a
column.

Binding filings needs `fill`: each contributes only the dimension
columns it actually uses, so a filing tagging classes of equity has a
`dim_ClassesOfEquity` column and one that does not, does not.
`do.call(rbind, ...)` fails on that, which is reason enough for this
function to do the binding itself.

A filing that cannot be parsed does not stop the read. Its path is
collected and all of them are reported once at the end, in
`attr(x, "failed")`.

## Amounts are absolute

A monetary fact is stated in its `unit` – kroner, not thousands. The
`decimals` attribute says how *precise* the figure is, not what scale it
is on: `decimals = "-3"` means accurate to the nearest thousand, and the
value is still in kroner. The "tkr." at the head of a printed note is a
presentation choice for the human-readable text and does not reach the
tags.

Confirmed against a filing whose note prints its fixed assets as
`62.113` with the column headed tkr.: the tagged figure is `62113000`.

A filing scaled wrong throughout is harder to catch than that, because
it stays internally consistent: its balance sheet still balances and its
income statement still reconciles. Registered capital looks like a check
– an A/S must hold 400,000 kr, an ApS 40,000 – but it only works for the
A/S. Danish entrepreneur companies (IVS) could be founded on a single
krone until the form was abolished in 2021, and 75 filings in a corpus
of 4,304 report capital under 1,000 kr with entirely ordinary assets.
They are not scaled; they are IVS, and the filing does not state its own
legal form.

What does catch it is a ratio between two reported figures that has to
fall in a known range. Payroll divided by the employee count is the
readiest one: a year of work costs somewhere between 100,000 and
1,500,000 kr, and a filing claiming 194 kr has scaled one of the two.

## Dimensions

A context may carry several `explicitMember` elements, and in Danish
filings roughly a fifth of them do. One of the common pairs is
`ConsolidatedSoloDimension`, which says whether a figure is the group's
or the parent's alone – so keeping only the first member would silently
mix consolidated and solo amounts. All members are returned in
`explicit_member`, semicolon-separated, with the dimension each belongs
to in `dimensions` in the same order.

## See also

[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md)
for the tables this feeds,
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
to resolve the taxonomy separately,
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)
for fetching the filings.

## Examples

``` r
if (FALSE) { # \dontrun{
# a whole directory, taxonomy and all
x <- read_xbrl("materiale/xbrl")

# one filing, facts only
read_xbrl("13645183_2024-12-31.xml", taxonomy = FALSE)
} # }
```
