#' Read the tables inside a filing's text notes
#'
#' A note in an XBRL filing is a text block, and text blocks often hold the
#' note as escaped HTML -- table markup and all. This finds those tables and
#' returns their cells, so a specification the filer never tagged can still be
#' read.
#'
#' @section When this is worth doing:
#' Where a company tags its staff costs only as a total, the split into wages,
#' pensions and social security usually still appears in
#' `DisclosureOfEmployeeBenefitsExpense`. Across a corpus of 4,304 Danish
#' filings, 1,302 report the total alone; 1,065 of those carry the note, and
#' 325 carry it as a table. The same holds for fixed-asset notes.
#'
#' Whether the markup survives is the filing agent's choice, not the format's:
#' some flatten the table to a run of words before writing it into the
#' instance, and nothing can be recovered from those. About a fifth of filings
#' keep it.
#'
#' @section Numbers as accountants write them:
#' Danish notes use `.` as the thousands separator and `,` for decimals, wrap
#' negatives in parentheses, and write a dash for nil. All four are read.
#' Anything else returns `NA` rather than a guess -- a cell that cannot be
#' parsed is not a zero, and neither is an empty one: treating blank layout
#' cells as zeros invents columns and shifts every figure to their right.
#'
#' @param x A tibble from [read_xbrl()].
#' @param elementid Which note to read. A single element name, several, or
#'   `NULL` (default) for every text block that contains a table.
#'
#' @return A tibble in long form, one row per numeric cell: `elementid`,
#'   `table` (its position in the note), `row`, `label` (the row's leading text
#'   cell), `column`, `column_label` (the header above it, which in an
#'   accounting note is the year) and `value`. A note with no table contributes
#'   nothing.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("filing.xml")
#' notes <- xbrl_note_tables(x, "DisclosureOfEmployeeBenefitsExpense")
#'
#' # a specification is only usable if it sums to the figure that was tagged
#' sum(notes$value[notes$column == 1])
#' }
#'
#' @seealso [read_xbrl()]. Validate what comes back against a tagged total
#'   before using it: a table that does not add up has been misread.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @importFrom xml2 read_html xml_find_all xml_text
#' @export
xbrl_note_tables <- function(x, elementid = NULL) {
  if (!all(c("elementid", "fact") %in% names(x)))
    cli::cli_abort("{.arg x} must be a tibble from {.fn read_xbrl}.")

  d <- if (is.null(elementid)) x else x[x$elementid %in% elementid, , drop = FALSE]
  d <- d[!is.na(d$fact) & grepl("<table", d$fact, fixed = TRUE), , drop = FALSE]
  if (nrow(d) == 0) return(tibble::as_tibble(data.frame()))

  rows <- lapply(seq_len(nrow(d)), function(i)
    .note_tables_one(d$fact[i], d$elementid[i]))
  tibble::as_tibble(data.table::rbindlist(
    rows[!vapply(rows, is.null, logical(1))], fill = TRUE))
}

.note_tables_one <- function(txt, elementid) {
  doc <- tryCatch(xml2::read_html(txt), error = function(e) NULL)
  if (is.null(doc)) return(NULL)
  tabs <- xml2::xml_find_all(doc, "//table")
  if (length(tabs) == 0) return(NULL)

  out <- lapply(seq_along(tabs), function(k) {
    trs <- xml2::xml_find_all(tabs[[k]], ".//tr")
    if (length(trs) == 0) return(NULL)
    cells <- lapply(trs, function(tr)
      trimws(xml2::xml_text(xml2::xml_find_all(tr, "./td | ./th"))))

    # The header is the first row with nothing in its label position: an
    # accounting note leads with a blank cell and then the years. Without it a
    # column is just an index, and which year a figure belongs to is the whole
    # point of reading the note.
    head_row <- Find(function(cs) length(cs) > 1 && !nzchar(cs[1]) &&
                       any(nzchar(cs[-1])), cells)
    headers <- if (is.null(head_row)) character() else head_row[-1]
    headers <- headers[nzchar(headers)]

    rowdata <- lapply(seq_along(cells), function(r) {
      cs <- cells[[r]]
      if (length(cs) < 2) return(NULL)
      # The label is the first cell that is text rather than a number; the
      # numbers to its right are the columns, usually this year and last.
      v <- .danish_number(cs)
      first_num <- which(!is.na(v))
      if (length(first_num) == 0) return(NULL)
      lab <- paste(cs[seq_len(first_num[1] - 1)], collapse = " ")
      if (!nzchar(trimws(lab))) return(NULL)
      col <- seq_along(first_num)
      data.frame(table = k, row = r, label = trimws(lab), column = col,
                 column_label = if (length(headers) >= max(col))
                   headers[col] else NA_character_,
                 value = v[first_num], stringsAsFactors = FALSE)
    })
    do.call(rbind, rowdata[!vapply(rowdata, is.null, logical(1))])
  })
  out <- out[!vapply(out, is.null, logical(1))]
  if (length(out) == 0) return(NULL)
  cbind(elementid = elementid, do.call(rbind, out))
}

# Danish accounting numbers: 1.234.567,89 with a dot for thousands, negatives
# in parentheses, a dash for nil. Anything else is NA rather than a guess.
.danish_number <- function(s) {
  s <- trimws(s)
  # Non-breaking and thin spaces, as escapes so the source stays ASCII.
  s <- gsub("[\u00a0\u2007\u202f]", "", s)
  neg <- grepl("^\\(.*\\)$", s) | grepl("^-[0-9]", s)
  s <- gsub("^\\(|\\)$", "", s)

  # A dash is a stated nil. An empty cell is not: it is layout, and reading it
  # as zero invents a column and shifts every figure to its right.
  nil <- s %in% c("-", "\u2013", "\u2014", "0")
  clean <- gsub("[.]", "", s)
  clean <- gsub(",", ".", clean)
  clean <- gsub("[^0-9.-]", "", clean)

  v <- suppressWarnings(as.numeric(clean))
  v[nil & is.na(v)] <- 0
  # A bare dash is nil; a cell of text is not a number at all.
  v[!nil & !grepl("[0-9]", s)] <- NA_real_
  ifelse(neg & !is.na(v), -abs(v), v)
}
