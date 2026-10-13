#' Give a filing's facts their names, place and sign convention
#'
#' Joins facts from [read_xbrl()] to the taxonomy they declare, so every
#' reported figure arrives with the statement it belongs to, a stable
#' accounting code, its Danish label, whether it is debit or credit, and
#' whether it is the group's figure or the parent company's.
#'
#' [read_xbrl()] calls this itself unless told not to. Reach for it directly
#' when the filings need a taxonomy package the cvrr tables do not hold, or
#' when the facts were read once and are to be joined more than one way.
#'
#' @section The join key is the namespace, not the prefix:
#' Filers bind namespace prefixes freely -- `d`, `e`, `f`, `g`,
#' `EOGS_202040000` all appear -- and the same letter means different
#' namespaces in different filings. Joining on the prefix looks equivalent and
#' silently attaches the wrong element definition, so the join runs on the
#' namespace URI.
#'
#' @section Parent company versus group:
#' Consolidated figures are tagged with a member of
#' `ConsolidatedSoloDimension`. Parent-company figures are **not tagged at
#' all**, and reading their absence as "parent" is only legitimate because the
#' taxonomy declares a default member for that dimension. This function reads
#' the declared default rather than assuming one, and records in
#' `basis_source` whether the filing said so (`"tagged"`) or the default
#' decided it (`"default"`) -- a figure that is the parent's only by default is
#' worth being able to find again.
#'
#' @section Codes:
#' The code comes from the taxonomy's own numbering: the role URI gives the
#' statement (`.../role/400.00/BalanceSheetAccountForm`) and the presentation
#' arcs' `order` values give the levels, so `400.00.020.010.020` is
#' "Assets, non-current, property plant and equipment" and sorts into statement
#' order on its own.
#'
#' @section Nothing is dropped:
#' A fact keeps its row whether or not the taxonomy has anything to say about
#' it. Two kinds do not:
#'
#' * **Facts in no statement** -- company data, the management's review, the
#'   auditor's report. They are the whole of what [xbrl_company()] reads, so
#'   dropping them would mean reading every filing twice. They come back with
#'   `statement` `NA`.
#' * **Facts whose taxonomy version is unknown**, because the filing declares
#'   an entry point newer than the packaged tables. Every taxonomy column is
#'   `NA` and one warning names the version, so a filing from a taxonomy this
#'   release has not caught up with degrades to its raw facts instead of
#'   disappearing. [read_taxonomy()] on the published package fixes it.
#'
#' @section One row per statement:
#' An element belongs to every statement that presents it, and many do:
#' `ProfitLoss` is the income statement's bottom line, the figure the proposed
#' distribution starts from, and a key figure. A fact therefore comes back once
#' per statement it appears in. Filter on `statement` before working with a
#' statement, and never sum across them.
#'
#' @param x A tibble from [read_xbrl()].
#' @param taxonomy A `cvrr_taxonomy` from [read_taxonomy()], or a list of them.
#'   `NULL`, the default, uses the taxonomies packaged with cvrr -- see
#'   [cvrr_taxonomy_tables] -- which covers 20121001 to 20251001 and needs
#'   nothing on disk. Pass a package only for a taxonomy those do not hold.
#' @param dimensions If `TRUE` (default), each dimension present in the data
#'   gets its own column holding the member that applies, named `dim_` plus
#'   the dimension's local name -- `dim_ClassesOfPropertyPlantAndEquipment`,
#'   `dim_ConsolidatedSolo`. The prefix is how [check_breakdown()] finds them
#'   again without having to guess.
#'
#' @return `x` with `statement`, `code`, `depth`, `label`, `is_total`,
#'   `is_leaf`, `balance`, `periodtype`, `basis`, `basis_source`, `is_line`
#'   (whether the fact is the statement line itself rather than a breakdown of
#'   it) and `period` added.
#'
#' @examples
#' \dontrun{
#' # normally not needed -- read_xbrl() does it
#' x <- read_xbrl("materiale/xbrl", taxonomy = FALSE)
#' x <- add_taxonomy(x)
#'
#' # a taxonomy version the packaged tables do not cover
#' add_taxonomy(x, read_taxonomy("XBRL20251001.zip"))
#' }
#'
#' @seealso [read_xbrl()], which calls this by default, [xbrl_accounts()] for
#'   the tables built on top of it, [read_taxonomy()].
#' @family taxonomy
#'
#' @importFrom cli cli_abort cli_warn cli_alert_success cli_progress_bar
#' @importFrom cli cli_progress_update cli_progress_done cli_progress_step
#' @importFrom data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
add_taxonomy <- function(x, taxonomy = NULL, dimensions = TRUE) {
  if (inherits(taxonomy, "cvrr_taxonomy")) taxonomy <- list(taxonomy)
  if (!is.null(taxonomy) &&
      !all(vapply(taxonomy, inherits, logical(1), "cvrr_taxonomy")))
    cli::cli_abort("{.arg taxonomy} must be a {.cls cvrr_taxonomy} or a list of them.")
  if (!"schemaref" %in% names(x))
    cli::cli_abort(c(
      "{.arg x} has no {.field schemaref} column.",
      "i" = "Read the filings with {.fn read_xbrl}; it records the taxonomy each declares."
    ))

  refs <- unique(x$schemaref)
  refs <- refs[!is.na(refs)]
  # A filing that names no taxonomy is not an error: it is a filing nothing can
  # be said about beyond its own facts, and that is what comes back.
  if (length(refs) == 0) {
    cli::cli_warn(c(
      "No filing in {.arg x} declares a taxonomy.",
      "i" = "A filing names one in {.field link:schemaRef}; these do not.",
      "i" = "The facts come back with every taxonomy column {.field NA}."))
    return(.blank_structure(x))
  }

  # One entry point at a time, and said out loud: on a corpus this is a merge
  # over a million rows per version and it is where read_xbrl() spends the
  # minute after its progress bar has finished.
  # The id is captured and passed: cli ties a bar to the frame that made it,
  # and the update here happens inside lapply's closure, which is a different
  # one.
  pb <- if (length(refs) > 1L)
    cli::cli_progress_bar("Resolving the taxonomy", total = length(refs))

  unknown <- character()
  out <- lapply(refs, function(ref) {
    if (!is.null(pb)) cli::cli_progress_update(id = pb)
    d  <- x[x$schemaref %in% ref, ]
    st <- .structure_for(ref, taxonomy)
    if (is.null(st)) {
      unknown <<- c(unknown, basename(ref))
      # The columns still appear, empty. Code downstream asks whether a fact is
      # a statement line, not whether the column exists, and a corpus that
      # spans a taxonomy release must not change shape halfway through.
      return(.blank_structure(d))
    }
    # all.x keeps the facts the taxonomy places in no statement. They are what
    # xbrl_company() reads, and re-reading every filing to get them back would
    # cost more than the rows do.
    merge(d, st, by = c("namespace", "elementid"), all.x = TRUE)
  })
  if (length(unknown))
    cli::cli_warn(c(
      "No packaged taxonomy holds {.val {unique(unknown)}}.",
      "i" = "Those facts keep their values; every taxonomy column is {.field NA}.",
      "i" = "Read the published package with {.fn read_taxonomy} and pass it in."))

  if (!is.null(pb)) cli::cli_progress_done(id = pb)
  out <- tibble::as_tibble(data.table::rbindlist(out, fill = TRUE))
  if (nrow(out) == 0) return(out)

  # The tail is not free either -- spreading the dimensions into columns is the
  # slowest thing left -- so the summary comes after it, not before. A line
  # that says "done" while a second of work remains is the whole complaint.
  if (!is.null(pb)) cli::cli_progress_step("Placing the facts")

  out <- .add_basis(out, .defaults_for(refs[1], taxonomy))
  out$is_line <- .is_statement_line(out$dimensions)

  # Not ifelse(): it drops the Date class and hands back a bare number.
  out$period <- out$instant
  out$period[is.na(out$period)] <- out$enddate[is.na(out$period)]

  if (dimensions) out <- .spread_dimensions(out)

  if (!is.null(pb)) {
    cli::cli_progress_done()
    placed <- sum(!is.na(out$statement))
    cli::cli_alert_success(
      "{length(refs)} taxonom{?y/ies}, {nrow(out)} rows, {placed} placed in a statement.")
  }
  out
}

# The taxonomy's columns, present and empty, for facts no taxonomy explains.
.blank_structure <- function(d) {
  d$statement  <- NA_character_
  d$code       <- NA_character_
  d$depth      <- NA_integer_
  d$label      <- NA_character_
  d$balance    <- NA_character_
  d$periodtype <- NA_character_
  d$is_total   <- NA
  d$is_leaf    <- NA
  d$abstract   <- NA
  d
}

# Which of the supplied packages can resolve this schemaRef, by catalog rule.
.taxonomy_for <- function(ref, taxonomy) {
  for (tax in taxonomy) {
    hit <- tax$rewrites$from[startsWith(ref, tax$rewrites$from)]
    if (length(hit) && basename(ref) %in% names(tax$entry_paths)) return(tax)
  }
  NULL
}

# The statements an entry point carries, read from its own linkbaseRefs rather
# than from a list of file names: which linkbases apply is the entry point's
# statement, and it differs between account form and current/long-term form,
# by-nature and by-function, and the "Excluding..." point that has none.
.entry_structure <- function(tax, ref) {
  key <- basename(ref)
  if (!is.null(tax$cache[[key]])) return(tax$cache[[key]])

  entry <- tax$entry_paths[[key]]
  doc   <- xml2::read_xml(entry)
  hrefs <- .xattr(xml2::xml_find_all(doc, ".//*[local-name()='linkbaseRef']"), "href")
  pre   <- hrefs[grepl("_pre[.]xml$", hrefs)]
  if (length(pre) == 0)
    cli::cli_abort("Entry point {.val {key}} declares no presentation linkbase.")

  base <- dirname(entry)
  tbl <- data.table::rbindlist(lapply(pre, function(h) {
    f <- file.path(base, h)
    if (!file.exists(f)) return(NULL)
    .presentation_table(f, base)
  }), fill = TRUE)
  tbl <- as.data.frame(tbl)

  codes <- tbl$code
  n_below <- vapply(codes, function(cd) sum(startsWith(codes, paste0(cd, "."))),
                    integer(1))
  tbl$is_leaf <- n_below == 0L

  # An element belongs to every statement that presents it, and many do:
  # ProfitLoss is the income statement's bottom line, the figure the proposed
  # distribution starts from, and a key figure. Forcing one home means choosing
  # arbitrarily -- first wins hands the balance sheet's own headline to a note,
  # most-descendants hands ProfitLoss to the distribution schedule -- so a fact
  # is returned once per statement it appears in. Filter on `statement`, and
  # never sum across them.
  tbl <- tbl[order(tbl$statement, tbl$code), ]
  tbl <- tbl[!duplicated(tbl[c("statement", "namespace", "elementid")]), ]

  tax$cache[[key]] <- tbl
  tbl
}

# One presentation linkbase -> one row per statement line, with the label,
# balance and hierarchical code attached.
.presentation_table <- function(path, base) {
  doc   <- xml2::read_xml(path)
  links <- xml2::xml_find_all(doc, ".//*[local-name()='presentationLink']")

  arcs <- do.call(rbind, lapply(links, function(lk) {
    role <- .xattr(lk, "role")
    locs <- xml2::xml_find_all(lk, ".//*[local-name()='loc']")
    map  <- stats::setNames(sub(".*#", "", .xattr(locs, "href")), .xattr(locs, "label"))
    a    <- xml2::xml_find_all(lk, ".//*[local-name()='presentationArc']")
    if (length(a) == 0) return(NULL)
    data.frame(
      statement = sub(".*/", "", role),
      prefix_code = sub(".*/role/([^/]+)/.*", "\\1", role),
      parent_id = unname(map[.xattr(a, "from")]),
      child_id  = unname(map[.xattr(a, "to")]),
      order     = as.numeric(xml2::xml_attr(a, "order")),
      stringsAsFactors = FALSE
    )
  }))
  if (is.null(arcs)) return(NULL)

  tree <- do.call(rbind, lapply(split(arcs, arcs$statement), .flatten_tree))
  ns   <- unique(sub("_.*$", "", tree$id))

  labels   <- do.call(rbind, lapply(ns, function(p) .labels_for(base, p)))
  balances <- do.call(rbind, lapply(ns, function(p) .balances_for(base, p)))

  out <- merge(tree, labels,   by = "id", all.x = TRUE, sort = FALSE)
  out <- merge(out,  balances, by = "id", all.x = TRUE, sort = FALSE)
  out$is_total[is.na(out$is_total)] <- FALSE
  out$elementid <- sub("^[^_]+_", "", out$id)
  # Abstract nodes are kept. They are never reported, so they cannot join to a
  # fact, but the statement's roots are abstract and the closing identity --
  # assets against liabilities and equity -- hangs below one of them.
  out[c("statement", "code", "depth", "namespace", "elementid", "label",
        "is_total", "balance", "periodtype", "abstract")]
}

# Walk parent/child arcs into one row per line, with a code built from the
# statement's own number and the arc orders.
.flatten_tree <- function(pre) {
  roots <- setdiff(pre$parent_id, pre$child_id)
  out <- list()
  walk <- function(node, depth, code) {
    out[[length(out) + 1L]] <<- data.frame(
      id = node, depth = depth, code = code,
      statement = pre$statement[1], stringsAsFactors = FALSE)
    kids <- pre[pre$parent_id == node, ]
    kids <- kids[order(kids$order), ]
    for (i in seq_len(nrow(kids)))
      walk(kids$child_id[i], depth + 1L,
           paste0(code, ".", formatC(kids$order[i], width = 3, flag = "0",
                                     format = "d")))
  }
  for (r in roots) walk(r, 0L, pre$prefix_code[1])
  do.call(rbind, out)
}

.labels_for <- function(base, prefix, lang = "da") {
  f <- list.files(file.path(base, prefix),
                  pattern = sprintf("^%s[-_]lab[-_]%s[.]xml$", prefix, lang),
                  full.names = TRUE)
  if (length(f) == 0) return(NULL)
  doc  <- xml2::read_xml(f[1])
  locs <- xml2::xml_find_all(doc, ".//*[local-name()='loc']")
  map  <- stats::setNames(sub(".*#", "", .xattr(locs, "href")), .xattr(locs, "label"))
  labs <- xml2::xml_find_all(doc, ".//*[local-name()='label']")
  lab  <- data.frame(id = .xattr(labs, "label"), role = .xattr(labs, "role"),
                     lang = xml2::xml_attr(labs, "lang"),
                     text = xml2::xml_text(labs, trim = TRUE),
                     stringsAsFactors = FALSE)
  arcs <- xml2::xml_find_all(doc, ".//*[local-name()='labelArc']")
  arc  <- data.frame(from = .xattr(arcs, "from"), to = .xattr(arcs, "to"),
                     stringsAsFactors = FALSE)
  arc$elementid <- unname(map[arc$from])

  m <- merge(arc, lab, by.x = "to", by.y = "id")
  m <- m[m$lang %in% lang & !is.na(m$elementid), ]
  std <- m[m$role == "http://www.xbrl.org/2003/role/label", ]
  std <- std[!duplicated(std$elementid), ]
  # An element given a totalLabel is used somewhere as a total of its siblings.
  tot <- unique(m$elementid[m$role == "http://www.xbrl.org/2003/role/totalLabel"])
  data.frame(id = std$elementid, label = std$text,
             is_total = std$elementid %in% tot, stringsAsFactors = FALSE)
}

.balances_for <- function(base, prefix) {
  f <- file.path(base, prefix, paste0(prefix, ".xsd"))
  if (!file.exists(f)) return(NULL)
  doc <- xml2::read_xml(f)
  els <- xml2::xml_find_all(doc, ".//*[local-name()='element']")
  data.frame(
    id         = xml2::xml_attr(els, "id"),
    namespace  = xml2::xml_attr(doc, "targetNamespace"),
    balance    = xml2::xml_attr(els, "balance"),
    periodtype = xml2::xml_attr(els, "periodType"),
    abstract   = !is.na(xml2::xml_attr(els, "abstract")) &
                   xml2::xml_attr(els, "abstract") == "true",
    stringsAsFactors = FALSE
  )
}

# Consolidated or parent, from the tag if there is one and from the taxonomy's
# declared default if there is not.
.add_basis <- function(x, defaults) {
  dflt <- defaults$default_member[grepl("ConsolidatedSolo", defaults$dimension)]
  dflt <- if (length(dflt)) dflt[1] else NA_character_

  tagged <- .dimension_member(x$dimensions, x$explicit_member, "ConsolidatedSolo")
  member <- ifelse(is.na(tagged), dflt, tagged)
  x$basis <- ifelse(is.na(member), NA_character_,
                    ifelse(grepl("ConsolidatedMember$", member),
                           "consolidated", "parent"))
  x$basis_source <- ifelse(is.na(tagged), "default", "tagged")
  x
}

# A figure carrying no dimension beyond consolidated/solo is the statement line
# itself; anything else is a breakdown of it and must not be added alongside.
.is_statement_line <- function(dimensions) {
  is.na(dimensions) | !grepl(";", dimensions) &
    grepl("ConsolidatedSolo", dimensions)
}

# One column per dimension actually present, named after the dimension and
# prefixed `dim_`. The prefix is what makes them findable again: identifying
# them by excluding the known column names instead means any character column
# a caller adds -- a taxonomy version, a source file -- is mistaken for a
# dimension and silently checked as one.
.spread_dimensions <- function(x) {
  dims <- unique(unlist(strsplit(stats::na.omit(x$dimensions), ";")))
  for (d in dims) {
    nm <- paste0("dim_", sub("Dimension$", "", sub("^[^:]+:", "", d)))
    if (nm %in% names(x)) next
    x[[nm]] <- sub("Member$", "", sub("^[^:]+:", "",
                    .dimension_member(x$dimensions, x$explicit_member, d)))
  }
  x
}

# The member of one named dimension, matched to it by position.
.dimension_member <- function(dims, members, want) {
  vapply(seq_along(dims), function(i) {
    if (is.na(dims[i])) return(NA_character_)
    d <- strsplit(dims[i], ";")[[1]]
    m <- strsplit(members[i], ";")[[1]]
    j <- grep(want, d, fixed = TRUE)
    if (length(j) == 0 || j[1] > length(m)) NA_character_ else m[j[1]]
  }, character(1))
}
