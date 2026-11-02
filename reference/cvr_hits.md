# Extract CVR search hits as a tibble

Flattens the hits in a response from
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)
into a tibble with one row per document. Nested field names are reduced
to their last component and lowercased (e.g. `dokumenter.dokumentUrl`
becomes `dokumenturl`).

## Usage

``` r
cvr_hits(response)
```

## Arguments

- response:

  A parsed response list from
  [`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md).

## Value

A tibble with one row per document. Warns if the `cvrnummer` or
`dokumenturl` columns needed by
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)
are missing.

## Details

A hit holds one published annual report and a list of the files it
consists of – typically a PDF and an XBRL document. The rows are built
from that nested structure, one per file, with the report's own fields
repeated across them. Building them from a flattened vector instead
would misalign the moment one file omitted a field, because a flattened
vector keeps no record of which file a value came from.

## See also

[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md),
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)

Other cvr:
[`clean_cvr()`](https://dataniel.github.io/cvrr/reference/clean_cvr.md),
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md),
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
hits <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com") |>
  cvr_hits()
} # }
```
