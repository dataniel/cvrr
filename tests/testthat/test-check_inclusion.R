filing <- function(note, ...) {
  extra <- list(...)
  d <- data.frame(
    elementid = c("DisclosureOfEmployeeBenefitsExpense", names(extra)),
    fact = c(note, unlist(lapply(extra, as.character))),
    stringsAsFactors = FALSE)
  d$dimensions <- NA_character_
  d
}

# The wording taken from a real filing, with the markup it arrives in.
REAL <- paste0("&lt;p&gt;Lønninger, andre omkostninger til social sikring ",
               "og andre personaleomkostninger er omkostningsført under ",
               "følgende poster:&lt;/p&gt;&lt;table&gt;&lt;tr&gt;&lt;td&gt;",
               "Administrationsomkostninger&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;")

test_that("a note that says where the wages went is read", {
  x <- filing(REAL, AdministrativeExpenses = 5000, EmployeeBenefitsExpense = 1200)
  r <- check_inclusion(x)
  expect_equal(nrow(r), 1L)
  expect_equal(r$within, "AdministrativeExpenses")
  expect_equal(r$elementid, "EmployeeBenefitsExpense")
  expect_equal(r$value, 1200)
  expect_equal(r$within_value, 5000)
})

test_that("the sentence the reading rests on comes back", {
  x <- filing(REAL, AdministrativeExpenses = 5000)
  expect_match(check_inclusion(x)$evidence, "Administrationsomkostninger")
  expect_false(grepl("<", check_inclusion(x)$evidence, fixed = TRUE))
})

test_that("naming the line is not enough without a verb of placement", {
  # A note listing administrative staff by headcount says nothing about where
  # the cost was booked.
  x <- filing("Selskabet har 3 ansatte i administrationen.",
              AdministrativeExpenses = 5000)
  expect_equal(nrow(check_inclusion(x)), 0L)
})

test_that("a placement elsewhere is reported as that place, not as administration", {
  x <- filing(paste("Personaleomkostninger er omkostningsført under",
                    "produktionsomkostninger."),
              AdministrativeExpenses = 5000)
  r <- check_inclusion(x)
  expect_equal(nrow(r), 1L)
  expect_equal(r$within, "CostOfSales")
  expect_true(r$sole)
})

test_that("distribution costs are found too", {
  x <- filing(paste("Lønninger er indeholdt i salgsomkostninger."),
              DistributionCosts = 900)
  r <- check_inclusion(x)
  expect_equal(r$within, "DistributionCosts")
  expect_equal(r$within_value, 900)
})

test_that("a filing with no such note returns nothing, not an error", {
  x <- data.frame(elementid = "Assets", fact = "100",
                  dimensions = NA_character_, stringsAsFactors = FALSE)
  expect_equal(nrow(check_inclusion(x)), 0L)
})

test_that("an unreported containing line still reports the inclusion", {
  # The note is the evidence; whether the figure was tagged is a separate
  # question, and a caller may still want to know the two overlap.
  x <- filing(REAL)
  r <- check_inclusion(x)
  expect_equal(nrow(r), 1L)
  expect_true(is.na(r$within_value))
})

test_that("something that is not a filing is refused", {
  expect_error(check_inclusion(data.frame(a = 1)), "read_xbrl")
})

test_that("a cost split between destinations is marked, not apportioned", {
  x <- filing(paste("Personaleomkostninger er omkostningsført under",
                    "produktionsomkostninger og administrationsomkostninger."),
              AdministrativeExpenses = 5000, CostOfSales = 3000)
  r <- check_inclusion(x)
  expect_equal(nrow(r), 2L)
  expect_false(any(r$sole))
  expect_setequal(r$within, c("AdministrativeExpenses", "CostOfSales"))
})

test_that("a single destination is marked as sole", {
  x <- filing(REAL, AdministrativeExpenses = 5000)
  expect_true(check_inclusion(x)$sole)
})
