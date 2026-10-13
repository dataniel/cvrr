# Send a query to the CVR distribution service

Posts a query built with
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md)
to Erhvervsstyrelsens distribution service and returns the parsed JSON
response. Pass the result to
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md) to
extract the hits as a tibble.

## Usage

``` r
cvr_search(
  query,
  contact,
  scroll = FALSE,
  sleep = 1,
  retries = 3,
  timeout = 120,
  url = "http://distribution.virk.dk/offentliggoerelser/_search"
)
```

## Arguments

- query:

  A query list, typically from
  [`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md).

- contact:

  A single non-empty string identifying you to the API (sent as the
  `User-Agent` header). Erhvervsstyrelsen requires requests to identify
  the sender; use an email address.

- scroll:

  Controls how results are fetched. `FALSE` (default): one request, at
  most `query$size` hits. `TRUE`: use the Elasticsearch scroll API to
  fetch *all* matching hits in batches of 500 (`query$size` is ignored).
  A number: like `TRUE` but with that batch size.

- sleep:

  Seconds to wait between scroll requests. Ignored without `scroll`.

- retries:

  How many times to retry a request that fails with a transient error
  (HTTP 429, 5xx, or a connection failure), with an exponential backoff.
  A long scroll makes hundreds of requests, and without this one blip
  discards the whole pull.

- timeout:

  Seconds before a single request is abandoned.

- url:

  The endpoint to post to. Defaults to the offentliggoerelser search
  endpoint. It is `http://`, not `https://`: the host does not answer on
  443 at all, and a request there hangs until it times out.

## Value

The parsed JSON response as a nested list; with `scroll`, the batches
are combined into one response of the same shape. Without `scroll`, a
warning is issued if the response holds as many hits as the query's
`size` allows, since the result may then be truncated.

## See also

[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md)

Other cvr:
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md),
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md)

## Examples

``` r
if (FALSE) { # \dontrun{
response <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com")

# Large pulls: fetch every matching hit in batches
response <- cvr_query(many_cvrs, "2015-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com", scroll = TRUE)
} # }
```
