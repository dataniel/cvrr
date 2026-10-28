test_that("find_signs() finds the correct sign combination", {
  # Only one solution: 7 - 3 = 4 (i.e. signs +1, -1)
  df <- data.frame(
    label = c("a", "b", "total"),
    value = c(7, 3, 4)
  )
  result <- find_signs(df, label, value, total_label = "total")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  expect_equal(result$status, rep("unique", 3))
  expect_true(all(result$certain))

  signed_values <- result$value[result$label != "total"]
  expect_equal(sum(signed_values), result$value[result$label == "total"])
})

test_that("find_signs() respects positive/negative constraints", {
  df <- data.frame(
    label = c("revenue", "costs", "total"),
    value = c(100, 60, 40)
  )
  result <- find_signs(df, label, value,
                       total_label = "total",
                       positive = "revenue",
                       negative = "costs")
  expect_equal(result$value[result$label == "revenue"],  100)
  expect_equal(result$value[result$label == "costs"],   -60)
})

# `by = year` used to fall through to the ungrouped branch, which then found
# several total rows and returned an empty tibble with a recycling warning.
test_that("find_signs() accepts every spelling of `by`", {
  df <- data.frame(
    year  = rep(c(2023, 2024), each = 3),
    label = rep(c("a", "b", "total"), 2),
    value = c(7, 3, 4, 10, 2, 8)
  )
  reference <- find_signs(df, label, value, by = c(year))

  expect_equal(find_signs(df, label, value, by = year),      reference)
  expect_equal(find_signs(df, label, value, by = "year"),    reference)
  expect_equal(find_signs(df, label, value, by = c("year")), reference)

  expect_equal(nrow(reference), 6)
  expect_equal(reference$sign, c(1L, -1L, 1L, 1L, -1L, 1L))
})

test_that("find_signs() groups by several columns", {
  df <- data.frame(
    year  = rep(c(2023, 2024), each = 6),
    firm  = rep(rep(c("A", "B"), each = 3), 2),
    label = rep(c("a", "b", "total"), 4),
    value = c(7, 3, 4, 10, 2, 8, 9, 4, 5, 20, 5, 15)
  )
  result <- find_signs(df, label, value, by = c(year, firm))
  expect_equal(nrow(result), 12)
  expect_equal(result$status, rep("unique", 12))
  expect_named(result, c("year", "firm", "label", "value", "sign", "certain",
                         "n_solutions", "status"))
})

test_that("find_signs() keeps unsolvable groups instead of dropping them", {
  df <- data.frame(
    label = c("a", "b", "total"),
    value = c(1, 1, 99)
  )
  result <- find_signs(df, label, value)

  expect_equal(nrow(result), 3)
  expect_equal(unique(result$status), "unsolved")
  expect_true(all(is.na(result$sign[result$label != "total"])))
  # the total is the target, not a line item -- it keeps its value
  expect_equal(result$value[result$label == "total"], 99)
})

# Several assignments can reach the total while still agreeing on some items.
# Those items are determined, and saying so is not a guess.
test_that("find_signs() resolves what every candidate agrees on", {
  df <- data.frame(
    label = c("a", "b", "c", "total"),
    value = c(5, 5, 10, 10)
  )
  result <- find_signs(df, label, value)

  expect_equal(unique(result$status), "ambiguous")
  expect_equal(result$n_solutions[1], 2L)
  expect_true(result$certain[result$label == "c"])
  expect_equal(result$sign[result$label == "c"], 1L)
  expect_false(any(result$certain[result$label %in% c("a", "b")]))
})

test_that("find_signs() names a missing or duplicated total", {
  no_total <- find_signs(data.frame(label = c("a", "b"), value = c(1, 2)),
                         label, value)
  expect_equal(unique(no_total$status), "no_total")

  dup <- find_signs(data.frame(label = c("a", "total", "total"),
                               value = c(1, 2, 3)), label, value)
  expect_equal(unique(dup$status), "duplicate_total")
})

# A company-year where only the total was tagged used to abort the whole run
# with "missing value where TRUE/FALSE needed".
test_that("find_signs() survives a group with nothing but a total", {
  df <- rbind(
    data.frame(g = 1, label = c("a", "b", "total"), value = c(7, 3, 4)),
    data.frame(g = 2, label = "total", value = 42)
  )
  result <- find_signs(df, label, value, by = g)

  expect_equal(nrow(result), 4)
  expect_equal(result$status[result$g == 1], rep("unique", 3))
  expect_equal(result$status[result$g == 2], "unsolved")
})

test_that("find_signs() reports labels that constrain nothing", {
  df <- data.frame(label = c("a", "b", "total"), value = c(7, 3, 4))
  expect_warning(find_signs(df, label, value, positive = "typo"), "not present")
})

test_that("find_signs() rejects bad arguments in the caller's terms", {
  df <- data.frame(label = c("a", "b", "total"), value = c(7, 3, 4))

  expect_error(find_signs(df, label, nope), "not found")
  expect_error(find_signs(df, label, value, by = missing_col), "not found")
  expect_error(find_signs(df, label, value, tol = 0), "positive number")
  expect_error(
    find_signs(data.frame(label = "total", value = "4"), label, value),
    "must be numeric"
  )
})

test_that("find_signs() refuses a search that would exhaust memory", {
  n  <- 40
  df <- data.frame(label = c(sprintf("i%02d", seq_len(n)), "total"),
                   value = c(seq_len(n), 1))
  expect_error(find_signs(df, label, value), "Too many items")
})

test_that("find_signs() honours tol", {
  # 7.005 - 3 is 4.005: outside the default tolerance, inside 1e-2
  df <- data.frame(label = c("a", "b", "total"), value = c(7.005, 3, 4))
  expect_equal(unique(find_signs(df, label, value)$status), "unsolved")
  expect_equal(unique(find_signs(df, label, value, tol = 1e-2)$status), "unique")
})

test_that(".meet_in_middle() returns every assignment that reaches the target", {
  # 5 + 5 - 10 is not 10, but 5 - 5 + 10 and -5 + 5 + 10 both are
  sols <- .meet_in_middle(c(5, 5), 10, target = 10, max_zeros = 0L,
                          c1 = c(0L, 0L), c2 = 0L)
  expect_equal(nrow(sols), 2)
  expect_equal(unique(sols[, 3]), 1L)
  expect_setequal(sols[, 1], c(1L, -1L))

  none <- .meet_in_middle(c(1, 1), 1, target = 99, max_zeros = 0L,
                          c1 = c(0L, 0L), c2 = 0L)
  expect_equal(nrow(none), 0)
})

# The search is clever, so it is checked against one that is not: every
# assignment of every item, enumerated, with the same preference for the
# fewest zeros. Random cases cover what hand-written ones miss -- repeated
# values, nil items, negatives, constraints, and magnitudes from kroner to a
# group's hundred billion. This is how the precision bug below was found.
brute_signs <- function(v, target, max_zeros, fixed, tol) {
  n <- length(v)
  grid <- as.matrix(expand.grid(rep(list(-1:1), n)))
  ok <- abs(grid %*% v - target) <= tol & rowSums(grid == 0) <= max_zeros
  ok <- ok & apply(grid, 1, function(s) all(s[fixed == 1L] >= 0) &&
                     all(s[fixed == -1L] <= 0))
  s <- grid[ok, , drop = FALSE]
  if (nrow(s) == 0) return(list(status = "unsolved", n = 0L))
  s <- s[rowSums(s == 0) == min(rowSums(s == 0)), , drop = FALSE]
  list(status = if (nrow(s) == 1) "unique" else "ambiguous", n = nrow(s),
       sign = as.integer(apply(s, 2, function(x) if (all(x == x[1])) x[1] else NA)))
}

test_that("find_signs() agrees with an exhaustive search", {
  set.seed(42)
  for (case in seq_len(300)) {
    n <- sample(1:6, 1)
    scale <- sample(c(1, 1e3, 1e6, 1e9, 1e11), 1)
    v <- sample(c(round(runif(n, -1000, 1000)), rep(250, 3), 0), n) * scale
    fixed <- sample(c(0L, 0L, 0L, 1L, -1L), n, replace = TRUE)
    max_zeros <- sample(0:2, 1)
    target <- if (runif(1) < 0.75) sum(sample(-1:1, n, replace = TRUE) * v) else 7
    lab <- paste0("i", seq_len(n))

    got <- suppressWarnings(find_signs(
      data.frame(label = c(lab, "total"), value = c(v, target)), label, value,
      positive = lab[fixed == 1L], negative = lab[fixed == -1L],
      max_zeros = max_zeros))
    want <- brute_signs(v, target, max_zeros, fixed, 1e-6)

    info <- paste("case", case)
    expect_equal(got$status[1], want$status, info = info)
    if (want$status != "unsolved") {
      expect_equal(got$n_solutions[1], want$n, info = info)
      expect_equal(got$sign[seq_len(n)], want$sign, info = info)
    }
  }
})

# The bucket keys are sum / tol. At a hundred billion and the default 1e-6
# that is past 2^53, where a key and both its neighbours are the same double,
# and every solution was found three times over: unique answers came back as
# ambiguous with three solutions. 184 of 4,000 random cases did this.
test_that("a unique answer stays unique at a group's magnitudes", {
  df <- data.frame(label = c("revenue", "costs", "total"),
                   value = c(312e9, 187e9, 125e9))
  r <- find_signs(df, label, value)
  expect_equal(r$status[1], "unique")
  expect_equal(r$n_solutions[1], 1L)
  expect_equal(r$sign, c(1L, -1L, 1L))
})

# Order is not information. The same items in any order are the same problem.
test_that("find_signs() does not depend on the order of the items", {
  df <- data.frame(label = c("a", "b", "c", "d", "total"),
                   value = c(120, 45, 30, 15, 60))
  ref <- find_signs(df, label, value)
  ref <- ref[order(ref$label), ]
  for (k in 1:5) {
    p <- df[c(sample(4), 5), ]
    r <- find_signs(p, label, value)
    r <- r[order(r$label), ]
    expect_equal(r$sign, ref$sign)
    expect_equal(r$status, ref$status)
  }
})

test_that(".sign_grid() enumerates the constrained ranges", {
  free <- .sign_grid(2, c(0L, 0L))
  expect_equal(nrow(free), 9)
  expect_setequal(unique(as.vector(free)), c(-1L, 0L, 1L))

  constrained <- .sign_grid(2, c(1L, -1L))
  expect_equal(nrow(constrained), 4)
  expect_setequal(unique(constrained[, 1]), c(0L, 1L))
  expect_setequal(unique(constrained[, 2]), c(-1L, 0L))
})
