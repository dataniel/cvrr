# Download CVR documents

Downloads the documents listed in a tibble from
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
one file per row. A delay between requests keeps the load on the API
polite.

## Usage

``` r
cvr_download(hits, path, sleep = 3, overwrite = FALSE, name_by = "cvrnummer")
```

## Arguments

- hits:

  A tibble with `cvrnummer` and `dokumenturl` columns, typically from
  [`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md).

- path:

  Directory to download into. Created automatically if it does not
  exist.

- sleep:

  Seconds to wait between downloads. Must be at least 1; the default of
  3 matches the API's expectations for bulk retrieval.

- overwrite:

  What to do about files that already exist. `FALSE` (default) aborts
  before downloading anything; `"skip"` leaves them alone and fetches
  the rest, which is how an interrupted bulk download is resumed; `TRUE`
  replaces them.

- name_by:

  Columns of `hits` to build each file name from, joined with `_`.
  Defaults to the CVR number alone, which means a company's filings for
  different years are told apart only by a `_2`, `_3` suffix in whatever
  order the API returned them. Pass `c("cvrnummer", "slutdato")` to name
  them by period instead.

## Value

`hits` with two columns added: `path`, the file each row was written to,
and `downloaded`, whether it arrived. Rows that failed keep their path,
so a second attempt can select them.

## Details

Each company-year typically lists several files (PDF, XML/XBRL,
sometimes XHTML), so filter the hits tibble before downloading if you
only need one format, e.g.
`hits[hits$dokumentmimetype == "application/xml", ]`.

## See also

[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md),
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
and
[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md)
for the machine-readable filings. A PDF filing has no parser here; it
goes through `taxmill`.

Other cvr:
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
files <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com") |>
  cvr_hits() |>
  cvr_download("data/pdf")

files[!files$downloaded, ]
} # }
```
