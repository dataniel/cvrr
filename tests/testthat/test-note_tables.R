# Notes arrive as escaped HTML in about a fifth of Danish filings; the rest are
# flattened to a run of words by the filing software and nothing can be
# recovered from those.
note_filing <- function(body) {
  path <- withr::local_tempfile(fileext = ".xml", .local_envir = parent.frame())
  writeLines(sprintf('<?xml version="1.0" encoding="UTF-8"?>
<xbrli:xbrl xmlns:xbrli="http://www.xbrl.org/2003/instance"
            xmlns:fsa="http://xbrl.dcca.dk/fsa">
  <xbrli:context id="c1"><xbrli:period>
    <xbrli:startDate>2024-01-01</xbrli:startDate>
    <xbrli:endDate>2024-12-31</xbrli:endDate>
  </xbrli:period></xbrli:context>
  <fsa:DisclosureOfEmployeeBenefitsExpense contextRef="c1">%s</fsa:DisclosureOfEmployeeBenefitsExpense>
</xbrli:xbrl>', body), path)
  path
}

TABLE <- paste0(
  "&lt;table&gt;",
  "&lt;tr&gt;&lt;td&gt;&lt;/td&gt;&lt;td&gt;2024&lt;/td&gt;&lt;td&gt;2023&lt;/td&gt;&lt;/tr&gt;",
  "&lt;tr&gt;&lt;td&gt;Lønninger&lt;/td&gt;&lt;td&gt;1.200.000&lt;/td&gt;&lt;td&gt;1.100.000&lt;/td&gt;&lt;/tr&gt;",
  "&lt;tr&gt;&lt;td&gt;Pensioner&lt;/td&gt;&lt;td&gt;(50.000)&lt;/td&gt;&lt;td&gt;-&lt;/td&gt;&lt;/tr&gt;",
  "&lt;tr&gt;&lt;td&gt;I alt&lt;/td&gt;&lt;td&gt;1.150.000&lt;/td&gt;&lt;td&gt;1.100.000&lt;/td&gt;&lt;/tr&gt;",
  "&lt;/table&gt;")

test_that("xbrl_note_tables() reads a table out of a text note", {
  n <- xbrl_note_tables(read_xbrl(note_filing(TABLE), taxonomy = FALSE))

  expect_equal(nrow(n), 6)
  expect_setequal(unique(n$label), c("Lønninger", "Pensioner", "I alt"))
  expect_equal(n$value[n$label == "Lønninger" & n$column == 1], 1200000)
})

# Which year a figure belongs to is the point of reading the note, and the
# header row is where that is written.
test_that("xbrl_note_tables() carries the column headers", {
  n <- xbrl_note_tables(read_xbrl(note_filing(TABLE), taxonomy = FALSE))
  expect_equal(unique(n$column_label[n$column == 1]), "2024")
  expect_equal(unique(n$column_label[n$column == 2]), "2023")
})

test_that("xbrl_note_tables() reads numbers the way accountants write them", {
  n <- xbrl_note_tables(read_xbrl(note_filing(TABLE), taxonomy = FALSE))

  # parentheses are negative, a dash is a stated nil
  expect_equal(n$value[n$label == "Pensioner" & n$column == 1], -50000)
  expect_equal(n$value[n$label == "Pensioner" & n$column == 2], 0)
})

test_that(".danish_number() refuses to guess", {
  v <- cvrr:::.danish_number(c("1.234.567", "(1.234)", "-", "12,50", "abc", "", "0"))
  expect_equal(v, c(1234567, -1234, 0, 12.5, NA, NA, 0))
})

test_that("xbrl_note_tables() returns nothing for a note with no table", {
  n <- xbrl_note_tables(read_xbrl(note_filing("Personaleomkostninger udgjorde 1.150.000 kr."), taxonomy = FALSE))
  expect_equal(nrow(n), 0)
})
