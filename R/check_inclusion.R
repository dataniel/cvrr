#' Find lines a note says are contained in another line
#'
#' A function-based income statement reports administrative expenses,
#' distribution costs and staff costs as separate figures. They are not always
#' separate amounts: where the staff note says the wages were expensed under
#' administration, the staff costs are *inside* the administrative expenses,
#' and adding the two counts them twice.
#'
#' @section Why no other check sees it:
#' Both figures are correctly tagged, both belong to the statement, and the
#' statement still adds up -- because the filer only ever counted the money
#' once. Nothing structural distinguishes this from a filing where the two are
#' genuinely separate. The only place the difference is stated is the prose of
#' the note.
#'
#' @section How common it is:
#' Rare, in Danish filings. Across 4,304 filings from 2020-2024, 87 use the
#' function-based income statement at all, 38 report administrative expenses
#' and staff costs together, and 3 carry a note naming administration. Most
#' Danish companies file by nature -- gross profit, then staff costs, then
#' depreciation -- where the question does not arise.
#'
#' That is worth knowing before relying on this: it is a check for a small,
#' real population, not a widespread correction.
#'
#' @section A cost split between destinations:
#' A note may name several: wages expensed partly under production and partly
#' under administration. Each is returned as a row with `sole = FALSE`, because
#' the note says where the money went without saying how much went to each.
#' Treating such a filing as though the whole staff cost sat in administration
#' would replace one error with another, so nothing is apportioned.
#'
#' @section What it does not do:
#' It reports the inclusion; it does not net it out. How to handle a
#' double-counted line depends on which variable a statistic is building -- an
#' employment cost total wants the staff figure, an operating cost breakdown
#' wants administration less staff -- and that is the caller's decision.
#'
#' @param x A tibble from [read_xbrl()].
#' @param note The text block to read. Defaults to the staff cost note.
#' @param within Elements the note may place the costs under. Defaults to the
#'   two function-based expense lines.
#'
#' @return A tibble with one row per line the note places inside another:
#'   `elementid` (the contained line), `within` (the containing line),
#'   `value` and `within_value` where both are reported, `sole` (whether the
#'   note names this destination alone), and `evidence`, the sentence the
#'   reading rests on. No rows where the note says nothing.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("filing.xml")
#' check_inclusion(x)
#' }
#'
#' @seealso [xbrl_note_tables()], which reads the same notes for their figures
#'   rather than their prose.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
check_inclusion <- function(x, note = "DisclosureOfEmployeeBenefitsExpense",
                            within = c("AdministrativeExpenses",
                                       "DistributionCosts",
                                       "CostOfSales")) {
  if (!all(c("elementid", "fact") %in% names(x)))
    cli::cli_abort("{.arg x} must be a tibble from {.fn read_xbrl}.")

  txt <- x$fact[x$elementid %in% note]
  txt <- paste(txt[!is.na(txt)], collapse = " ")
  if (!nzchar(txt)) return(tibble::as_tibble(data.frame()))
  plain <- .plain_text(txt)

  # The phrasing filings actually use: "Lonninger ... er omkostningsfoert
  # under foelgende poster: Administrationsomkostninger". A mention of the
  # line is not enough on its own -- the note has to be saying where the cost
  # went, so a verb of placement is required alongside it.
  places <- grepl(paste0("omkostningsf|indeholdt|indg\u00e5r|er medtaget|",
                         "er inkluderet|included in|recognised in"),
                  plain, ignore.case = TRUE)
  if (!places) return(tibble::as_tibble(data.frame()))

  words <- c(AdministrativeExpenses = "administra",
             DistributionCosts      = "distribution|salgsomkostning|vertriebs",
             CostOfSales            = "produktion|vareforbrug|cost of sales")
  hits <- within[vapply(within, function(w) {
    pat <- words[[w]]
    !is.null(pat) && grepl(pat, plain, ignore.case = TRUE)
  }, logical(1))]
  if (length(hits) == 0) return(tibble::as_tibble(data.frame()))

  value_of <- function(el) {
    v <- suppressWarnings(as.numeric(
      x$fact[x$elementid == el & is.na(x$dimensions)]))
    v <- v[!is.na(v)]
    if (length(v) == 0) NA_real_ else v[which.max(abs(v))]
  }
  contained <- sub("^Disclosure(Of)?", "", note)

  tibble::as_tibble(data.table::rbindlist(lapply(hits, function(w)
    data.frame(elementid = contained, within = w,
               value = value_of(contained), within_value = value_of(w),
               sole = length(hits) == 1L,
               evidence = .sentence_with(plain, words[[w]]),
               stringsAsFactors = FALSE)), fill = TRUE))
}

# Escaped HTML with the markup stripped and the whitespace collapsed.
.plain_text <- function(txt) {
  s <- gsub("<[^>]*>", " ", txt)
  s <- gsub("&[a-z]+;|&#[0-9]+;", " ", s)
  trimws(gsub("[[:space:]]+", " ", s))
}

# The clause the reading rests on, so a caller can judge it rather than trust
# a regular expression.
.sentence_with <- function(plain, pattern) {
  parts <- unlist(strsplit(plain, "(?<=[.:;])\\s", perl = TRUE))
  hit <- parts[grepl(pattern, parts, ignore.case = TRUE)]
  if (length(hit) == 0) return(substr(plain, 1, 200))
  substr(hit[1], 1, 200)
}
