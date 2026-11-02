#' Standardise CVR numbers
#'
#' Cleans a vector of Danish CVR numbers to the canonical 8-digit form:
#' dashes and spaces are stripped (`"12 34 56 78"` -> `"12345678"`), and a
#' leading `"DK"` VAT prefix is removed (`"DK12345678"` -> `"12345678"`).
#' This is the form [cvr_query()] requires, so CVR numbers from a
#' spreadsheet or another register go through `clean_cvr()` first.
#'
#' Seven-digit values are *not* zero-padded: a lost leading zero cannot be
#' distinguished from a typo, and inventing a digit would let a malformed
#' number slip past the 8-digit check in [cvr_query()]. Values are returned
#' cleaned but otherwise untouched, so malformed numbers stay visibly
#' malformed. This differs from `clean_cpr()` in the pnrr package, which
#' does pad CPR numbers: birth days 01-09 make that padding unambiguous.
#'
#' `clean_cvr()` started in the daos package and moved here unchanged,
#' next to the functions that use CVR numbers.
#'
#' @param x A character vector of CVR numbers. Numeric vectors are
#'   converted with `as.character()` first.
#'
#' @return A character vector of the same length.
#'
#' @examples
#' clean_cvr(c("DK12345678", "12 34 56 78", "12345678", NA))
#'
#' # Typical use: clean, then query
#' # cvr_query(clean_cvr(firms$cvr), "2024-01-01", "2024-12-31")
#'
#' @seealso [cvr_query()]
#' @family cvr
#' @export
clean_cvr <- function(x) {
  if (!is.character(x)) x <- as.character(x)
  x <- gsub("[- ]", "", x)
  sub("^DK", "", x, ignore.case = TRUE)
}
