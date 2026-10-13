# A frame in the shape read_xbrl() returns. The note is read from the facts
# themselves, so no taxonomy columns are needed -- only the dates, which is
# what tells an opening balance from a closing one.
END  <- as.Date("2023-12-31")
PREV <- as.Date("2022-12-31")

fact <- function(elementid, value, instant = NA, enddate = NA,
                 member = NA_character_)
  data.frame(elementid = elementid, value = value,
             instant = as.Date(instant), enddate = as.Date(enddate),
             dimensions = if (is.na(member)) NA_character_
                          else "fsa:ClassesOfPropertyPlantAndEquipmentDimension",
             explicit_member = member, unit = "iso4217:DKK",
             stringsAsFactors = FALSE)

at   <- function(el, when, value, member = NA_character_)
  fact(el, value, instant = when, member = member)
over <- function(el, value, member = NA_character_)
  fact(el, value, enddate = END, member = member)

filing <- function(..., file = "a.xml", cvr = "12345678",
                   period_end = END, prev_end = PREV) {
  x <- rbind(...)
  x$file <- file
  x$cvr  <- cvr
  x$period_start <- prev_end + 1
  x$period_end   <- period_end
  x$prev_start   <- as.Date(NA)
  x$prev_end     <- prev_end
  x
}

# Cost 1000 + 300 - 100 = 1200; depreciation 400 + 150 = 550; carrying 650.
schedule <- function(...)
  filing(
    at("PropertyPlantAndEquipmentGross", PREV, 1000),
    over("AdditionsToPropertyPlantAndEquipment", 300),
    over("DisposalsOfPropertyPlantAndEquipment", 100),
    at("PropertyPlantAndEquipmentGross", END, 1200),
    at("AccumulatedImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment",
       PREV, 400),
    over("DepreciationOfPropertyPlantAndEquipment", 150),
    at("AccumulatedImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment",
       END, 550),
    at("PropertyPlantAndEquipment", END, 650),
    ...)

test_that("the note comes back as a roll-forward", {
  m <- xbrl_movements(schedule())

  expect_equal(m$layer[m$item == "additions"], "cost")
  expect_equal(m$value[m$layer == "cost" & m$item == "opening"], 1000)
  expect_equal(m$value[m$layer == "cost" & m$item == "additions"], 300)
  # Signed: a disposal takes away from cost whatever the filer wrote, and
  # `tagged` keeps what they wrote.
  expect_equal(m$value[m$layer == "cost" & m$item == "disposals"], -100)
  expect_equal(m$tagged[m$layer == "cost" & m$item == "disposals"], 100)
  expect_equal(m$value[m$layer == "cost" & m$item == "closing"], 1200)
  expect_equal(m$value[m$layer == "depreciation" & m$item == "charge"], 150)
  expect_equal(m$value[m$layer == "carrying" & m$item == "closing"], 650)
})

# One element, two balances. Which one it is comes from the instant it is
# tagged against, not from a second element name.
test_that("opening and closing are told apart by the date", {
  m <- xbrl_movements(schedule())
  cost <- m[m$layer == "cost" & m$item %in% c("opening", "closing"), ]

  expect_equal(nrow(cost), 2L)
  expect_equal(unique(cost$elementid), "PropertyPlantAndEquipmentGross")
  expect_equal(cost$value[cost$item == "opening"], 1000)
  expect_equal(cost$value[cost$item == "closing"], 1200)
})

test_that("the note keeps its rows in note order", {
  m <- xbrl_movements(schedule())
  cost <- m[m$layer == "cost", ]
  expect_equal(cost$item, c("opening", "additions", "disposals", "closing"))
})

test_that("a movement the filing does not report has no row", {
  m <- xbrl_movements(schedule())
  expect_false("transfers" %in% m$item)
  expect_false("revaluation" %in% m$layer)
})

# A note is tagged per asset class, and the undimensioned figure is the total.
# Summing across the classes and the NA row counts everything twice.
test_that("the asset class comes through, and NA is the total", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", END, 700,
       member = "fsa:LandAndBuildingsMember"),
    at("PropertyPlantAndEquipmentGross", END, 500,
       member = "fsa:PlantAndMachineryMember"),
    at("PropertyPlantAndEquipmentGross", END, 1200))
  m <- xbrl_movements(x)

  expect_equal(sort(m$class[!is.na(m$class)]),
               c("LandAndBuildings", "PlantAndMachinery"))
  expect_equal(m$value[is.na(m$class)], 1200)
  expect_equal(sum(m$value[!is.na(m$class)]), 1200)
})

test_that("filings are kept apart", {
  x <- rbind(schedule(), schedule(file = "b.xml", cvr = "22222222"))
  m <- xbrl_movements(x)

  expect_equal(sort(unique(m$cvr)), c("12345678", "22222222"))
  expect_equal(nrow(m[m$cvr == "12345678", ]), nrow(m[m$cvr == "22222222", ]))
})

test_that("a category can be asked for on its own", {
  m <- xbrl_movements(schedule(), category = "intangible")
  expect_equal(nrow(m), 0L)

  m <- xbrl_movements(schedule(), category = "tangible")
  expect_true(all(m$category == "tangible"))
})

# Intangibles amortise where tangibles depreciate, and the element names differ
# accordingly. Both land in the same `depreciation` layer.
test_that("amortisation of intangibles is the same layer as depreciation", {
  x <- filing(
    at("IntangibleAssetsGross", PREV, 500),
    over("AmortisationOfIntangibleAssets", 60),
    at("IntangibleAssets", END, 440))
  m <- xbrl_movements(x)

  expect_equal(unique(m$category), "intangible")
  expect_equal(m$value[m$layer == "depreciation" & m$item == "charge"], 60)
})

test_that("a frame that is not from read_xbrl is refused with a reason", {
  expect_error(xbrl_movements(data.frame(elementid = "Assets")), "read_xbrl")
})

test_that("a filing with no note at all comes back empty, not broken", {
  m <- xbrl_movements(filing(at("Assets", END, 1000)))
  expect_equal(nrow(m), 0L)
  expect_true(all(c("cvr", "layer", "item", "value") %in% names(m)))
})

# The signs are what make the note usable. Cost 1000 + 300 - 100 = 1200 closes
# for exactly one assignment, so it can be claimed.
test_that("the signs that close a block are solved for", {
  m <- xbrl_movements(schedule())
  cost <- m[m$layer == "cost", ]

  expect_true(all(cost$reconciled))
  expect_equal(cost$sign[cost$item == "additions"], 1)
  expect_equal(cost$sign[cost$item == "disposals"], -1)
  expect_equal(sum(cost$value[!cost$item %in% "closing"]),
               cost$value[cost$item == "closing"])
  expect_equal(cost$sign_source[cost$item == "additions"], "solved")
})

test_that("a block that cannot close is marked, not silently signed", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", PREV, 1000),
    over("AdditionsToPropertyPlantAndEquipment", 300),
    at("PropertyPlantAndEquipmentGross", END, 9999))
  m <- xbrl_movements(x)
  cost <- m[m$layer == "cost", ]

  expect_true(all(!cost$reconciled))
  # The arithmetic settled nothing, so the direction comes from what the row
  # is -- and says so, which is what lets a caller refuse it.
  expect_equal(cost$sign_source[cost$item == "additions"], "convention")
  expect_equal(cost$sign[cost$item == "additions"], 1)
})

test_that("a block with nothing to check is NA, not FALSE", {
  m <- xbrl_movements(filing(at("PropertyPlantAndEquipment", END, 650)))
  expect_true(all(is.na(m$reconciled)))
})

# The three blocks are a partition of one asset, so the one left out follows.
test_that("a missing block is derived from the other two", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", END, 1200),
    at("AccumulatedImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment",
       END, 550))
  m <- xbrl_movements(x)

  carry <- m[m$layer == "carrying" & m$item == "closing", ]
  expect_equal(carry$value, 650)
  expect_equal(carry$source, "derived: layers")
})

test_that("fill = FALSE returns only what the filing stated", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", END, 1200),
    at("AccumulatedImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment",
       END, 550))
  m <- xbrl_movements(x, fill = FALSE)

  expect_false("carrying" %in% m$layer)
  expect_true(all(m$source == "reported"))
})

test_that("nothing is derived where two blocks are missing", {
  m <- xbrl_movements(filing(at("PropertyPlantAndEquipmentGross", END, 1200)))
  expect_true(all(m$source == "reported"))
  expect_equal(nrow(m), 1L)
})

# A note covering land and buildings and stopping there is not wrong, but a
# figure taken from it is not the company's fixed assets.
test_that("a note that does not cover the balance sheet line is marked", {
  short <- filing(
    at("PropertyPlantAndEquipment", END, 1000),
    at("PropertyPlantAndEquipment", END, 400,
       member = "fsa:LandAndBuildingsMember"))
  expect_false(unique(xbrl_movements(short)$covers_balance))

  whole <- filing(
    at("PropertyPlantAndEquipment", END, 1000),
    at("PropertyPlantAndEquipment", END, 400,
       member = "fsa:LandAndBuildingsMember"),
    at("PropertyPlantAndEquipment", END, 600,
       member = "fsa:PlantAndMachineryMember"))
  expect_true(unique(xbrl_movements(whole)$covers_balance))
})

# Where the note is one undimensioned figure, it *is* the balance sheet line.
# Reporting that as a passed check would be a tautology.
test_that("coverage is NA where the note has no class breakdown", {
  m <- xbrl_movements(filing(at("PropertyPlantAndEquipment", END, 1000)))
  expect_true(all(is.na(m$covers_balance)))
})

# A schedule can close in every year and still break between them.
NEXT <- as.Date("2024-12-31")

year_pair <- function(opening) list(
  filing(at("PropertyPlantAndEquipmentGross", END, 1200), file = "y2023.xml"),
  filing(at("PropertyPlantAndEquipmentGross", END, opening),
         at("PropertyPlantAndEquipmentGross", NEXT, 1500),
         file = "y2024.xml", period_end = NEXT, prev_end = END))

test_that("last year's closing is checked against this year's opening", {
  p <- year_pair(1200)
  m <- xbrl_movements(rbind(p[[1]], p[[2]]))
  op <- m[m$item == "opening", ]

  expect_equal(nrow(op), 1L)
  expect_true(op$continuous)
})

test_that("a broken chain across years is marked", {
  p <- year_pair(999)
  m <- xbrl_movements(rbind(p[[1]], p[[2]]))
  expect_false(m$continuous[m$item == "opening"])
})

# The comparison is made on the opening row, but the answer is about the
# block. Left on the one row it was computed on, three rows in four came back
# NA and the column read as though nothing had been checked.
test_that("the continuity verdict is carried across the block", {
  p <- year_pair(1200)
  m <- xbrl_movements(rbind(p[[1]], p[[2]]))
  blk <- m[m$file == "y2024.xml" & m$layer == "cost", ]

  expect_gt(nrow(blk), 1L)
  expect_true(all(blk$continuous))
})

# Every row is labelled, whether or not an element carries it: opening and
# closing are the same element, so the taxonomy cannot name them apart, and a
# derived row has no element to look up at all.
test_that("every row carries the note line it belongs to", {
  m <- xbrl_movements(schedule())

  expect_false(any(is.na(m$label)))
  expect_equal(m$label[m$layer == "cost" & m$item == "opening"],
               "Kostpris primo")
  expect_equal(m$label[m$layer == "cost" & m$item == "closing"],
               "Kostpris ultimo")
  expect_equal(m$label[m$layer == "cost" & m$item == "disposals"], "Afgang")
  expect_false(any(is.na(m$label[is.na(m$elementid)])))
})

# A stated balance is not a movement. Before this, a note holding nothing but
# a carrying amount had sign NA, and `value * sign` -- the documented way to
# use the table -- was NA for half the corpus.
test_that("a balance is signed even where there is no arithmetic to solve", {
  m <- xbrl_movements(filing(at("PropertyPlantAndEquipment", END, 650)))

  expect_equal(m$value, 650)
  expect_equal(m$sign, 1)
  expect_equal(m$sign_source, "balance")
  expect_true(is.na(m$reconciled))
})

test_that("a filing with no preceding year has no continuity verdict", {
  m <- xbrl_movements(schedule())
  expect_true(all(is.na(m$continuous)))
})

# A movement reported as nought closes the block either way, so leaving it in
# the sign search makes the block ambiguous and throws away the signs of the
# movements that are not nil. A filer who tags a nil disposal tags a real
# addition beside it, so this is most of the corpus.
test_that("a nil movement does not cost the block its signs", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", PREV, 1000),
    over("AdditionsToPropertyPlantAndEquipment", 300),
    over("DisposalsOfPropertyPlantAndEquipment", 0),
    at("PropertyPlantAndEquipmentGross", END, 1300))
  m <- xbrl_movements(x)
  cost <- m[m$layer == "cost", ]

  expect_true(all(cost$reconciled))
  expect_equal(cost$sign[cost$item == "additions"], 1)
  expect_false(any(is.na(cost$sign)))
})

# Opening equals closing and nothing moved: the block closes, and the empty
# sign assignment is a solution rather than the absence of one.
test_that("a block that stood still closes", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", PREV, 1000),
    over("AdditionsToPropertyPlantAndEquipment", 0),
    at("PropertyPlantAndEquipmentGross", END, 1000))
  expect_true(all(xbrl_movements(x)$reconciled[
    xbrl_movements(x)$layer == "cost"]))
})

# Financial assets are not capital formation, and a note that swept them in
# would not be the fixed asset note.
test_that("financial investments are not a category", {
  expect_error(xbrl_movements(schedule(), category = "investments"),
               "should be one of")
  expect_equal(sort(unique(cvrr:::.MOVEMENT_MAP$category)),
               c("intangible", "tangible"))
})

# A note can account for its own line and still leave the company's fixed
# assets unexplained.
test_that("the notes are checked against the whole of fixed assets", {
  # Tangible broken down and complete, intangible on the balance sheet and
  # absent from the notes: covers_balance passes, covers_fixed_assets does not.
  x <- filing(
    at("PropertyPlantAndEquipment", END, 1000),
    at("PropertyPlantAndEquipment", END, 400,
       member = "fsa:LandAndBuildingsMember"),
    at("PropertyPlantAndEquipment", END, 600,
       member = "fsa:PlantAndMachineryMember"),
    fact("IntangibleAssets", 250, instant = END))
  m <- xbrl_movements(x)

  expect_true(unique(m$covers_balance[m$category == "tangible"]))
  expect_false(unique(m$covers_fixed_assets))
})

test_that("both notes together can cover the balance sheet", {
  x <- filing(
    at("PropertyPlantAndEquipment", END, 1000),
    at("PropertyPlantAndEquipment", END, 1000,
       member = "fsa:LandAndBuildingsMember"),
    at("IntangibleAssets", END, 250),
    at("IntangibleAssets", END, 250, member = "fsa:GoodwillMember"))
  expect_true(unique(xbrl_movements(x)$covers_fixed_assets))
})

# A group and its parent both report a fixed asset note, and the two sit next
# to each other undimensioned by class. Without choosing, the same block comes
# back twice with different figures, the roll-forward is checked against the
# wrong closing balance, and a pivot returns list columns.
test_that("consolidated and parent notes are not mixed", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", END, 1000),
    at("PropertyPlantAndEquipmentGross", END, 2500))
  x$basis <- c("parent", "consolidated")

  m <- xbrl_movements(x)
  expect_equal(nrow(m), 1L)
  expect_equal(m$value, 1000)

  g <- xbrl_movements(x, basis = "consolidated")
  expect_equal(g$value, 2500)
})

test_that("a table with no basis column is read whole", {
  m <- xbrl_movements(schedule())
  expect_gt(nrow(m), 0)
})

# Several elements can carry one row of the note, and where they co-occur they
# are additions to it, not alternative names for it: of the eight filings using
# the division-disposal element, two report an ordinary disposal beside it.
# Taking the first would drop a real movement.
test_that("two elements for one line are summed into one row", {
  x <- filing(
    at("PropertyPlantAndEquipmentGross", PREV, 1000),
    over("DisposalsOfPropertyPlantAndEquipment", 100),
    over("DisposalsOfPropertyPlantAndEquipmentByDivisionAndSaleOfOtherCompany",
         100),
    at("PropertyPlantAndEquipmentGross", END, 800))
  m <- xbrl_movements(x)
  dis <- m[m$item == "disposals", ]

  expect_equal(nrow(dis), 1L)
  expect_equal(dis$value, -200)
  expect_equal(dis$tagged, 200)
  # Naming one of two would say the line came from somewhere it half came from.
  expect_true(is.na(dis$elementid))
  expect_true(all(m$reconciled[m$layer == "cost"]))
})

test_that("one element keeps its name", {
  m <- xbrl_movements(schedule())
  expect_equal(m$elementid[m$item == "disposals"],
               "DisposalsOfPropertyPlantAndEquipment")
})

test_that("one row per class, per line", {
  m <- xbrl_movements(schedule())
  k <- paste(m$category, m$class, m$layer, m$item)
  expect_false(any(duplicated(k)))
})
