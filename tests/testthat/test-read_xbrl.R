xbrl_fixture <- testthat::test_path("fixtures", "minimal.xml")
dim_fixture  <- testthat::test_path("fixtures", "dimensions.xml")

test_that("read_xbrl() returns a tibble", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_s3_class(result, "tbl_df")
})

test_that("read_xbrl() returns one row per fact", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_equal(nrow(result), 2)
})

test_that("read_xbrl() has expected columns", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_named(result, c("file", "cvr", "period_start", "period_end",
                         "prev_start", "prev_end", "elementid", "prefix",
                         "namespace", "schemaref", "contextid", "fact",
                         "value", "unitid", "unit", "decimals", "startdate",
                         "enddate", "instant", "dimensions",
                         "explicit_member"),
               ignore.order = TRUE)
})

test_that("read_xbrl() joins context dates correctly, as dates", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  revenue_row <- result[result$elementid == "Revenue", ]
  expect_s3_class(revenue_row$startdate, "Date")
  expect_equal(revenue_row$startdate, as.Date("2023-01-01"))
  expect_equal(revenue_row$enddate,   as.Date("2023-12-31"))
})

# Every caller used to write `as.numeric(fact)` itself, and the ones that
# forgot compared amounts as text.
test_that("read_xbrl() converts amounts, and leaves text alone", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_equal(result$value[result$elementid == "Revenue"], 1000000)
  expect_true(all(is.na(result$value[!grepl("^-?[0-9.]+$", result$fact)])))
})

# A filing has to be findable again once many are bound into one table.
test_that("read_xbrl() carries the filing's own identity on every row", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_equal(unique(result$file), xbrl_fixture)
  expect_s3_class(result$period_end, "Date")
})

test_that("read_xbrl() reads a directory, and binds unlike filings", {
  dir <- testthat::test_path("fixtures")
  result <- suppressWarnings(read_xbrl(dir, taxonomy = FALSE))
  expect_gt(length(unique(result$file)), 1)
  expect_true(all(c("elementid", "value") %in% names(result)))
})

test_that("read_xbrl() refuses a path that is not there", {
  expect_error(read_xbrl("no/such/place.xml"), "does not exist")
})

test_that("read_xbrl() joins unit correctly", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_true(all(grepl("DKK", result$unit)))
})

test_that("read_xbrl() strips namespace prefixes from contextid and unitid", {
  result <- read_xbrl(xbrl_fixture, taxonomy = FALSE)
  expect_false(any(grepl(":", result$contextid, fixed = TRUE)))
  expect_false(any(grepl(":", result$unitid[!is.na(result$unitid)], fixed = TRUE)))
})

# The taxonomy is keyed by qualified name, so the namespace has to survive the
# read -- `elementid` alone cannot be looked up.
test_that("read_xbrl() keeps the element's namespace", {
  result <- read_xbrl(dim_fixture, taxonomy = FALSE)
  revenue <- result[result$elementid == "Revenue", ]

  expect_equal(sort(revenue$prefix), c("cmn", "fsa"))
  expect_equal(
    revenue$namespace[revenue$prefix == "fsa"],
    "http://xbrl.dcca.dk/fsa"
  )
  # same local name, different namespaces, different facts
  expect_equal(revenue$fact[revenue$prefix == "fsa"], "1000000")
  expect_equal(revenue$fact[revenue$prefix == "cmn"], "7")
})

# Roughly a fifth of the contexts in a Danish filing carry two dimensions, and
# one of the pair is often consolidated-vs-solo. Keeping only the first member
# would mix group and parent figures.
test_that("read_xbrl() keeps every explicitMember of a context", {
  result <- read_xbrl(dim_fixture, taxonomy = FALSE)
  row <- result[result$elementid == "ContributedCapital", ]

  expect_equal(
    row$dimensions,
    "fsa:ClassesOfEquityDimension;cmn:ConsolidatedSoloDimension"
  )
  expect_equal(
    row$explicit_member,
    "fsa:ContributedCapitalMember;cmn:ConsolidatedMember"
  )
})

test_that("read_xbrl() leaves dimensionless contexts as NA", {
  result <- read_xbrl(dim_fixture, taxonomy = FALSE)
  expect_true(all(is.na(result$dimensions[result$contextid == "ctx_plain"])))
})

test_that("read_xbrl() handles facts without a unit", {
  result <- read_xbrl(dim_fixture, taxonomy = FALSE)
  row <- result[result$elementid == "NameOfEntity", ]
  expect_equal(row$fact, "Acme A/S")
  expect_true(is.na(row$unitid))
  expect_true(is.na(row$unit))
})

test_that("read_xbrl() warns and returns an empty tibble for a document with no facts", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(
    '<?xml version="1.0"?><xbrl xmlns="http://www.xbrl.org/2003/instance"></xbrl>',
    path
  )

  expect_warning(result <- read_xbrl(path, taxonomy = FALSE), "No XBRL facts")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true(all(c("elementid", "namespace", "fact") %in% names(result)))
})

# Namespace prefixes are document-local and filers pick them freely: in a real
# sample "e" meant fsa in one filing and sob in another. Anything joined on the
# prefix attaches the wrong definition without complaining.
test_that("read_xbrl() rewrites dimension and member prefixes to the namespace", {
  result <- read_xbrl(testthat::test_path("fixtures", "oddprefix.xml"), taxonomy = FALSE)

  expect_equal(result$namespace, "http://xbrl.dcca.dk/fsa")
  expect_equal(
    result$dimensions,
    "fsa:ClassesOfPropertyPlantAndEquipmentDimension;cmn:ConsolidatedSoloDimension"
  )
  expect_equal(result$explicit_member,
               "fsa:LandAndBuildingsMember;cmn:ConsolidatedMember")
})
