#' The fixed asset note, movement by movement
#'
#' A filing's fixed asset schedule as it is printed: cost at the start of the
#' year, the year's additions, disposals and transfers, cost at the end, then
#' the same for accumulated depreciation and revaluation, and the carrying
#' amount that falls out of them. One row per movement, per asset class, per
#' filing.
#'
#' @section Why long and not wide:
#' The note is a roll-forward, and its point is that the arithmetic closes:
#' opening plus additions less disposals equals closing, on each of three
#' layers, and the three layers together give the carrying amount. A row per
#' movement lets that be followed, checked, and filtered on. The note's own
#' printed layout is one `pivot_wider()` away.
#'
#' @section What the columns mean:
#' `layer` is which of the note's blocks the row belongs to -- `"cost"`,
#' `"depreciation"` (accumulated depreciation, amortisation and impairment),
#' `"revaluation"`, or `"carrying"` for the net figure the balance sheet
#' carries. `item` is the row within the block: `"opening"` and `"closing"` for
#' the balances, and `"additions"`, `"disposals"`, `"transfers"`, `"charge"`,
#' `"reversals"` or `"revaluations"` for the movements between them. `label`
#' is the two of them in Danish, as a printed note writes the line: "Kostpris
#' primo", "Tilgang", "Årets af- og nedskrivninger".
#'
#' The label is the package's own and not the taxonomy's, because the
#' taxonomy's cannot name these rows. Opening and closing are the same element
#' at two dates -- `PropertyPlantAndEquipmentGross` is cost, and which balance
#' it is depends on the instant it is tagged against -- so the element's label
#' names both and distinguishes neither. The filing's own declared period is
#' what decides: `period_end` is the closing instant and the preceding period's
#' end is the opening one. A row derived from the other two layers has no
#' element at all, and is labelled just the same.
#'
#' @section The signs are solved, and applied:
#' A Danish filer tags a disposal as a positive number about as often as a
#' negative one, so the figures as tagged do not roll forward. What decides the
#' sign is the arithmetic: a layer closes for one assignment of plus and minus
#' and not for the others, and there are few enough movements in a block to
#' enumerate them.
#'
#' `value` is the figure with that sign applied -- a disposal is negative in it
#' whatever the filer wrote -- so a block sums: opening plus its movements is
#' closing, and `sum(value)` over a company's additions is what it invested.
#' `tagged` keeps the filer's own number beside it, `NA` on a derived row
#' because no one tagged it.
#'
#' `sign_source` says how the sign was arrived at, and the three answers are
#' not equally strong:
#'
#' * `"balance"` -- an opening or closing balance. A stated amount is not a
#'   movement and needs no sign; it is `+1` and always was.
#' * `"solved"` -- the block's arithmetic closes for exactly this assignment.
#' * `"convention"` -- nothing could be solved, so the direction is taken from
#'   what the row is: a disposal or a reversal reduces its layer, everything
#'   else keeps the sign it was given. Checked against the rows where the
#'   arithmetic *did* settle it, the rule agrees 5,121 times out of 5,148.
#'
#' Over the corpus that is 23,135 rows signed as balances, 5,148 solved and 498
#' by convention -- and no row left without a figure to add up.
#'
#' A caller who will only accept solved arithmetic filters on `sign_source`;
#' one who wants the note as the filer wrote it reads `tagged`.
#'
#' The check was tested by planting errors in blocks that rolled forward, one
#' movement at a time, in 500 filings. A figure off by 9,000, or written in
#' kroner where the note is in thousands, stopped the block rolling forward
#' in 129 of 129 blocks each time. The same movement with its sign flipped was
#' absorbed in 130 of 130. That is what solving the signs is for, because
#' filers write a disposal either way.
#'
#' @section What is derived, and what is checked:
#' `source` is `"reported"`, `"derived: layers"`, or `"derived: first year"`
#' for the opening balance of a company that did not yet exist. The three
#' blocks are a
#' partition of one asset -- carrying = cost - depreciation + revaluation at
#' any instant -- so a block the filer left out is determined by the other two.
#' Over the whole corpus the identity closes to within a krone for 2,290 of the
#' 2,358 blocks stating all three; read with depreciation added rather than
#' subtracted it closes for 176. `fill = FALSE` returns only what was reported.
#'
#' Four columns say whether to trust the result, and they answer different
#' questions. A note can pass any one of them and fail another.
#'
#' * `reconciled` -- does this block's roll-forward close *within* the year?
#'   Per filing, per class, per layer. `NA` where the filing gives no movements
#'   to check.
#' * `covers_balance` -- do the note's classes add up to the balance sheet line
#'   they belong to? A note covering land and buildings and stopping there is
#'   not wrong, but a figure taken from it is not the company's fixed assets.
#'   Over 4,304 filings, 1,378 class-broken notes cover their line and 99 do
#'   not. `NA` where the note has no class breakdown, because then the note's
#'   figure and the balance sheet's are the same fact and comparing them would
#'   be a tautology reported as a check.
#' * `covers_fixed_assets` -- do the two notes *together* account for the fixed
#'   assets the balance sheet carries? Per filing. A note can pass
#'   `covers_balance` and fail this: a filing that breaks down its tangible
#'   assets in full and says nothing about its intangibles is complete on the
#'   line it covers and silent on the rest. 1,198 filings pass and 109 fail;
#'   the remainder have no class-broken note to judge.
#' * `continuous` -- is the block's opening balance last year's closing
#'   balance? A schedule can close perfectly in every year and still break
#'   between them, when a company restates its cost or a filer starts the note
#'   over. The comparison is made on the opening row and the verdict is carried
#'   across the block, like the other three. Of 10,965 opening balances in the
#'   corpus, 7,387 had a preceding filing to compare with: 6,875 matched and
#'   512 did not. `NA` where the company has no preceding filing **in `x`** --
#'   read one year and every row is `NA`, which is the commonest reason for
#'   seeing no `TRUE` at all.
#'
#' @section The asset class:
#' A note is tagged per class -- land and buildings, plant and machinery,
#' fixtures and fittings -- with the total column often left untagged, because
#' the balance sheet already carries it. `class` is the class where the filing
#' tagged one and `NA` for the undimensioned figure. Summing across classes
#' *and* the `NA` row counts everything twice.
#'
#' @section How much of this a filing actually has:
#' 3,521 of 4,304 filings state a note at all, and most of them state very
#' little of it. Counted by how many filings use each tangible-asset element:
#' the carrying amount 3,471, cost 1,297, accumulated depreciation 1,181, the
#' year's charge 1,120, additions 790, disposals 406, transfers 99. Intangible
#' assets are a fraction of that again. The carrying amount and the charge are
#' near-universal and the full schedule is a minority, so the rows simply do
#' not appear where the filing is silent.
#'
#' @param x A tibble from [read_xbrl()].
#' @param category Which note: `"tangible"`, `"intangible"`, or both, which is
#'   the default. Financial assets are deliberately not here -- buying shares in
#'   a subsidiary is not capital formation, and a note that swept them in would
#'   not be the fixed asset note.
#' @param basis `"parent"` (default) or `"consolidated"`. A group and its
#'   parent both report a fixed asset note, and the two sit next to each other
#'   undimensioned by class -- without choosing, the same block comes back twice
#'   with different figures. An untagged figure is the parent's, because the
#'   taxonomy says so; see [add_taxonomy()].
#' @param fill Derive a block the filer left out from the other two. `FALSE`
#'   returns only what was reported.
#'
#' @return A tibble in note order: the key -- `cvr`, `name`, `period_start`,
#'   `period_end` -- then what the row is (`category`, `class`, `layer`,
#'   `item`, `label`, `elementid`), what it says (`value` with the sign
#'   applied, `tagged` as the filer wrote it, `currency`, `source`), and how
#'   far to trust it (`sign`, `sign_source`, `reconciled`, `covers_balance`,
#'   `covers_fixed_assets`, `continuous`), with `file` last. A movement the
#'   filing does not report has no row.
#'
#' @examples
#' \dontrun{
#' x <- read_xbrl("materiale/xbrl")
#' m <- xbrl_movements(x)
#'
#' # the note as it is printed
#' tidyr::pivot_wider(m, names_from = c(layer, item), values_from = value)
#'
#' # what the companies invested in tangible assets, by year
#' a <- m[m$category == "tangible" & m$item == "additions", ]
#' tapply(a$value, format(a$period_end, "%Y"), sum)
#'
#' # the same, on the schedules that close and nothing assumed
#' b <- a[a$reconciled %in% TRUE & a$sign_source == "solved", ]
#' }
#'
#' @seealso [xbrl_accounts()], which returns this beside the statements,
#'   [check_movement()] for the same reconciliation run over the raw facts, and
#'   [find_signs()] for the sign search on its own.
#' @family taxonomy
#'
#' @importFrom cli cli_abort
#' @importFrom data.table rbindlist
#' @importFrom tibble tibble as_tibble
#' @export
xbrl_movements <- function(x, category = c("tangible", "intangible"),
                           basis = c("parent", "consolidated"), fill = TRUE) {
  category <- match.arg(category, several.ok = TRUE)
  basis <- match.arg(basis)
  need <- c("file", "cvr", "elementid", "value", "period_end", "instant",
            "enddate")
  gone <- setdiff(need, names(x))
  if (length(gone) > 0)
    cli::cli_abort(c(
      "{cli::qty(length(gone))}Column{?s} not found in {.arg x}: {.val {gone}}.",
      "i" = "{.arg x} must be a tibble from {.fn read_xbrl}."))

  map <- .MOVEMENT_MAP[.MOVEMENT_MAP$category %in% category, , drop = FALSE]

  keep <- c("file", "cvr", "period_start", "period_end", "prev_end",
            "elementid", "value", "instant", "enddate", "dimensions",
            "explicit_member", "unit", "basis")
  d <- x[intersect(keep, names(x))]
  d <- d[!is.na(d$value) & d$elementid %in% map$elementid, , drop = FALSE]

  # A group and its parent both report a fixed asset note, and the two sit next
  # to each other undimensioned by class. Without this the same block appears
  # twice with different figures, the roll-forward is checked against the wrong
  # closing balance, and a pivot comes back as list columns. 549 of 28,889
  # blocks in the corpus are this.
  if ("basis" %in% names(d))
    d <- d[d$basis %in% basis, , drop = FALSE]
  if (nrow(d) == 0) return(.empty_movements())

  cur <- vapply(split(x$unit, x$file),
                function(u) .filing_currency(list(unit = u)), character(1))
  nm <- .filing_names(x)

  # Which filings are a company's first. Computed over the whole fact table,
  # not the note: an instant earlier than the year end anywhere in the filing
  # is a comparative, and a comparative means the company existed.
  no_prev  <- tapply(is.na(x$prev_end), x$file, all)
  earlier  <- tapply(x$instant < x$period_end, x$file,
                     function(v) any(v, na.rm = TRUE))
  first_yr <- no_prev & !earlier

  grp <- split(d, d$file)
  pb  <- .file_progress(grp, "  rolling notes forward")
  out <- lapply(grp, function(g) {
    .file_tick(pb)
    .movements_one(g, map, currency = unname(cur[g$file[1]]), fill = fill,
                   name = unname(nm[g$file[1]]),
                   first_year = isTRUE(unname(first_yr[g$file[1]])))
  })
  .file_done(pb)
  out <- data.table::rbindlist(out, fill = TRUE)
  if (nrow(out) == 0) return(.empty_movements())

  # Across years, which is why it cannot happen inside a filing.
  out <- .carry_forward(as.data.frame(out))
  out$prev_end <- NULL

  # The sign, applied. `value` is the figure that rolls forward -- a disposal
  # is negative in it whatever the filer wrote -- and `tagged` is that filer's
  # own number, kept so the reading can be checked and so nothing is quietly
  # rewritten. A derived row has no tagged figure, because no one tagged it.
  out$tagged <- ifelse(out$source == "reported", out$value, NA_real_)
  out$value  <- out$value * out$sign

  tibble::as_tibble(out[intersect(.MOVEMENT_COLUMNS, names(out))])
}


# The order the columns come back in: what the row is, then what it says, then
# how far to trust it. Written once, because .empty_movements() has to match a
# full table exactly.
.MOVEMENT_COLUMNS <- c(
  .KEYS, "category", "class", "layer", "item", "label", "elementid",
  "value", "tagged", "currency", "source", "sign", "sign_source",
  "reconciled", "covers_balance", "covers_fixed_assets", "continuous", "file")


# Which element carries which row of the note, per asset category.
#
# Not derivable from the taxonomy: it publishes the presentation hierarchy and
# the labels, but nothing that says "this element is the opening cost and that
# one is the year's charge". So the map is curated -- and curated against the
# corpus rather than against the element list, which is why the near-synonyms
# are here. A filing writes disposals as `DisposalsOf...` or, when it sold a
# division, `DisposalsOf...ByDivisionAndSaleOfOtherCompany`, and a map that
# knew only the first would report no disposals for the filings that had the
# largest.
#
# Opening and closing share an element and are told apart by the instant, which
# is why both rows name the same one.
.mv <- function(category, layer, item, periodtype, ...)
  data.frame(category = category, layer = layer, item = item,
             periodtype = periodtype, elementid = c(...),
             stringsAsFactors = FALSE)


.MOVEMENT_MAP <- rbind(
  # ---- tangible ----------------------------------------------------------
  .mv("tangible", "cost", "opening", "instant", "PropertyPlantAndEquipmentGross"),
  .mv("tangible", "cost", "additions", "duration",
      "AdditionsToPropertyPlantAndEquipment",
      "AdditionsToPropertyPlantAndEquipmentThroughMergersAndBusinessCombinations"),
  .mv("tangible", "cost", "disposals", "duration",
      "DisposalsOfPropertyPlantAndEquipment",
      "DisposalsOfPropertyPlantAndEquipmentByDivisionAndSaleOfOtherCompany"),
  .mv("tangible", "cost", "transfers", "duration",
      "IncreaseDecreaseOfPropertyPlantAndEquipmentThroughTransfers"),
  .mv("tangible", "cost", "closing", "instant", "PropertyPlantAndEquipmentGross"),

  .mv("tangible", "depreciation", "opening", "instant",
      "AccumulatedImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment"),
  .mv("tangible", "depreciation", "charge", "duration",
      "DepreciationOfPropertyPlantAndEquipment"),
  .mv("tangible", "depreciation", "reversals", "duration",
      "ReversalsOfImpairmentLossesAndDepreciationOfDisposedPropertyPlantAndEquipment",
      "ImpairmentLossesAndDepreciationOfDisposedPropertyPlantAndEquipment"),
  .mv("tangible", "depreciation", "transfers", "duration",
      "TransferImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment"),
  .mv("tangible", "depreciation", "closing", "instant",
      "AccumulatedImpairmentLossesAndDepreciationOfPropertyPlantAndEquipment"),

  .mv("tangible", "revaluation", "opening", "instant",
      "AccumulatedRevaluationOfPropertyPlantAndEquipment"),
  .mv("tangible", "revaluation", "revaluations", "duration",
      "RevaluationsOfPropertyPlantAndEquipment"),
  .mv("tangible", "revaluation", "reversals", "duration",
      "ReversalsOfRevaluationsOfDisposedPropertyPlantAndEquipment",
      "ReversalsOfRevaluationsOfPropertyPlantAndEquipmentFromPreviousPeriods"),
  .mv("tangible", "revaluation", "closing", "instant",
      "AccumulatedRevaluationOfPropertyPlantAndEquipment"),

  .mv("tangible", "carrying", "opening", "instant", "PropertyPlantAndEquipment"),
  .mv("tangible", "carrying", "closing", "instant", "PropertyPlantAndEquipment"),

  # ---- intangible --------------------------------------------------------
  .mv("intangible", "cost", "opening", "instant", "IntangibleAssetsGross"),
  .mv("intangible", "cost", "additions", "duration",
      "AdditionsToIntangibleAssets",
      "AdditionsToIntangibleAssetsThroughMergersAndBusinessCombinations",
      "AcquiredIntangibleAssets"),
  .mv("intangible", "cost", "disposals", "duration",
      "DisposalsOfIntangibleAssets"),
  .mv("intangible", "cost", "transfers", "duration",
      "IncreaseDecreaseOfIntangibleAssetsThroughTransfers"),
  .mv("intangible", "cost", "closing", "instant", "IntangibleAssetsGross"),

  .mv("intangible", "depreciation", "opening", "instant",
      "AccumulatedImpairmentLossesAndAmortisationOfIntangibleAssets"),
  .mv("intangible", "depreciation", "charge", "duration",
      "AmortisationOfIntangibleAssets"),
  .mv("intangible", "depreciation", "reversals", "duration",
      "ReversalsOfImpairmentLossesAndAmortisationOfDisposedIntangibleAssets",
      "ReversalsOfImpairmentLossesOfIntangibleAssetsFromPreviousPeriods"),
  .mv("intangible", "depreciation", "closing", "instant",
      "AccumulatedImpairmentLossesAndAmortisationOfIntangibleAssets"),

  .mv("intangible", "carrying", "opening", "instant", "IntangibleAssets"),
  .mv("intangible", "carrying", "closing", "instant", "IntangibleAssets")
)


# What the note calls the row, in Danish.
#
# The taxonomy has a label for every element in the map -- "Tilgang til
# materielle anlaegsaktiver", "Afskrivninger paa materielle anlaegsaktiver" --
# and it cannot be used here, for two reasons. Opening and closing are the
# *same element* at two instants, so the taxonomy's label names both and
# distinguishes neither: cost opening and cost closing would both read
# "Materielle anlaegsaktiver i alt". And a row this function derives from the
# other two layers has no element at all, so there would be nothing to look
# up for 2,634 rows of the corpus.
#
# So the label names the row, the way a printed note does, and `category` and
# `class` beside it say which asset it is about. Every combination the map can
# produce has one; a row can never come back unlabelled.
#
# Written with escapes because R CMD check requires ASCII source. In order:
# Kostpris primo / Tilgang / Afgang / Overfoersel / Kostpris ultimo /
# Af- og nedskrivninger primo / Aarets af- og nedskrivninger / Tilbagefoersel
# ved afgang / Af- og nedskrivninger ultimo / Opskrivninger primo / Aarets
# opskrivninger / Tilbagefoerte opskrivninger / Opskrivninger ultimo /
# Regnskabsmaessig vaerdi primo / Regnskabsmaessig vaerdi ultimo.
.MOVEMENT_LABELS <- c(
  "cost/opening"              = "Kostpris primo",
  "cost/additions"            = "Tilgang",
  "cost/disposals"            = "Afgang",
  "cost/transfers"            = "Overf\u00f8rsel",
  "cost/closing"              = "Kostpris ultimo",

  "depreciation/opening"      = "Af- og nedskrivninger primo",
  "depreciation/charge"       = "\u00c5rets af- og nedskrivninger",
  "depreciation/reversals"    = "Tilbagef\u00f8rsel ved afgang",
  "depreciation/transfers"    = "Overf\u00f8rsel",
  "depreciation/closing"      = "Af- og nedskrivninger ultimo",

  "revaluation/opening"       = "Opskrivninger primo",
  "revaluation/revaluations"  = "\u00c5rets opskrivninger",
  "revaluation/reversals"     = "Tilbagef\u00f8rte opskrivninger",
  "revaluation/closing"       = "Opskrivninger ultimo",

  "carrying/opening"          = "Regnskabsm\u00e6ssig v\u00e6rdi primo",
  "carrying/closing"          = "Regnskabsm\u00e6ssig v\u00e6rdi ultimo")

.movement_label <- function(layer, item)
  unname(.MOVEMENT_LABELS[paste(layer, item, sep = "/")])


# One filing's schedule, in note order.
.movements_one <- function(d, map, currency, fill, name, first_year) {
  end   <- d$period_end[1]
  opens <- c(d$prev_end[1], d$period_start[1])
  opens <- opens[!is.na(opens)]

  d$class <- .movement_class(d)

  # Over the map's *groups*, not its rows. Several elements can carry one row
  # of the note -- a filing writes disposals as `DisposalsOf...` or, having
  # sold a division, `DisposalsOf...ByDivisionAndSaleOfOtherCompany` -- and
  # they are alternatives, not additions. A filing that tags two of them was
  # coming back with two rows for one line, which double-counted the block and
  # turned a pivot into list columns.
  grp <- unique(map[c("category", "layer", "item", "periodtype")])
  rows <- lapply(seq_len(nrow(grp)), function(i) {
    m <- grp[i, ]
    els <- map$elementid[map$category == m$category & map$layer == m$layer &
                           map$item == m$item]
    h <- d[d$elementid %in% els, , drop = FALSE]
    if (nrow(h) == 0) return(NULL)

    # The date first. An instant element carries both balances, so narrowing by
    # class before narrowing by date would throw one of them away.
    if (m$periodtype == "instant") {
      when <- if (m$item == "closing") end else opens
      h <- h[h$instant %in% when, , drop = FALSE]
    } else {
      h <- h[h$enddate %in% end, , drop = FALSE]
    }
    if (nrow(h) == 0) return(NULL)

    # Then one row per class, summed over the elements that contribute to it.
    #
    # Several can. An ordinary purchase and an addition through a merger are
    # both additions, and a filing reporting both means both -- taking the
    # first would drop a real movement and leave the block unable to close.
    # Checked against the corpus: of the eight filings using the merger
    # element, one uses the ordinary one beside it, and two of the eight using
    # the division-disposal element use the ordinary disposal too. The pair
    # that never co-occurs is the two spellings of the disposed depreciation,
    # where summing and taking the first are the same thing anyway.
    #
    # The first dedupe is the taxonomy join, not the filing: a fact comes back
    # once per statement that presents it.
    h <- h[!duplicated(paste(h$elementid, h$class, h$value)), , drop = FALSE]
    h <- .sum_by_class(h)
    data.frame(file = h$file, cvr = h$cvr, name = name,
               period_start = h$period_start[1], period_end = end,
               prev_end = h$prev_end[1],
               category = m$category, class = h$class, layer = m$layer,
               item = m$item, label = .movement_label(m$layer, m$item),
               elementid = h$elementid, value = h$value,
               currency = currency, stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) return(NULL)

  out <- do.call(rbind, rows)
  out$source <- "reported"
  if (fill && first_year) out <- .first_year_opening(out)
  if (fill) out <- .fill_layers(out)
  out <- .reconcile_layers(out)
  .note_coverage(out, d, end)
}


# The asset class a row is tagged against, from whichever classes dimension the
# note used. NA is the undimensioned total, not an unknown class.
#
# Read from `dimensions` and `explicit_member` rather than from the `dim_`
# columns, so it works whether or not the taxonomy was spread out -- and so a
# category whose dimension this function has never heard of still resolves.
.movement_class <- function(d) {
  m <- .dimension_member(d$dimensions, d$explicit_member, "ClassesOf")
  sub("Member$", "", sub("^[^:]+:", "", m))
}


# One row per asset class, the value summed over the elements that carry it.
#
# `elementid` keeps the element's name where one contributed and is NA where
# several did: naming one of two would say the line came from somewhere it only
# half came from.
.sum_by_class <- function(h) {
  if (nrow(h) <= 1) return(h)
  key <- ifelse(is.na(h$class), "\r", h$class)
  if (anyDuplicated(key) == 0) return(h)

  keep <- !duplicated(key)
  out <- h[keep, , drop = FALSE]
  out$value <- as.vector(tapply(h$value, key, sum)[key[keep]])
  n <- as.vector(table(key)[key[keep]])
  out$elementid[n > 1] <- NA_character_
  out
}


# A company that did not exist held nothing.
#
# A first filing has a closing balance and the year's movements and no opening
# row at all, so the block has only one end and cannot be checked. But the
# opening is not missing: it is nought. Of the 232 filings whose note has a
# closing balance and no opening anywhere, 208 declare no preceding period.
#
# The absence of a declared comparative is not taken on its own -- the filing
# must also carry no instant earlier than its year end, so a comparative that
# was merely left untagged is not read as a beginning. That is the same guard
# the fixed asset figure used before this table replaced it.
.first_year_opening <- function(d, tol = 1) {
  key <- paste(d$category, d$class, d$layer, sep = "\r")
  add <- lapply(unique(key), function(k) {
    g <- d[key == k, , drop = FALSE]
    if (any(g$item == "opening") || !any(g$item == "closing")) return(NULL)
    if (!any(!g$item %in% c("opening", "closing"))) return(NULL)

    r <- g[1, , drop = FALSE]
    r$item <- "opening"
    r$label <- .movement_label(r$layer, "opening")
    r$elementid <- NA_character_
    r$value <- 0
    r$source <- "derived: first year"
    r
  })
  add <- add[!vapply(add, is.null, logical(1))]
  if (length(add) == 0) return(d)

  # In note order: an opening balance belongs at the top of its block.
  out <- rbind(d, do.call(rbind, add))
  ord <- order(match(paste(out$category, out$layer),
                     unique(paste(d$category, d$layer))),
               match(out$item, c("opening", "additions", "disposals",
                                 "transfers", "charge", "reversals",
                                 "revaluations", "closing")))
  out[ord, , drop = FALSE]
}


# carrying = cost - depreciation + revaluation, at one instant.
#
# The note's three blocks are a partition of the same asset, so a block the
# filer left out is determined by the other two -- the same argument the
# balance sheet identities rest on, and it holds as well: across the corpus
# the identity closes to within a krone for 2,290 of the 2,358 blocks that
# state all three. Read the other way round, with depreciation added rather
# than subtracted, it holds for 176. The convention is not in doubt.
#
# A revaluation block is absent far more often than it is nil, but a fixed
# asset that was never revalued has no revaluation, so absence is nought here.
# That is the one assumption in this function, and it is why a derived figure
# says so in `source`.
.fill_layers <- function(d, tol = 1) {
  key <- paste(d$category, d$class, d$item, sep = "\r")
  add <- lapply(unique(key[d$item %in% c("opening", "closing")]), function(k) {
    g <- d[key == k, , drop = FALSE]
    v <- function(l) {
      z <- g$value[g$layer == l]
      if (length(z) == 1) z else NA_real_
    }
    cost <- v("cost"); dep <- v("depreciation"); carry <- v("carrying")
    rev  <- v("revaluation"); rev0 <- if (is.na(rev)) 0 else rev

    miss <- c(cost = is.na(cost), depreciation = is.na(dep),
              carrying = is.na(carry))
    if (sum(miss) != 1) return(NULL)

    layer <- names(miss)[miss]
    value <- switch(layer,
      cost         = carry + dep - rev0,
      depreciation = cost - carry + rev0,
      carrying     = cost - dep + rev0)
    if (is.na(value)) return(NULL)

    r <- g[1, , drop = FALSE]
    r$layer <- layer
    r$label <- .movement_label(layer, r$item)
    r$elementid <- NA_character_
    r$value <- value
    r$source <- "derived: layers"
    r
  })
  add <- add[!vapply(add, is.null, logical(1))]
  if (length(add) == 0) return(d)
  rbind(d, do.call(rbind, add))
}


# Does each block of the note close, and with which signs?
#
# A layer is a roll-forward: opening plus the year's movements equals closing.
# The movements are reported without a usable sign -- a filer writes a disposal
# positive about as often as negative -- so the question is whether *some*
# assignment of plus and minus makes the block close. There are at most a
# handful of movements in a block, so the assignments are enumerated outright
# rather than solved.
#
# Every row ends with a sign, and `sign_source` says where it came from,
# because the three answers are not equally strong:
#
# * `"balance"` -- an opening or closing balance is a stated amount and not a
#   movement. There is nothing to solve, and a block that states nothing but a
#   carrying amount is not thereby unusable. This is most of the table: 23,135
#   of the corpus's 28,781 rows, and 15,583 of those sit in blocks with no
#   arithmetic at all. Signing them only where a block happened to close is
#   what made the table look half-finished.
# * `"solved"` -- the block closes for exactly this assignment.
# * `"convention"` -- nothing could be solved, so the direction is taken from
#   what the row is. See .conventional_sign().
.reconcile_layers <- function(d, tol = 1) {
  d$reconciled <- NA
  d$sign <- NA_real_
  d$sign_source <- NA_character_

  bal <- d$item %in% c("opening", "closing")
  d$sign[bal] <- 1
  d$sign_source[bal] <- "balance"

  key <- paste(d$category, d$class, d$layer, sep = "\r")
  for (k in unique(key)) {
    i <- which(key == k)
    g <- d[i, ]
    open  <- g$value[g$item == "opening"]
    close <- g$value[g$item == "closing"]
    mv    <- which(!g$item %in% c("opening", "closing"))

    # A block with no opening, no closing, or nothing between them states no
    # arithmetic, so there is nothing to be right or wrong about.
    if (length(open) != 1 || length(close) != 1 || length(mv) == 0) next

    # A movement reported as nought says nothing about its own sign, and both
    # readings of it close the block. Leaving it in the search makes every such
    # block ambiguous and throws away the signs of the movements that are not
    # nil -- which is most of the corpus, because a filer who tags a nil
    # disposal tags a real addition beside it.
    nil <- mv[abs(g$value[mv]) <= tol]
    real <- setdiff(mv, nil)

    target <- close - open
    fits <- .sign_fits(g$value[real], target, tol)

    d$reconciled[i] <- length(fits) > 0
    d$sign[i[nil]] <- 1
    d$sign_source[i[nil]] <- "solved"
    if (length(fits) == 1) {
      d$sign[i[real]] <- fits[[1]]
      d$sign_source[i[real]] <- "solved"
    }
  }

  todo <- is.na(d$sign)
  if (any(todo)) {
    d$sign[todo] <- .conventional_sign(d$item[todo], d$value[todo])
    d$sign_source[todo] <- "convention"
  }
  d
}


# The direction a movement has by what it is, for the rows the arithmetic could
# not settle.
#
# A disposal takes away from the layer it belongs to and an addition adds to
# it, whatever sign the filer wrote. So a disposal or a reversal tagged as a
# positive number is subtracted, and one already tagged negative is left alone;
# everything else keeps the sign it was given, which matters for the two
# elements that are signed by design -- transfers are named
# `IncreaseDecreaseOf...` and a revaluation can be downwards.
#
# Checked against the rows where the block did close and the sign is therefore
# known: the rule gives the same answer 5,121 times out of 5,148. The 27 it
# misses are 10 transfers, 8 reversals, 5 charges and 4 disposals. That is why
# it is a fallback and why `sign_source` says where a sign came from -- a
# caller who will only take solved arithmetic can filter on it.
.conventional_sign <- function(item, value) {
  ifelse(item %in% c("disposals", "reversals") & value > 0, -1, 1)
}


# Every +1/-1 assignment over `v` that hits `target`, deduplicated by the
# assignment itself. Nought is not offered: a movement the filing bothered to
# report is a movement that happened.
.sign_fits <- function(v, target, tol) {
  n <- length(v)
  if (n > 12) return(list())          # 4,096 combinations is already generous

  # Nothing to assign. The block closes if it stood still, and expand.grid()
  # with no arguments returns a 0x0 matrix that would answer "no" instead.
  if (n == 0)
    return(if (abs(target) <= tol) list(numeric(0)) else list())

  grid <- as.matrix(expand.grid(rep(list(c(1, -1)), n)))
  hit <- which(abs(as.vector(grid %*% v) - target) <= tol)
  unique(lapply(hit, function(r) as.vector(grid[r, ])))
}


# Does the note account for the whole of the asset the balance sheet carries?
#
# A note that covers land and buildings and stops there is not wrong, but a
# figure taken from it is not the company's fixed assets. The comparison is the
# note's closing carrying amount against the balance sheet line at the same
# date -- the total row where the filer tagged one, and the classes summed
# where it did not.
.note_coverage <- function(d, facts, end, tol = 1) {
  line <- list(tangible = "PropertyPlantAndEquipment",
               intangible = "IntangibleAssets")
  d$covers_balance <- NA

  # unique(): a fact comes back once per statement that presents it, and the
  # balance sheet total appears in three or four of them.
  bs_of <- function(el) {
    v <- unique(facts$value[facts$elementid %in% el & facts$instant %in% end &
                              is.na(facts$dimensions)])
    if (length(v) == 1 && !is.na(v)) v else NA_real_
  }

  # The note's own total: the class rows summed. Only a class-broken note says
  # anything here -- where the filer tagged one undimensioned figure, that
  # figure *is* the balance sheet line, and comparing them would be a tautology
  # reported as a check.
  note_of <- function(cat) {
    g <- d[d$category %in% cat & d$layer %in% "carrying" &
             d$item %in% "closing", , drop = FALSE]
    if (!any(!is.na(g$class))) NA_real_ else sum(g$value[!is.na(g$class)])
  }

  for (cat in unique(d$category)) {
    bs <- bs_of(line[[cat]])
    nt <- note_of(cat)
    if (is.na(bs) || is.na(nt)) next
    d$covers_balance[d$category == cat] <- abs(nt - bs) <= tol
  }

  # And the two notes together against the whole of fixed assets. A note can
  # account for its own line and still leave the company's fixed assets
  # unexplained -- a filing that breaks down its tangible assets in full and
  # says nothing about its intangibles passes the check above twice over and
  # this one not at all. Financial assets are deliberately outside both: buying
  # shares in a subsidiary is not capital formation.
  d$covers_fixed_assets <- NA
  bs <- c(bs_of("IntangibleAssets"), bs_of("PropertyPlantAndEquipment"))
  nt <- c(note_of("intangible"), note_of("tangible"))

  # A line the balance sheet does not state is nought, not unknown: a company
  # with no intangible assets has no intangible assets. But a note that is
  # missing where the balance sheet does carry the line is exactly the gap this
  # is looking for, so that case counts as nought on the note's side and the
  # check fails, which is the point.
  if (any(!is.na(bs)) && any(!is.na(nt))) {
    z <- function(v) sum(ifelse(is.na(v), 0, v))
    d$covers_fixed_assets <- abs(z(nt) - z(bs)) <= tol
  }
  d
}


# Last year's closing balance is this year's opening balance.
#
# A schedule can close perfectly in each year and still be wrong across them:
# a company that restated its cost, or a filer that started the note over,
# breaks the chain without breaking any single year's arithmetic. The check
# needs two filings for the same company, which is why it runs here and not
# inside one.
#
# The pairing is by date, not by position. A filing states the period its
# comparative belongs to, so the opening balance is matched to the closing
# balance of the filing that ended on that date -- a company with a gap in its
# filings gets no match rather than a wrong one.
.carry_forward <- function(d, tol = 1) {
  d$continuous <- NA
  close <- d[d$item %in% "closing", , drop = FALSE]
  if (nrow(close) == 0) return(d)

  k <- function(z, when)
    paste(z$cvr, z$category, z$class, z$layer, when, sep = "\r")

  open <- which(d$item %in% "opening")
  hit <- match(k(d[open, , drop = FALSE], d$prev_end[open]),
               k(close, close$period_end))
  d$continuous[open] <- ifelse(is.na(hit), NA,
                               abs(d$value[open] - close$value[hit]) <= tol)

  # The verdict belongs to the block, not to the one row the comparison was
  # made on. `reconciled` and the two coverage columns are already set on every
  # row of their block, and a column that is NA on three rows in four reads as
  # "nobody checked" rather than "this is asked of the opening balance".
  blk <- paste(d$file, d$category, d$class, d$layer, sep = "\r")
  v <- tapply(d$continuous, blk,
              function(z) if (all(is.na(z))) NA else all(z, na.rm = TRUE))
  d$continuous <- unname(v[blk])
  d
}


# The same shape a full one has, keys and all: a filing with no note must not
# change the columns a caller is working with.
.empty_movements <- function() {
  d <- tibble::tibble(
    file = character(), cvr = character(), name = character(),
    period_start = as.Date(character()), period_end = as.Date(character()),
    category = character(), class = character(),
    layer = character(), item = character(), label = character(),
    elementid = character(), value = numeric(), tagged = numeric(),
    currency = character(), source = character(),
    sign = numeric(), sign_source = character(), reconciled = logical(),
    covers_balance = logical(), covers_fixed_assets = logical(),
    continuous = logical())
  d[.MOVEMENT_COLUMNS]
}

