# Build an Elasticsearch query for CVR annual reports

Constructs the query body used by
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)
to look up published annual reports (offentliggoerelser) in
Erhvervsstyrelsens distribution service. Companies are matched by CVR
number and accounting-period end date. The function is pure: it only
builds a nested list and performs no network calls.

## Usage

``` r
cvr_query(cvr, enddate_from, enddate_to, size = 2999)
```

## Arguments

- cvr:

  A character or numeric vector of CVR numbers (8 digits each). At most
  1000 per query, so split larger sets into batches. Use
  [`clean_cvr()`](https://dataniel.github.io/cvrr/reference/clean_cvr.md)
  first for numbers with a `DK` prefix, spaces or dashes.

- enddate_from, enddate_to:

  Accounting-period end-date range as `"YYYY-MM-DD"` strings or `Date`s.
  Only reports whose period ends within the range (inclusive) are
  matched.

- size:

  Maximum number of hits the API should return. Default `2999`.

## Value

A nested list ready to be serialised as the JSON request body.

## Details

Greenlandic companies are covered by the same service and the same
8-digit CVR numbers as Danish ones. Greenland's own register (GER) was
folded into CVR on 3 January 2018, so filings from before then are not
reachable here under a CVR number.

The full pipeline is:

    cvr_query(cvr, from, to) |>
      cvr_search(contact = "you@example.com") |>
      cvr_hits() |>
      cvr_download("data/pdf")

## See also

[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md),
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)

Other cvr:
[`clean_cvr()`](https://dataniel.github.io/cvrr/reference/clean_cvr.md),
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md),
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)

## Examples

``` r
query <- cvr_query("12345678", "2024-01-01", "2024-12-31")
str(query, max.level = 3)
#> List of 2
#>  $ query:List of 1
#>   ..$ bool:List of 1
#>   .. ..$ must:List of 3
#>  $ size : num 2999
```
