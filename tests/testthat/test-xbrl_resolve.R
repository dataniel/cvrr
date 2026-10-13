# A statement in the shape add_taxonomy() produces. `Total` sits over `A` and `B`.
stmt <- function(...) {
  rows <- list(...)
  d <- do.call(rbind, lapply(rows, function(r)
    as.data.frame(r, stringsAsFactors = FALSE)))
  d$statement <- "BalanceSheet"
  d$basis <- "parent"
  d$period <- "2023-12-31"
  d$is_line <- TRUE
  d$abstract <- FALSE
  d$label <- d$elementid
  d
}
line <- function(code, el, value)
  list(code = code, elementid = el, value = value)

test_that("a conflict the arithmetic can settle is settled", {
  # A is stated as 60 and as 40. Only 40 makes the total of 100 work.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      60),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      60)
  )
  expect_equal(check_statement(x)$verdict[1], "conflicting duplicates")

  r <- xbrl_resolve(x)
  expect_equal(nrow(r[r$elementid == "A", ]), 1L)
  expect_equal(r$value[r$elementid == "A"], 40)
  expect_true(r$resolved[r$elementid == "A"])
  expect_equal(check_statement(r)$verdict[1], "complete")
})

test_that("a conflict that reconciles either way is left alone", {
  # Both readings of A leave the total unexplained by the same amount, so
  # neither is better and nothing is chosen.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      10),
    line("400.00.010", "A",      20),
    line("400.00.020", "B",      30)
  )
  r <- xbrl_resolve(x)
  expect_equal(nrow(r[r$elementid == "A", ]), 2L)
  expect_false(any(r$resolved))
})

test_that("a statement with no conflict comes back untouched", {
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      60)
  )
  r <- xbrl_resolve(x)
  expect_equal(nrow(r), nrow(x))
  expect_false(any(r$resolved))
})

test_that("two conflicting lines are resolved together, not one at a time", {
  # A is 30 or 40, B is 50 or 60. Only 40 + 60 reaches 100, and neither line
  # can be settled without the other.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      30),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      50),
    line("400.00.020", "B",      60)
  )
  r <- xbrl_resolve(x)
  expect_equal(r$value[r$elementid == "A"], 40)
  expect_equal(r$value[r$elementid == "B"], 60)
  expect_equal(check_statement(r)$verdict[1], "complete")
})

test_that("a resolution that settles nothing is not made", {
  # No reading reconciles the total, so choosing between them would be
  # arbitrary dressed as arithmetic.
  x <- stmt(
    line("400.00",     "Total", 999),
    line("400.00.010", "A",      10),
    line("400.00.010", "A",      20),
    line("400.00.020", "B",      30)
  )
  r <- xbrl_resolve(x)
  expect_false(any(r$resolved))
  expect_equal(nrow(r), nrow(x))
})

test_that("too many candidate readings is a refusal, not a long wait", {
  rows <- c(list(line("400.00", "Total", 100)),
            lapply(1:9, function(v) line("400.00.010", "A", v)),
            lapply(1:9, function(v) line("400.00.020", "B", v * 10)))
  x <- do.call(stmt, rows)
  r <- xbrl_resolve(x, max_readings = 10)
  expect_false(any(r$resolved))
})

test_that("a missing column is named", {
  expect_error(xbrl_resolve(data.frame(code = "1")), "elementid")
})

test_that("a conflicting subtotal is settled from below as well as above", {
  # The conflict is on a subtotal, not a leaf. 70 is what its own children add
  # up to, and it is also what the total above it needs. Both directions agree,
  # and neither alone was consulted specially -- every subtotal in the group is
  # scored, so a subtotal's conflict is settled by the same search.
  x <- stmt(
    line("400.00",         "Total", 100),
    line("400.00.010",     "Sub",    70),
    line("400.00.010",     "Sub",    90),
    line("400.00.010.010", "A",      40),
    line("400.00.010.020", "B",      30),
    line("400.00.020",     "C",      30)
  )
  expect_equal(check_statement(x)$verdict[1], "conflicting duplicates")

  r <- xbrl_resolve(x)
  expect_equal(r$value[r$elementid == "Sub"], 70)
  expect_true(all(check_statement(r)$verdict %in% c("complete", "sides agree")))
})

test_that("a subtotal settled only from below is still settled", {
  # No grand total to appeal to: the subtotal's own children are the whole
  # evidence, and they are enough.
  x <- stmt(
    line("400.00.010",     "Sub", 70),
    line("400.00.010",     "Sub", 90),
    line("400.00.010.010", "A",   40),
    line("400.00.010.020", "B",   30)
  )
  r <- xbrl_resolve(x)
  expect_equal(r$value[r$elementid == "Sub"], 70)
  expect_true(r$resolved[r$elementid == "Sub"])
})

test_that("two readings that settle equally many subtotals settle nothing", {
  # A of 40 makes the total work; A of 40 by another route does too, because
  # B is equally in dispute. Taking the first would be a coin toss.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      40),
    line("400.00.010", "A",      60),
    line("400.00.020", "B",      60),
    line("400.00.020", "B",      40)
  )
  r <- xbrl_resolve(x)
  expect_false(any(r$resolved))
  expect_equal(nrow(r), nrow(x))
})

test_that("one figure at two precisions is not a conflict", {
  # XBRL states precision in `decimals`: -3 means accurate to thousands, so
  # 1,729,466,749 at decimals 0 and 1,729,467,000 at decimals -3 are the same
  # number written twice. The exact one is kept.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      60)
  )
  x$decimals <- "0"
  x <- rbind(x, within(x[x$elementid == "A", ], {
    value <- 0; decimals <- "-3"
  }))
  r <- xbrl_resolve(x)
  expect_equal(nrow(r[r$elementid == "A", ]), 1L)
  expect_equal(r$value[r$elementid == "A"], 40)
  expect_equal(r$resolution[r$elementid == "A"], "rounding")
})

test_that("a difference rounding cannot explain is left to the arithmetic", {
  # 47 at decimals -3 would be 0, not 40: the two are not one number.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      60)
  )
  x$decimals <- "0"
  x <- rbind(x, within(x[x$elementid == "A", ], { value <- 47 }))
  r <- xbrl_resolve(x)
  expect_true(is.na(r$resolution[r$elementid == "A"][1]) ||
                r$resolution[r$elementid == "A"][1] != "rounding")
})

test_that("an INF-precision duplicate must match exactly", {
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      60)
  )
  x$decimals <- "INF"
  x <- rbind(x, within(x[x$elementid == "A", ], { value <- 41 }))
  r <- xbrl_resolve(x)
  expect_false(any(r$resolution %in% "rounding"))
})

test_that("a whole statement stated twice is read as two contexts", {
  # Every line has a second figure in a context of its own. Read line by line
  # that is three unresolvable conflicts; read as two contexts it is plain
  # which context is the balance sheet.
  x <- stmt(
    line("400.00",     "Total", 100),
    line("400.00.010", "A",      40),
    line("400.00.020", "B",      60)
  )
  x$contextid <- "real"
  shadow <- x
  shadow$value <- 0
  shadow$contextid <- "blank"
  r <- xbrl_resolve(rbind(x, shadow))
  expect_equal(nrow(r), 3L)
  expect_equal(sort(r$value), c(40, 60, 100))
  expect_true(all(r$resolution == "empty context"))
})

test_that("two contexts that both hold real figures are left to the arithmetic", {
  # Neither column is empty, so the context rule has nothing to say and the
  # conflict stands or falls on whether the sums settle it.
  x <- stmt(line("400.00.010", "A", 40))
  y <- stmt(line("400.00.010", "A", 90))
  x$contextid <- "one"; y$contextid <- "two"
  r <- xbrl_resolve(rbind(x, y))
  expect_equal(nrow(r), 2L)
  expect_false(any(r$resolved))
})

test_that("a nil column is only discarded where a real one disputes it", {
  # Every figure is nil, in one context. There is nothing to prefer it to, and
  # a company may genuinely report nothing.
  x <- stmt(
    line("400.00",     "Total", 0),
    line("400.00.010", "A",     0),
    line("400.00.020", "B",     0)
  )
  x$contextid <- "only"
  r <- xbrl_resolve(x)
  expect_equal(nrow(r), 3L)
  expect_false(any(r$resolved))
})
