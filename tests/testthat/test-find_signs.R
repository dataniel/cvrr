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

test_that(".sign_grid() enumerates the constrained ranges", {
  free <- .sign_grid(2, c(0L, 0L))
  expect_equal(nrow(free), 9)
  expect_setequal(unique(as.vector(free)), c(-1L, 0L, 1L))

  constrained <- .sign_grid(2, c(1L, -1L))
  expect_equal(nrow(constrained), 4)
  expect_setequal(unique(constrained[, 1]), c(0L, 1L))
  expect_setequal(unique(constrained[, 2]), c(-1L, 0L))
})
