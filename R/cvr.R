#' Build an Elasticsearch query for CVR annual reports
#'
#' Constructs the query body used by [cvr_search()] to look up published
#' annual reports (offentliggoerelser) in Erhvervsstyrelsens distribution
#' service. Companies are matched by CVR number and accounting-period end
#' date. The function is pure: it only builds a nested list and performs no
#' network calls.
#'
#' Greenlandic companies are covered by the same service and the same
#' 8-digit CVR numbers as Danish ones. Greenland's own register (GER) was
#' folded into CVR on 3 January 2018, so filings from before then are not
#' reachable here under a CVR number.
#'
#' The full pipeline is:
#'
#' ```r
#' cvr_query(cvr, from, to) |>
#'   cvr_search(contact = "you@example.com") |>
#'   cvr_hits() |>
#'   cvr_download("data/pdf")
#' ```
#'
#' @param cvr A character or numeric vector of CVR numbers (8 digits each).
#'   At most 1000 per query, so split larger sets into batches.
#' @param enddate_from,enddate_to Accounting-period end-date range as
#'   `"YYYY-MM-DD"` strings or `Date`s. Only reports whose period ends within
#'   the range (inclusive) are matched.
#' @param size Maximum number of hits the API should return. Default `2999`.
#'
#' @return A nested list ready to be serialised as the JSON request body.
#'
#' @examples
#' query <- cvr_query("12345678", "2024-01-01", "2024-12-31")
#' str(query, max.level = 3)
#'
#' @seealso [cvr_search()], [cvr_hits()], [cvr_download()]
#' @family cvr
#'
#' @importFrom cli cli_abort
#' @export
cvr_query <- function(cvr, enddate_from, enddate_to, size = 2999) {
  cvr <- as.character(cvr)
  bad <- cvr[!grepl("^\\d{8}$", cvr)]
  if (length(bad) > 0)
    cli::cli_abort(c(
      "All CVR numbers must be exactly 8 digits.",
      "x" = "{cli::qty(length(bad))}Invalid value{?s}: {.val {utils::head(bad, 5)}}."
    ))
  if (length(cvr) > 1000)
    cli::cli_abort(c(
      "Too many CVR numbers ({length(cvr)}); the API allows at most 1000 per query.",
      "i" = "Split the CVR numbers into batches and combine the results."
    ))

  from <- .parse_date(enddate_from, "enddate_from")
  to   <- .parse_date(enddate_to, "enddate_to")
  if (from > to)
    cli::cli_abort("{.arg enddate_from} must not be later than {.arg enddate_to}.")

  list(
    query = list(
      bool = list(
        must = list(
          # I() keeps a length-1 cvr serialised as a JSON array, as required
          # by the Elasticsearch terms query
          list(terms = list(cvrNummer = I(cvr))),
          list(term = list("dokumenter.dokumentType" = "aarsrapport")),
          list(range = list("regnskab.regnskabsperiode.slutDato" = list(
            gte = sprintf("%sT00:00:00.000Z", from),
            lte = sprintf("%sT23:59:59.999Z", to)
          )))
        )
      )
    ),
    size = size
  )
}

#' Send a query to the CVR distribution service
#'
#' Posts a query built with [cvr_query()] to Erhvervsstyrelsens distribution
#' service and returns the parsed JSON response. Pass the result to
#' [cvr_hits()] to extract the hits as a tibble.
#'
#' @param query A query list, typically from [cvr_query()].
#' @param contact A single non-empty string identifying you to the API (sent
#'   as the `User-Agent` header). Erhvervsstyrelsen requires requests to
#'   identify the sender; use an email address.
#' @param scroll Controls how results are fetched. `FALSE` (default): one
#'   request, at most `query$size` hits. `TRUE`: use the Elasticsearch scroll
#'   API to fetch *all* matching hits in batches of 500 (`query$size` is
#'   ignored). A number: like `TRUE` but with that batch size.
#' @param sleep Seconds to wait between scroll requests. Ignored without
#'   `scroll`.
#' @param retries How many times to retry a request that fails with a
#'   transient error (HTTP 429, 5xx, or a connection failure), with an
#'   exponential backoff. A long scroll makes hundreds of requests, and
#'   without this one blip discards the whole pull.
#' @param timeout Seconds before a single request is abandoned.
#' @param url The endpoint to post to. Defaults to the offentliggoerelser
#'   search endpoint. It is `http://`, not `https://`: the host does not
#'   answer on 443 at all, and a request there hangs until it times out.
#'
#' @return The parsed JSON response as a nested list; with `scroll`, the
#'   batches are combined into one response of the same shape. Without
#'   `scroll`, a warning is issued if the response holds as many hits as the
#'   query's `size` allows, since the result may then be truncated.
#'
#' @examples
#' \dontrun{
#' response <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com")
#'
#' # Large pulls: fetch every matching hit in batches
#' response <- cvr_query(many_cvrs, "2015-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com", scroll = TRUE)
#' }
#'
#' @seealso [cvr_query()], [cvr_hits()], [cvr_download()]
#' @family cvr
#'
#' @importFrom cli cli_abort cli_alert_success cli_warn
#' @importFrom cli cli_progress_bar cli_progress_update cli_progress_done
#' @export
cvr_search <- function(query, contact, scroll = FALSE, sleep = 1,
                       retries = 3, timeout = 120,
                       url = "http://distribution.virk.dk/offentliggoerelser/_search") {
  if (missing(contact) || is.null(contact) || length(contact) != 1 ||
      !nzchar(trimws(contact)))
    cli::cli_abort(c(
      "{.arg contact} must be a single non-empty string.",
      "i" = "Erhvervsstyrelsen requires requests to identify the sender; use an email address."
    ))

  if (!isFALSE(scroll) && !isTRUE(scroll) &&
      !(is.numeric(scroll) && length(scroll) == 1 && scroll >= 1))
    cli::cli_abort("{.arg scroll} must be `TRUE`, `FALSE`, or a single batch size >= 1.")

  post <- function(u, body) .cvr_post(u, body, contact, retries, timeout)

  if (isFALSE(scroll)) {
    parsed <- post(url, .cvr_json(query))

    n_hits <- length(parsed$hits$hits)
    cli::cli_alert_success("CVR API request succeeded ({n_hits} hit{?s}).")
    if (!is.null(query$size) && n_hits >= query$size)
      cli::cli_warn(c(
        "The response holds {n_hits} hits -- as many as the query {.arg size} allows.",
        "i" = "The result may be truncated. Use {.code scroll = TRUE} to fetch all hits."
      ))
    return(parsed)
  }

  # Scroll mode: fetch all hits in batches. The scroll context is kept alive
  # for 5 minutes between calls; continuation requests go to /_search/scroll
  # at the root of the host.
  query$size <- if (isTRUE(scroll)) 500L else as.integer(scroll)

  parsed <- post(paste0(url, "?scroll=5m"), .cvr_json(query))
  scroll_id <- parsed[["_scroll_id"]]
  if (is.null(scroll_id))
    cli::cli_abort("The response contains no scroll id -- the endpoint may not support scrolling.")

  # Release the server's scroll context even if the loop aborts. Contexts are
  # a limited resource on a service everyone shares.
  on.exit(.cvr_clear_scroll(url, scroll_id, contact, timeout), add = TRUE)

  all_hits  <- parsed$hits$hits
  batch     <- all_hits
  n_batches <- 1L
  cli::cli_progress_bar("Scrolling CVR hits", total = NA)
  while (length(batch) > 0) {
    cli::cli_progress_update(status = paste0(length(all_hits), " hits"))
    Sys.sleep(sleep)
    nxt <- post(
      paste0(.scroll_url(url), "?scroll=5m&scroll_id=",
             utils::URLencode(scroll_id, reserved = TRUE)),
      ""
    )
    if (!is.null(nxt[["_scroll_id"]])) scroll_id <- nxt[["_scroll_id"]]
    batch <- nxt$hits$hits
    all_hits <- c(all_hits, batch)
    n_batches <- n_batches + 1L
  }
  cli::cli_progress_done()

  parsed$hits$hits <- all_hits
  cli::cli_alert_success(
    "CVR API scroll completed: {length(all_hits)} hit{?s} in {n_batches} request{?s}."
  )
  parsed
}

#' Extract CVR search hits as a tibble
#'
#' Flattens the hits in a response from [cvr_search()] into a tibble with one
#' row per document. Nested field names are reduced to their last component
#' and lowercased (e.g. `dokumenter.dokumentUrl` becomes `dokumenturl`).
#'
#' A hit holds one published annual report and a list of the files it consists
#' of -- typically a PDF and an XBRL document. The rows are built from that
#' nested structure, one per file, with the report's own fields repeated
#' across them. Building them from a flattened vector instead would misalign
#' the moment one file omitted a field, because a flattened vector keeps no
#' record of which file a value came from.
#'
#' @param response A parsed response list from [cvr_search()].
#'
#' @return A tibble with one row per document. Warns if the `cvrnummer` or
#'   `dokumenturl` columns needed by [cvr_download()] are missing.
#'
#' @examples
#' \dontrun{
#' hits <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com") |>
#'   cvr_hits()
#' }
#'
#' @seealso [cvr_query()], [cvr_search()], [cvr_download()]
#' @family cvr
#'
#' @importFrom cli cli_alert_info cli_warn
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble tibble
#' @export
cvr_hits <- function(response) {
  hits <- response$hits$hits
  if (length(hits) == 0) {
    cli::cli_warn("The response contains no hits.")
    return(tibble::tibble())
  }

  rows <- unlist(lapply(hits, function(h) .hit_rows(h[["_source"]])),
                 recursive = FALSE)
  out  <- tibble::as_tibble(data.table::rbindlist(rows, fill = TRUE))

  missing_cols <- setdiff(c("cvrnummer", "dokumenturl"), names(out))
  if (length(missing_cols) > 0)
    cli::cli_warn(
      "{cli::qty(length(missing_cols))}Missing column{?s} required by {.fn cvr_download}: {.val {missing_cols}}."
    )

  cli::cli_alert_info("Extracted {nrow(out)} document row{?s} from {length(hits)} hit{?s}.")
  out
}

#' Download CVR documents
#'
#' Downloads the documents listed in a tibble from [cvr_hits()], one file per
#' row. A delay between requests keeps the load on the API polite.
#'
#' Each company-year typically lists several files (PDF, XML/XBRL, sometimes
#' XHTML), so filter the hits tibble before downloading if you only need one
#' format, e.g. `hits[hits$dokumentmimetype == "application/xml", ]`.
#'
#' @param hits A tibble with `cvrnummer` and `dokumenturl` columns, typically
#'   from [cvr_hits()].
#' @param path Directory to download into. Created automatically if it does
#'   not exist.
#' @param sleep Seconds to wait between downloads. Must be at least 1; the
#'   default of 3 matches the API's expectations for bulk retrieval.
#' @param overwrite What to do about files that already exist. `FALSE`
#'   (default) aborts before downloading anything; `"skip"` leaves them alone
#'   and fetches the rest, which is how an interrupted bulk download is
#'   resumed; `TRUE` replaces them.
#' @param name_by Columns of `hits` to build each file name from, joined with
#'   `_`. Defaults to the CVR number alone, which means a company's filings
#'   for different years are told apart only by a `_2`, `_3` suffix in
#'   whatever order the API returned them. Pass
#'   `c("cvrnummer", "slutdato")` to name them by period instead.
#'
#' @return `hits` with two columns added: `path`, the file each row was
#'   written to, and `downloaded`, whether it arrived. Rows that failed keep
#'   their path, so a second attempt can select them.
#'
#' @examples
#' \dontrun{
#' files <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com") |>
#'   cvr_hits() |>
#'   cvr_download("data/pdf")
#'
#' files[!files$downloaded, ]
#' }
#'
#' @seealso [cvr_query()], [cvr_search()], [cvr_hits()], and [read_xbrl()]
#'   for the machine-readable filings. A PDF filing has no parser here; it
#'   goes through `taxmill`.
#' @family cvr
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_alert_warning
#' @importFrom cli cli_progress_bar cli_progress_update cli_progress_done
#' @export
cvr_download <- function(hits, path, sleep = 3, overwrite = FALSE,
                         name_by = "cvrnummer") {
  missing_cols <- setdiff(c(name_by, "dokumenturl"), names(hits))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Missing required column{?s}: {.val {missing_cols}}."
    )
  if (nrow(hits) == 0)
    cli::cli_abort("{.arg hits} is empty -- there are no documents to download.")
  if (sleep < 1)
    cli::cli_abort("{.arg sleep} must be at least 1 second to keep the load on the API polite.")
  if (!isTRUE(overwrite) && !isFALSE(overwrite) && !identical(overwrite, "skip"))
    cli::cli_abort('{.arg overwrite} must be `TRUE`, `FALSE`, or `"skip"`.')

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # File names: the name_by columns + extension from the url (query strings
  # stripped); repeated names get a _2, _3, ... suffix
  stem <- do.call(paste, c(lapply(name_by, function(k) as.character(hits[[k]])),
                           sep = "_"))
  ext <- tools::file_ext(sub("[?#].*$", "", hits$dokumenturl))
  dot_ext <- ifelse(nzchar(ext), paste0(".", ext), "")
  occurrence <- stats::ave(seq_along(stem), stem, FUN = seq_along)
  suffix <- ifelse(occurrence > 1, paste0("_", occurrence), "")
  filenames <- paste0(stem, suffix, dot_ext)
  out_paths <- file.path(path, filenames)

  exists_already <- file.exists(out_paths)
  if (isFALSE(overwrite) && any(exists_already)) {
    existing <- basename(out_paths[exists_already])
    shown <- utils::head(existing, 10)
    if (length(existing) > 10)
      shown <- c(shown, cli::format_inline("... and {length(existing) - 10} more"))
    cli::cli_abort(c(
      "Would overwrite {length(existing)} existing file{?s} in {.path {path}}: {shown}.",
      "i" = 'Set {.code overwrite = "skip"} to fetch only what is missing, or {.code overwrite = TRUE} to replace them.'
    ))
  }
  fetch <- if (identical(overwrite, "skip")) !exists_already else rep(TRUE, length(out_paths))

  n <- sum(fetch)
  path_lnk <- .path_link(path)
  if (identical(overwrite, "skip") && any(exists_already))
    cli::cli_alert_info("Skipping {sum(exists_already)} file{?s} that {?is/are} already there.")
  if (n == 0) {
    cli::cli_alert_success("Nothing to download; every file is already in '{path_lnk}'.")
    return(.with_paths(hits, out_paths, exists_already))
  }
  cli::cli_alert_info(
    "Downloading {n} document{?s} to '{path_lnk}' with {sleep}s between requests..."
  )

  t0 <- Sys.time()
  skipped <- exists_already & !fetch
  ok <- skipped
  todo <- which(fetch)
  cli::cli_progress_bar("Downloading documents", total = n)
  for (k in seq_along(todo)) {
    i <- todo[[k]]
    cli::cli_progress_update(status = filenames[[i]])
    ok[[i]] <- tryCatch({
      h <- curl::new_handle(failonerror = TRUE, timeout = 300L)
      curl::handle_setheaders(h, "User-Agent" = "cvrr")
      curl::curl_download(hits$dokumenturl[[i]], out_paths[[i]], quiet = TRUE,
                          handle = h)
      TRUE
    }, error = function(e) {
      # A failed transfer can still have created the file; do not leave a
      # truncated or error-page file behind to be mistaken for a filing.
      if (file.exists(out_paths[[i]])) unlink(out_paths[[i]])
      cli::cli_alert_warning(
        "{filenames[[i]]}: download failed ({conditionMessage(e)}) -- skipped."
      )
      FALSE
    })
    if (k < n) Sys.sleep(sleep)
  }
  cli::cli_progress_done()

  # cli reads a leading dot inside braces as style markup, so the elapsed time
  # is formatted before it goes into the message.
  elapsed <- .format_elapsed(Sys.time() - t0)
  cli::cli_alert_success(
    "Downloaded {sum(ok) - sum(skipped)} of {n} document{?s} to '{path_lnk}' in {elapsed}."
  )

  .with_paths(hits, out_paths, ok)
}

.with_paths <- function(hits, out_paths, ok) {
  hits$path <- out_paths
  hits$downloaded <- unname(ok)
  hits
}

# One row per document in a hit, built from the nested structure rather than
# from a flattened vector: `unlist()` records no index, so a file missing a
# field would shift every later value onto the wrong row.
.hit_rows <- function(src) {
  repeats <- vapply(src, function(v) is.list(v) && is.null(names(v)) &&
                      length(v) > 0, logical(1))
  scalars <- .leaf_values(src[!repeats])

  if (!any(repeats)) return(list(scalars))
  if (sum(repeats) > 1)
    cli::cli_warn(c(
      "A hit holds several repeating fields: {.val {names(src)[repeats]}}.",
      "i" = "Only {.val {names(src)[which(repeats)[1]]}} becomes rows; the rest are dropped."
    ))

  lapply(src[[which(repeats)[1]]], function(doc) c(scalars, .leaf_values(doc)))
}

# Flatten a named list to its leaves, keyed by the last name component,
# lowercased. A NULL field becomes NA rather than vanishing.
.leaf_values <- function(x) {
  out <- list()
  for (nm in names(x)) {
    v <- x[[nm]]
    out <- if (is.list(v) && !is.null(names(v))) {
      c(out, .leaf_values(v))
    } else if (length(v) == 0) {
      c(out, stats::setNames(list(NA), tolower(nm)))
    } else {
      c(out, stats::setNames(list(v[[1]]), tolower(nm)))
    }
  }
  dup <- unique(names(out)[duplicated(names(out))])
  if (length(dup) > 0)
    cli::cli_warn(
      "{cli::qty(length(dup))}Field name{?s} used by more than one path: {.val {dup}}."
    )
  out
}

# Parse a single date given as "YYYY-MM-DD" or Date; abort with the argument
# name on anything else (including NULL and NA).
.parse_date <- function(x, arg) {
  d <- tryCatch(suppressWarnings(as.Date(x)), error = function(e) as.Date(NA))
  if (length(d) != 1 || is.na(d))
    cli::cli_abort("{.arg {arg}} must be a single valid date in 'YYYY-MM-DD' format.")
  d
}

.cvr_json <- function(query) {
  as.character(jsonlite::toJSON(query, auto_unbox = TRUE))
}

# POST `body` to `url` with the contact as User-Agent and return the parsed
# JSON response. Transient failures are retried with an exponential backoff;
# anything else aborts with the reason the API itself gave.
.cvr_post <- function(url, body, contact, retries = 3, timeout = 120) {
  attempt <- 0L
  repeat {
    attempt <- attempt + 1L
    result <- tryCatch({
      # connecttimeout is separate from timeout and defaults to 10s, which is
      # short for a service answering a thousand-CVR query.
      h <- curl::new_handle(timeout = timeout, connecttimeout = 30)
      curl::handle_setheaders(h,
        "Content-Type" = "application/json",
        "User-Agent"   = contact
      )
      curl::handle_setopt(h, postfields = body)
      curl::curl_fetch_memory(url, handle = h)
    }, error = function(e) e)

    transient <- inherits(result, "error") ||
      result$status_code == 429 || result$status_code >= 500

    if (!transient) break
    if (attempt > retries) {
      if (inherits(result, "error")) cli::cli_abort(conditionMessage(result))
      break
    }
    Sys.sleep(2^attempt)
  }

  if (result$status_code != 200)
    cli::cli_abort(c(
      "The CVR API request failed with HTTP status {result$status_code}.",
      "x" = "{.val {substr(rawToChar(result$content), 1, 300)}}"
    ))

  jsonlite::fromJSON(rawToChar(result$content), simplifyVector = FALSE)
}

# Tell the server we are done with a scroll context instead of leaving it to
# time out. Best effort: failing to clean up must not fail the pull.
.cvr_clear_scroll <- function(url, scroll_id, contact, timeout) {
  tryCatch({
    h <- curl::new_handle(timeout = timeout, customrequest = "DELETE")
    curl::handle_setheaders(h, "Content-Type" = "application/json",
                            "User-Agent" = contact)
    curl::handle_setopt(h, postfields = .cvr_json(list(scroll_id = I(scroll_id))))
    curl::curl_fetch_memory(.scroll_url(url), handle = h)
  }, error = function(e) NULL)
  invisible(NULL)
}

# Scroll continuations go to /_search/scroll at the root of the host, not
# under the index path.
.scroll_url <- function(url) {
  paste0(sub("^(https?://[^/]+).*$", "\\1", url), "/_search/scroll")
}
