test_that(".format_elapsed() formats milliseconds", {
  expect_equal(.format_elapsed(as.difftime(0.1, units = "secs")), "100ms")
  expect_equal(.format_elapsed(as.difftime(0,   units = "secs")), "0ms")
})

test_that(".format_elapsed() formats seconds", {
  expect_equal(.format_elapsed(as.difftime(2.3, units = "secs")), "2.3s")
  expect_equal(.format_elapsed(as.difftime(59,  units = "secs")), "59s")
})

test_that(".format_elapsed() formats minutes", {
  expect_equal(.format_elapsed(as.difftime(90, units = "secs")), "1.5m")
  expect_equal(.format_elapsed(as.difftime(60, units = "secs")), "1m")
})

test_that(".path_link() falls back to plain text without hyperlink support", {
  withr::local_options(cli.hyperlink = FALSE, cli.hyperlink_run = FALSE)
  path <- withr::local_tempfile()
  expect_equal(as.character(.path_link(path, "label")), "label")
})

test_that(".path_link() links files to their absolute file:// path", {
  withr::local_options(cli.hyperlink = TRUE)
  path <- withr::local_tempfile()
  writeLines("x", path)

  link <- .path_link(path, basename(path))
  expect_match(link, "file://", fixed = TRUE)
  expect_match(link, normalizePath(path, winslash = "/"), fixed = TRUE)
})

test_that(".path_link() uses an Explorer run-link for directories in RStudio", {
  withr::local_envvar(RSTUDIO = "1")
  withr::local_options(cli.hyperlink = TRUE, cli.hyperlink_run = TRUE)
  dir <- withr::local_tempdir()

  link <- .path_link(dir)
  expect_match(link, "x-r-run", fixed = TRUE)
  expect_match(link, "utils::browseURL", fixed = TRUE)
})

# The check family was written when a fact table held one filing. read_xbrl()
# now returns a directory at a time, so `c("basis", "period")` no longer
# identifies one statement: four companies with the same balance sheet date
# land in one group, their codes collide and the residual comes back NA.
test_that(".default_by() puts the filing in the grouping when it is there", {
  expect_equal(cvrr:::.default_by(data.frame(file = 1, basis = 1, period = 1)),
               c("file", "basis", "period"))
  expect_equal(cvrr:::.default_by(data.frame(basis = 1, period = 1)),
               c("basis", "period"))
  expect_equal(cvrr:::.default_by(data.frame(file = 1, basis = 1),
                                  want = c("file", "basis")),
               c("file", "basis"))
})

test_that(".default_by() honours an explicit by, and does not abort on none", {
  expect_equal(cvrr:::.default_by(data.frame(a = 1), by = "a"), "a")
  # The calling function names the column it cannot find; its message is better.
  expect_equal(cvrr:::.default_by(data.frame(a = 1)),
               c("file", "basis", "period"))
})

# A filing carries the year it is about and at least one comparative, and the
# comparative is usually partial. Checking both reports its gaps as the
# filing's own.
test_that(".closing_only() keeps the filing's own column", {
  x <- data.frame(period = as.Date(c("2023-12-31", "2022-12-31")),
                  period_end = as.Date("2023-12-31"), v = 1:2)
  expect_equal(cvrr:::.closing_only(x)$v, 1L)
  expect_equal(nrow(cvrr:::.closing_only(x, NULL)), 2L)
})

test_that(".closing_only() leaves a table it cannot narrow alone", {
  x <- data.frame(period = as.Date("2023-12-31"),
                  period_end = as.Date(NA), v = 1)
  expect_equal(nrow(cvrr:::.closing_only(x)), 1L)
  expect_equal(nrow(cvrr:::.closing_only(data.frame(v = 1))), 1L)
})

# A cascade is what an income statement is. Run over every statement the
# taxonomy defines, the walk finds an "entry" in places that have none -- the
# number of employees, the submitting agent's CVR number.
test_that("the income alias covers every income statement the taxonomy has", {
  s <- cvrr:::.INCOME_STATEMENTS()

  expect_true(all(startsWith(s, "IncomeStatement")))
  expect_false(any(endsWith(s, "Disclosures")))
  expect_true(all(c("IncomeStatementByNature", "IncomeStatementByFunction") %in% s))
  # The sector formats are income statements too, and a hardcoded pair of
  # names would have dropped them without saying so.
  expect_true("IncomeStatementUvmReg" %in% s)
  expect_gt(length(s), 10)
})
