# The currency a filing states its amounts in.
#
# Almost every Danish filing is in kroner, and it is tempting to assume all of
# them are. Over 4,304 filings, 4,293 are purely DKK -- and eight are not: six
# report in Canadian dollars and two in US dollars. A ninth kind, three filings
# of one company, is USD throughout with a single stray DKK fact, a nil
# long-term liability, tagged in the wrong unit.
#
# Eight filings is a fifth of a percent, and it is exactly the kind of thing
# that never shows up in a spot check and quietly puts Canadian dollars into a
# krone aggregate. So every function that hands out amounts hands out the
# currency beside them.
#
# All currencies present are returned, joined, rather than a dominant one:
# `"DKK+USD"` is the truth about those three filings, and a caller filtering on
# `"DKK"` should not be given them.
.filing_currency <- function(x) {
  if (!"unit" %in% names(x)) return(NA_character_)
  u <- x$unit[!is.na(x$unit) & grepl("iso4217", x$unit, ignore.case = TRUE)]
  if (length(u) == 0) return(NA_character_)
  cur <- toupper(sub(".*:", "", u))
  paste(sort(unique(cur)), collapse = "+")
}
