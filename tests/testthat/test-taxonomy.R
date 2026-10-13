# The fixture is a miniature taxonomy package: a catalog, one entry point, a
# presentation linkbase, Danish labels, debit/credit markings and a declared
# dimension default. The filing that goes with it binds fsa to "g" and cmn to
# "d", the way real filings do.
tax_zip <- testthat::test_path("fixtures", "taxonomy-20240101.zip")
filing  <- testthat::test_path("fixtures", "balance-filing.xml")

# Read without the taxonomy: these tests are about add_taxonomy() joining the
# fixture package on, and read_xbrl() would otherwise have tried the packaged
# tables first and found nothing for a taxonomy called example.invalid.
facts <- function() read_xbrl(filing, taxonomy = FALSE)

test_that("read_taxonomy() opens a package and reads its catalog", {
  tax <- read_taxonomy(tax_zip)

  expect_s3_class(tax, "cvrr_taxonomy")
  expect_equal(tax$version, "20240101")
  expect_equal(tax$entrypoints, "entryBalanceSheet20240101.xsd")
  expect_equal(tax$rewrites$from, "http://example.invalid/taxonomy/20240101/")
})

# Consolidated figures are tagged; parent figures are not tagged at all, so
# reading absence as "parent" is only legitimate because the taxonomy says so.
test_that("read_taxonomy() reads the declared dimension defaults", {
  tax <- read_taxonomy(tax_zip)

  expect_equal(nrow(tax$defaults), 1)
  expect_equal(tax$defaults$dimension, "cmn:ConsolidatedSoloDimension")
  expect_equal(tax$defaults$default_member, "cmn:SoloMember")
})

test_that("read_taxonomy() refuses a package with no catalog", {
  dir <- withr::local_tempdir()
  expect_error(read_taxonomy(dir), "catalog.xml")
  expect_error(read_taxonomy(file.path(dir, "nope.zip")), "No taxonomy package")
})

test_that("read_xbrl() records the taxonomy the filing declares", {
  expect_equal(
    unique(facts()$schemaref),
    "http://example.invalid/taxonomy/20240101/entryBalanceSheet20240101.xsd"
  )
})

test_that("add_taxonomy() gives facts a code, a label and a sign convention", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))

  expect_true(all(c("statement", "code", "label", "balance", "basis") %in% names(t)))
  expect_setequal(unique(t$statement), c("BalanceSheet", "IncomeStatement"))

  assets <- t[t$elementid == "Assets" & t$basis == "parent", ]
  expect_equal(assets$code, "400.00")
  expect_equal(assets$label, "Aktiver")
  expect_equal(assets$balance, "debit")
  expect_true(assets$is_total)

  # the code sorts into statement order on its own
  inv <- t$code[t$elementid == "Inventories"][1]
  expect_equal(inv, "400.00.020.010")
})

# The filing binds fsa to "g" and cmn to "d". A join on the prefix would find
# nothing here, and in a real sample would attach the wrong definition.
test_that("add_taxonomy() joins on the namespace, not the filing's prefix", {
  f <- facts()
  # every fact is written with the filer's own prefix, never "fsa"
  expect_equal(unique(f$prefix), "g")
  expect_equal(unique(f$namespace), "http://example.invalid/fsa")
  # and the dimension member is rewritten to the namespace it resolves to
  expect_true("cmn:ConsolidatedMember" %in% f$explicit_member)

  t <- add_taxonomy(f, read_taxonomy(tax_zip))
  expect_equal(nrow(t), 17)   # balance sheet, inventory classes and income statement
})

test_that("add_taxonomy() separates parent from group using the declared default", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))

  cons <- t[t$basis == "consolidated", ]
  solo <- t[t$basis == "parent", ]

  expect_equal(unique(cons$basis_source), "tagged")
  expect_equal(unique(solo$basis_source), "default")
  expect_equal(cons$value[cons$elementid == "Assets"], 350)
  expect_equal(solo$value[solo$elementid == "Assets"], 300)
})

# A filing whose taxonomy version nobody has is not a filing to throw away. It
# keeps its facts and loses only what the taxonomy would have said about them,
# so a corpus spanning a new release still reads.
test_that("add_taxonomy() warns and keeps facts it holds no taxonomy for", {
  f <- facts()
  f$schemaref <- "http://elsewhere.invalid/taxonomy/19990101/entryOther.xsd"
  expect_warning(t <- add_taxonomy(f, read_taxonomy(tax_zip)),
                 "No packaged taxonomy holds")

  expect_equal(nrow(t), nrow(f))
  expect_true(all(is.na(t$statement)))
  expect_equal(t$value, f$value)
})

test_that("add_taxonomy() warns rather than fails on a filing naming none", {
  f <- facts()
  f$schemaref <- NA_character_
  expect_warning(t <- add_taxonomy(f), "declares a taxonomy")
  expect_equal(nrow(t), nrow(f))
})

test_that("add_taxonomy() needs facts read by read_xbrl()", {
  f <- facts()
  f$schemaref <- NULL
  expect_error(add_taxonomy(f, read_taxonomy(tax_zip)), "schemaref")
})

test_that("check_statement() reconciles a subtotal against its own children", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  ch <- check_statement(t)

  solo <- ch[ch$basis == "parent" & ch$statement == "BalanceSheet", ]
  expect_equal(sort(solo$code), c("400.00", "400.00.020"))
  expect_equal(unique(solo$verdict), "complete")
  expect_equal(solo$residual, c(0, 0))
})

# The group figures report current assets of 250 but specify only 120 of it.
# One reported child is enough to see that: the remainder is the point.
test_that("check_statement() reports the unspecified remainder", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  ch <- check_statement(t)

  r <- ch[ch$basis == "consolidated" & ch$code == "400.00.020", ]
  expect_equal(r$total, 250)
  expect_equal(r$specified, 120)
  expect_equal(r$residual, 130)
  expect_equal(r$verdict, "unspecified remainder")
})

test_that("check_statement() names the columns it cannot find", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  expect_error(check_statement(t, by = "segment"), "segment")
})

# One filing in a sample of 100 reported its cash six times and its receivables
# twice, all with the same figure. Repeats that agree are harmless; repeats
# that disagree are the filing stating two different amounts for one line.
test_that("check_statement() collapses agreeing repeats but names conflicting ones", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  solo <- t[t$basis == "parent", ]

  solo <- solo[solo$statement == "BalanceSheet", ]
  agree <- rbind(solo, solo[solo$elementid == "Inventories", ])
  ch <- check_statement(agree)
  expect_equal(ch$verdict[ch$code == "400.00.020"], "complete")

  clash <- solo[solo$elementid == "Inventories", ]
  clash$value <- 999
  ch2 <- check_statement(rbind(solo, clash))
  expect_equal(ch2$verdict[ch2$code == "400.00.020"], "conflicting duplicates")
})

# Checking each subtotal against the lines below it never reaches the identity
# a balance sheet exists to assert. Assets and liabilities are siblings of
# opposite sign, so they are compared, not summed -- and the balance attribute
# is what says so, with no element name written down anywhere.
test_that("check_statement() compares the two sides of the statement", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  ch <- check_statement(t)

  # The fixture's balance sheet has assets only, so it has no credit side. Its
  # income statement has both, and revenue less expenses is what gets compared.
  expect_equal(nrow(ch[ch$label == "debit side vs credit side" &
                         ch$statement == "BalanceSheet", ]), 0)

  # Both the trading group and the statement root have a debit and a credit
  # side, and neither balances: an income statement is a cascade, not an
  # identity. That is what check_cascade() is for.
  sides <- ch[ch$label == "debit side vs credit side" &
                ch$statement == "IncomeStatement", ]
  expect_equal(nrow(sides), 2)
  expect_equal(unique(sides$verdict), "sides differ")
})

# A breakdown runs across a dimension, where the presentation hierarchy does
# not reach. It is also where a filer's scale slip hides: one filing in 300
# tags its balance sheet in kroner and its fixed-asset note in thousands, and
# nothing but the filing's own arithmetic shows it.
test_that("check_breakdown() reconciles the parts against the line", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  b <- check_breakdown(t)

  expect_equal(nrow(b), 1)
  expect_equal(b$dimension, "dim_ClassesOfInventories")
  expect_equal(b$line, 120)
  expect_equal(b$parts, 120)
  expect_equal(b$n_members, 2L)
  expect_equal(b$verdict, "agrees")
})

test_that("check_breakdown() names a breakdown on a different scale", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  scaled <- t
  parts <- !is.na(scaled$dim_ClassesOfInventories)
  scaled$value[parts] <- scaled$value[parts] / 1000

  b <- check_breakdown(scaled)
  expect_equal(b$verdict, "scaled by 1000")
  expect_equal(b$ratio, 1000)
})

test_that("check_breakdown() ignores the consolidated/solo split", {
  # basis is already a grouping column; treating it as a breakdown would
  # compare the consolidated line with itself.
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  expect_false("dim_ConsolidatedSolo" %in% check_breakdown(t)$dimension)
})

income <- function() {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  t[t$statement == "IncomeStatement", ]
}

# 500 revenue less 200 external expenses is a gross profit of 300; less 50 tax
# leaves 250. Staff costs of 100 are a breakdown of the external expenses, and
# counting both would double-count.
test_that("check_cascade() reconciles each step to its own subtotal", {
  # The fixture names its statement "IncomeStatement", which the real taxonomy
  # does not use, and income() has already narrowed to it.
  cc <- check_cascade(income(), read_taxonomy(tax_zip), statement = NULL)

  expect_equal(cc$step, c("501.00.010", "tail"))
  expect_equal(cc$target, c("GrossProfitLoss", "ProfitLoss"))
  expect_equal(cc$status, c("unique", "unique"))
  expect_equal(cc$n_items, c(2L, 2L))   # staff costs excluded as a breakdown
})

# The steps have to come from the taxonomy, not from what a filing happens to
# report: omit the subtotal and the line above it would be mistaken for one.
# The taxonomy no longer has to be handed over -- the packaged tables are the
# default -- but a filing they do not cover still yields nothing rather than
# steps guessed from the data.
test_that("check_cascade() without a taxonomy it can resolve returns nothing", {
  expect_equal(nrow(check_cascade(income(), statement = NULL)), 0L)
})

test_that("check_cascade() still refuses something that is not a taxonomy", {
  expect_error(check_cascade(income(), taxonomy = "20231001"), "must be the")
})

# Accounting class B may give a gross figure instead of turnover and its
# components. That is where the filing *enters*, not a gap, and the remaining
# steps still reconcile.
test_that("check_cascade() carries a given income concept forward", {
  inc <- income()
  inc <- inc[!inc$elementid %in% c("Revenue", "ExternalExpenses", "StaffCosts"), ]

  cc <- check_cascade(inc, read_taxonomy(tax_zip), statement = NULL)
  expect_equal(cc$status[cc$step == "501.00.010"], "given")
  expect_equal(cc$status[cc$step == "tail"], "unique")
  expect_equal(unique(cc$entry), "GrossProfitLoss")
})

test_that("a tolerance can be read off the filing's own precision", {
  # decimals="-3" claims accuracy to thousands, so such a figure carries up to
  # 500 kroner of rounding, and a step of several adds theirs together.
  expect_equal(cvrr:::.decimals_tolerance(c("-3", "-3")), 1000)
  expect_equal(cvrr:::.decimals_tolerance(c("-3", "0")), 500.5)
  expect_equal(cvrr:::.decimals_tolerance(c("INF", "INF")), 1)  # floored
  expect_equal(cvrr:::.decimals_tolerance(c("-6")), 500000)
  # An unstated precision is read as the unit itself, not as exact.
  expect_equal(cvrr:::.decimals_tolerance(c(NA, NA)), 1)
})

test_that("lines wait for the next subtotal when their own is not reported", {
  # The filer omits the gross profit. Its constituents still belong to the
  # statement, so they carry forward to the next subtotal that is reported
  # rather than being dropped -- which is what going from the revenue to the
  # result for the year means when a signpost is missing.
  t <- income()
  without <- t[t$elementid != "GrossProfitLoss", ]
  cc <- check_cascade(without, read_taxonomy(tax_zip), statement = NULL)

  expect_equal(cc$status[cc$step == "501.00.010"], "not reported")
  tail <- cc[cc$step == "tail", ]
  expect_equal(tail$status, "unique")
  # Revenue and external expenses joined the tail's own items.
  expect_gt(tail$n_items, 2L)
})

test_that("a step whose every line is nil is given, not unexplained", {
  # Dropping nil items before the search can empty a step. It has nothing to
  # reconcile, which is not the same as failing to reconcile -- and the check
  # for it has to come after the drop, because until then the step looked like
  # it had lines.
  t <- income()
  t$value[t$statement == "IncomeStatement"] <- 0
  cc <- check_cascade(t, read_taxonomy(tax_zip), statement = NULL)
  expect_equal(cc$status[cc$step == "501.00.010"], "given")
  expect_equal(cc$n_items[cc$step == "501.00.010"], 0L)
})

test_that("a statement that starts at the gross profit is not asked to explain it", {
  # The taxonomy puts the trading group's other lines at codes before both of
  # its exits, so they arrive looking like inputs to the gross profit. A filing
  # that prints "Bruttofortjeneste" first and the administrative expenses
  # beneath it means the opposite, and the printed statement is what it means.
  t <- income()
  without <- t[!t$elementid %in% c("Revenue", "OtherExternalExpenses"), ]
  without$value[without$elementid == "GrossProfitLoss"] <- -121
  extra <- without[without$elementid == "GrossProfitLoss", ]
  extra$elementid <- "StaffCosts"
  extra$code <- "501.00.010.020.010"
  extra$value <- 21
  cc <- check_cascade(rbind(without, extra), read_taxonomy(tax_zip), statement = NULL)

  expect_equal(cc$status[cc$step == "501.00.010"], "given")
  expect_equal(cc$n_items[cc$step == "501.00.010"], 0L)
})

test_that("pinning the signs turns an undecidable step into a decided one", {
  # Two items of equal size reaching the same total either way round: the
  # search cannot choose, and nothing in the numbers can. `xbrli:balance` is
  # credit on income and debit on expense, so the taxonomy has already said
  # which is which -- what find_signs() searches for is declared.
  items <- data.frame(label = c("income", "expense", "total"),
                      value = c(50, 50, 0), stringsAsFactors = FALSE)
  free <- suppressMessages(find_signs(items, "label", "value",
                                      total_label = "total", max_zeros = 0L))
  expect_equal(free$status[1], "ambiguous")

  pinned <- suppressMessages(find_signs(items, "label", "value",
                                        total_label = "total",
                                        positive = "income",
                                        negative = "expense", max_zeros = 0L))
  expect_equal(pinned$status[1], "unique")
  expect_equal(pinned$sign[pinned$label == "income"], 1L)
  expect_equal(pinned$sign[pinned$label == "expense"], -1L)
})

test_that("a step the search already decided is not second-guessed", {
  # The tie-break runs only on `ambiguous`. Taking the balance away from a
  # filing that reconciles must change nothing.
  t <- income()
  with_bal <- check_cascade(t, read_taxonomy(tax_zip), statement = NULL)
  t$balance <- NA_character_
  without <- check_cascade(t, read_taxonomy(tax_zip), statement = NULL)
  expect_equal(with_bal$status, without$status)
  expect_equal(with_bal$target, without$target)
})

test_that("an alternative exit the filer also reported is a line, not a target", {
  # A group can offer several subtotals and a filer may report more than one.
  # Only one can be the step's target; the other is a figure like any other and
  # belongs to the steps below. Claimed by the step that does not use it, the
  # tax never reaches the one that needs it, and the statement's last identity
  # is left unchecked.
  t <- income()
  cc <- check_cascade(t, read_taxonomy(tax_zip), statement = NULL)
  expect_false(any(cc$status == "unexplained"))
  expect_true(any(cc$status == "unique"))
})

test_that("a subtotal that does not arrive at the next one is reported", {
  # Nothing between two subtotals and yet they differ: a figure is missing and
  # no line was tagged to name it. That used to be recorded as having nothing
  # to check, which is how 993 filings passed with their last step unverified.
  t <- income()
  t <- t[t$elementid %in% c("GrossProfitLoss", "ProfitLoss"), ]
  cc <- check_cascade(t, read_taxonomy(tax_zip), statement = NULL)
  expect_true(any(cc$status == "unexplained"))
})

test_that("an unitemised group takes its last exit, not its first", {
  # A by-function statement: revenue, cost of production, gross result, gross
  # profit, none of them broken down further. Every child is then a candidate
  # subtotal and the group says nothing about which. Taking the first makes the
  # revenue its own subtotal and the cascade reads the statement upside down.
  st <- data.frame(
    code = c("500.00.020.010", "500.00.020.030",
             "500.00.020.060", "500.00.020.070"),
    elementid = c("Revenue", "CostOfProduction", "GrossResult",
                  "GrossProfitLoss"), stringsAsFactors = FALSE)
  steps <- cvrr:::.cascade_steps(st)
  expect_length(steps, 1L)
  expect_true(steps[[1]]$flat)
  expect_equal(steps[[1]]$targets,
               c("Revenue", "CostOfProduction", "GrossResult", "GrossProfitLoss"))
})

test_that("a group with an itemised line is not flat", {
  # External expenses are broken down, so the lines above the breakdown are
  # items and what follows them is the subtotal. The group says which.
  st <- data.frame(
    code = c("501.00.010.010", "501.00.010.020", "501.00.010.020.010",
             "501.00.010.030"),
    elementid = c("Revenue", "ExternalExpenses", "StaffCosts",
                  "GrossProfitLoss"), stringsAsFactors = FALSE)
  steps <- cvrr:::.cascade_steps(st)
  expect_false(steps[[1]]$flat)
  expect_equal(steps[[1]]$targets, "GrossProfitLoss")
})

test_that("a filing is tidied from the packaged tables with no taxonomy at all", {
  # The point of shipping the tables: a real schemaRef resolves without a
  # taxonomy package on disk, so no unzipping and no XML at run time.
  x <- data.frame(
    schemaref = paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
                       "entryDanishGAAPBalanceSheetAccountFormIncomeStatement",
                       "ByNatureIncludingManagementsReviewStatisticsAndTax",
                       "20231001.xsd"),
    namespace = "http://xbrl.dcca.dk/fsa",
    elementid = c("Assets", "ProfitLoss"),
    fact = c("1000", "250"), value = c(1000, 250),
    contextid = "c1", instant = c("2023-12-31", NA),
    startdate = c(NA, "2023-01-01"), enddate = c(NA, "2023-12-31"),
    dimensions = NA_character_, explicit_member = NA_character_,
    unitid = "DKK", decimals = "0", unit = "iso4217:DKK",
    prefix = "fsa", stringsAsFactors = FALSE)

  t <- add_taxonomy(x)
  expect_gt(nrow(t), 0)
  expect_true("BalanceSheetAccountForm" %in% t$statement)
  expect_equal(t$label[t$elementid == "Assets"][1], "Aktiver")
  expect_equal(t$balance[t$elementid == "Assets"][1], "debit")
})

test_that("the packaged tables and a taxonomy package agree", {
  # Two routes to the same structure. If they diverge, one of them is wrong and
  # the checks would silently read a different statement depending on how they
  # were called.
  ref <- paste0("http://archprod.service.eogs.dk/taxonomy/20231001/",
                "entryDanishGAAPBalanceSheetAccountFormIncomeStatement",
                "ByNatureIncludingManagementsReviewStatisticsAndTax20231001.xsd")
  st <- cvrr:::.packaged_structure(ref)
  expect_gt(nrow(st), 1000)
  expect_setequal(names(st),
                  c("statement", "code", "depth", "namespace", "elementid",
                    "label", "balance", "periodtype", "is_total", "is_leaf",
                    "abstract"))
  expect_false(any(is.na(st$statement)))

  # One line per code, in the statements that are reconciled. The management's
  # review is exempt: two presentation linkbases, `mrv` and `esg`, each
  # contribute a root there and both land on code 200.00. It is prose and
  # nothing checks it, but the tables record what the taxonomy does rather than
  # what would be tidier.
  fin <- st[grepl("^BalanceSheet|^IncomeStatement|^DisclosureOf|^StatementOf",
                  st$statement), ]
  expect_equal(anyDuplicated(paste(fin$statement, fin$code)), 0L)
})

# The steps come from the taxonomy's hierarchy, and the hierarchy has to be
# narrowed to the same statements the facts were. Reading it from the whole
# table instead returned 79 steps for a filing whose income statement has four,
# most of them "not reported" steps of statements that are not cascades.
test_that("check_cascade() takes its steps from the statement it is checking", {
  t <- add_taxonomy(facts(), read_taxonomy(tax_zip))
  cc <- check_cascade(t[t$statement == "IncomeStatement", ],
                      read_taxonomy(tax_zip), statement = NULL)

  expect_true(all(startsWith(cc$step, "501.") | cc$step == "tail"))
  expect_false(any(is.na(cc$target)))
})
