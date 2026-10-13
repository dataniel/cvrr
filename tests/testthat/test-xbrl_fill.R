tax_zip <- testthat::test_path("fixtures", "taxonomy-20240101.zip")
filing  <- testthat::test_path("fixtures", "balance-filing.xml")

# 400.00                 Assets            300
#   400.00.010           NoncurrentAssets  100
#   400.00.020           CurrentAssets     200
#     400.00.020.010     Inventories       120
#     400.00.020.020     CashAndCash...     80
tidy_fixture <- function() {
  tax <- read_taxonomy(tax_zip, exdir = withr::local_tempdir())
  x <- read_xbrl(filing, taxonomy = FALSE)
  x$value <- suppressWarnings(as.numeric(x$fact))
  t <- add_taxonomy(x, tax)
  t <- t[t$statement == "BalanceSheet" & t$is_line & t$period == min(t$period), ]
  # The parent column alone: the fixture's consolidated column omits cash, and
  # that omission has a test of its own below.
  list(tidy = t[t$basis == "parent", ], both = t, tax = tax)
}

test_that("nothing is derived where the filing is complete", {
  f <- tidy_fixture()
  r <- xbrl_fill(f$tidy, f$tax, statement = "BalanceSheet")
  expect_true(all(r$source == "reported"))
  expect_equal(nrow(r), nrow(f$tidy))
})

test_that("a subtotal the filer left out is the sum of what is beneath it", {
  f <- tidy_fixture()
  without <- f$tidy[f$tidy$elementid != "CurrentAssets", ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet")
  d <- r[r$source != "reported", ]
  expect_equal(nrow(d), 1L)
  expect_equal(d$elementid, "CurrentAssets")
  expect_equal(d$value, 200)
  expect_equal(d$source, "derived: sum of components")
})

test_that("one missing component is the residual of its subtotal", {
  f <- tidy_fixture()
  without <- f$tidy[f$tidy$elementid != "CashAndCashEquivalents", ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet")
  d <- r[r$source == "derived: residual", ]
  expect_equal(nrow(d), 1L)
  expect_equal(d$elementid, "CashAndCashEquivalents")
  expect_equal(d$value, 80)
})

test_that("derivation goes as far as the hierarchy reaches and stops", {
  # Assets 300 over NoncurrentAssets 100 and nothing else. At that level the
  # missing 200 has exactly one home -- current assets -- so it is recovered.
  # One level down it could be inventories, cash, or both, and nothing says
  # which, so neither is invented.
  f <- tidy_fixture()
  without <- f$tidy[!f$tidy$elementid %in%
                      c("Inventories", "CashAndCashEquivalents", "CurrentAssets"), ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet")
  d <- r[r$source != "reported", ]
  expect_equal(nrow(d), 1L)
  expect_equal(d$elementid, "CurrentAssets")
  expect_equal(d$value, 200)
  expect_false(any(c("Inventories", "CashAndCashEquivalents") %in% d$elementid))
})

test_that("the label of a derived line comes from the taxonomy", {
  f <- tidy_fixture()
  without <- f$tidy[f$tidy$elementid != "CashAndCashEquivalents", ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet")
  expect_equal(r$label[r$source == "derived: residual"], "Likvide beholdninger")
})

test_that("reported rows keep their source and are never altered", {
  f <- tidy_fixture()
  without <- f$tidy[f$tidy$elementid != "CashAndCashEquivalents", ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet")
  kept <- r[r$source == "reported", ]
  expect_equal(sort(kept$value), sort(without$value))
})

test_that("each basis is filled on its own", {
  # The fixture's consolidated column reports current assets of 250 over
  # inventories of 120 and no cash at all, while the parent column is complete.
  # One residual should come back, and it should belong to the group.
  f <- tidy_fixture()
  r <- xbrl_fill(f$both, f$tax, statement = "BalanceSheet")
  d <- r[r$source == "derived: residual", ]
  expect_equal(nrow(d), 1L)
  expect_equal(d$basis, "consolidated")
  expect_equal(d$value, 130)
})

test_that("a missing column is named", {
  expect_error(xbrl_fill(data.frame(code = "1"), NULL), "elementid")
})

test_that("a named residual line takes a remainder no arithmetic can place", {
  # Current assets of 200 with neither inventories nor cash beneath them: the
  # remainder could be either, so arithmetic cannot place it. Told that
  # inventories is where a current-asset remainder belongs, the 200 goes there.
  f <- tidy_fixture()
  without <- f$tidy[!f$tidy$elementid %in%
                      c("Inventories", "CashAndCashEquivalents"), ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet",
                 residual = c(CurrentAssets = "Inventories"))
  d <- r[r$source == "derived: remainder to residual line", ]
  expect_equal(nrow(d), 1L)
  expect_equal(d$elementid, "Inventories")
  expect_equal(d$value, 200)
})

test_that("without a map only the unambiguous case is derived", {
  f <- tidy_fixture()
  without <- f$tidy[!f$tidy$elementid %in%
                      c("Inventories", "CashAndCashEquivalents"), ]

  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet", residual = NULL)
  expect_equal(nrow(r[r$source == "derived: remainder to residual line", ]), 0L)
})

test_that("a residual line the filing already reports is not written over", {
  f <- tidy_fixture()
  without <- f$tidy[f$tidy$elementid != "CashAndCashEquivalents", ]
  r <- xbrl_fill(without, f$tax, statement = "BalanceSheet",
                 residual = c(CurrentAssets = "Inventories"))
  # Inventories is reported, so the single absent line -- cash -- is the
  # remainder, and the map is not consulted.
  d <- r[r$source != "reported", ]
  expect_equal(d$elementid, "CashAndCashEquivalents")
  expect_equal(d$source, "derived: residual")
})

test_that("a malformed residual map is refused", {
  f <- tidy_fixture()
  expect_error(xbrl_fill(f$tidy, f$tax, residual = c("Inventories")),
               "named character vector")
})

test_that("a subtotal absent from the residual map is passed over, not an error", {
  # `[[` on a named character vector errors for a missing name, and almost
  # every subtotal is missing from the map.
  f <- tidy_fixture()
  without <- f$tidy[!f$tidy$elementid %in%
                      c("Inventories", "CashAndCashEquivalents"), ]
  expect_no_error(
    xbrl_fill(without, f$tax, statement = "BalanceSheet",
              residual = c(SomethingElse = "Inventories")))
})
