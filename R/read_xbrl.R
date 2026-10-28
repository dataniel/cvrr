#' Read XBRL filings
#'
#' Reads one filing, a vector of them, or a whole directory, and returns a
#' single tibble with one row per reported fact. The taxonomy is resolved as
#' the filings are read, so labels, the statement hierarchy and the
#' debit/credit marking arrive with the facts rather than in a second step.
#'
#' @section What an instance does and does not contain:
#' An XBRL instance holds facts, contexts and units -- and no human-readable
#' text at all. That is by design: the meaning of every element lives in the
#' *taxonomy* the filing points to with a single `link:schemaRef`. Labels, the
#' statement hierarchy and the debit/credit balance are published there, and
#' [add_taxonomy()] is what joins them on. The calculation weights are
#' published there too, but they are not read.
#'
#' Because the taxonomy is keyed by qualified name, the element's namespace is
#' returned alongside its local name. A Danish filing binds six or more
#' namespaces at once (`fsa` for the financial statements, `gsd` for company
#' data, `mrv` for management's review, `arr` for the auditor's report, ...),
#' and `elementid` alone cannot be looked up.
#'
#' @section Many filings, one table:
#' Every row carries the filing it came from: `file`, `cvr` and the four dates
#' of `period_start`, `period_end`, `prev_start` and `prev_end`. That is what
#' makes a directory of filings usable as one table, and it is why nothing
#' downstream takes a `period` argument any more -- the period is a column.
#'
#' Binding filings needs `fill`: each contributes only the dimension columns it
#' actually uses, so a filing tagging classes of equity has a
#' `dim_ClassesOfEquity` column and one that does not, does not.
#' `do.call(rbind, ...)` fails on that, which is reason enough for this
#' function to do the binding itself.
#'
#' A filing that cannot be parsed does not stop the read. Its path is collected
#' and all of them are reported once at the end, in `attr(x, "failed")`.
#'
#' @section Amounts are absolute:
#' A monetary fact is stated in its `unit` -- kroner, not thousands. The
#' `decimals` attribute says how *precise* the figure is, not what scale it is
#' on: `decimals = "-3"` means accurate to the nearest thousand, and the value
#' is still in kroner. The "tkr." at the head of a printed note is a
#' presentation choice for the human-readable text and does not reach the tags.
#'
#' Confirmed against a filing whose note prints its fixed assets as `62.113`
#' with the column headed tkr.: the tagged figure is `62113000`.
#'
#' A filing scaled wrong throughout is harder to catch than that, because it
#' stays internally consistent: its balance sheet still balances and its income
#' statement still reconciles. Registered capital looks like a check -- an A/S
#' must hold 400,000 kr, an ApS 40,000 -- but it only works for the A/S. Danish
#' entrepreneur companies (IVS) could be founded on a single krone until the
#' form was abolished in 2021, and 75 filings in a corpus of 4,304 report
#' capital under 1,000 kr with entirely ordinary assets. They are not scaled;
#' they are IVS, and the filing does not state its own legal form.
#'
#' What does catch it is a ratio between two reported figures that has to fall
#' in a known range. Payroll divided by the employee count is the readiest one:
#' a year of work costs somewhere between 100,000 and 1,500,000 kr, and a
#' filing claiming 194 kr has scaled one of the two.
#'
#' @section Dimensions:
#' A context may carry several `explicitMember` elements, and in Danish
#' filings roughly a fifth of them do. One of the common pairs is
#' `ConsolidatedSoloDimension`, which says whether a figure is the group's or
#' the parent's alone -- so keeping only the first member would silently mix
#' consolidated and solo amounts. All members are returned in
#' `explicit_member`, semicolon-separated, with the dimension each belongs to
#' in `dimensions` in the same order.
#'
#' @param path A directory, a path to a single filing, or a vector of either.
#'   Directories contribute every `.xml` file they hold.
#' @param taxonomy Resolve the taxonomy while reading. `TRUE`, the default,
#'   uses the tables packaged with cvrr -- see [cvrr_taxonomy_tables]. Pass a
#'   `cvrr_taxonomy` from [read_taxonomy()] for a version those do not cover,
#'   or `FALSE` for the facts alone; [add_taxonomy()] does the same job
#'   afterwards.
#' @param recurse Descend into subdirectories. Default `TRUE`, because filings
#'   are usually filed by year.
#' @param encoding Character encoding of the files. Defaults to `"UTF-8"`.
#'
#' @return A [`tibble`][tibble::tibble] with one row per fact: `file`, `cvr`,
#'   `period_start`, `period_end`, `prev_start`, `prev_end`, `elementid` (local
#'   name), `prefix` and `namespace`, `contextid`, `fact` (the text as tagged)
#'   and `value` (the same figure as a number, `NA` where the fact is text),
#'   `unitid`, `unit`, `decimals`, `schemaref`, `startdate`, `enddate`,
#'   `instant`, `dimensions` and `explicit_member`. With `taxonomy`, the
#'   columns [add_taxonomy()] adds. Dates are `Date`.
#'
#' @examples
#' \dontrun{
#' # a whole directory, taxonomy and all
#' x <- read_xbrl("materiale/xbrl")
#'
#' # one filing, facts only
#' read_xbrl("13645183_2024-12-31.xml", taxonomy = FALSE)
#' }
#'
#' @seealso [xbrl_accounts()] for the tables this feeds, [add_taxonomy()] to
#'   resolve the taxonomy separately, [cvr_download()] for fetching the
#'   filings.
#'
#' @importFrom xml2 read_xml xml_find_all xml_name xml_attr xml_text xml_ns
#' @importFrom xml2 xml_find_first
#' @importFrom cli cli_abort cli_warn cli_alert_success cli_progress_bar
#' @importFrom cli cli_progress_update cli_progress_done
#' @importFrom data.table data.table rbindlist
#' @importFrom tibble as_tibble
#' @export
read_xbrl <- function(path, taxonomy = TRUE, recurse = TRUE,
                      encoding = "UTF-8") {
  files <- .xbrl_files(path, recurse)
  many  <- length(files) > 1L
  t0    <- Sys.time()

  if (many) cli::cli_progress_bar("Reading filings", total = length(files))
  out <- vector("list", length(files))
  for (i in seq_along(files)) {
    if (many) cli::cli_progress_update()
    out[[i]] <- tryCatch(.read_instance(files[i], encoding),
                         error = function(e) NULL)
  }
  if (many) cli::cli_progress_done()

  failed <- files[vapply(out, is.null, logical(1))]
  out <- out[!vapply(out, is.null, logical(1))]
  if (length(out) == 0)
    cli::cli_abort("No filing in {.arg path} could be read.")

  # The progress bar covers the parsing and stops there, but two of the slowest
  # steps come after it: binding a directory's worth of tables, and resolving
  # the taxonomy. Left silent they read as a hang -- the bar has finished, so
  # the work looks finished.
  if (many) cli::cli_progress_step("Binding {length(out)} filings")
  x <- tibble::as_tibble(data.table::rbindlist(out, fill = TRUE))
  if (many) cli::cli_progress_done()

  .warn_unparsed(x)
  if (!isFALSE(taxonomy))
    x <- add_taxonomy(x, if (isTRUE(taxonomy)) NULL else taxonomy)

  if (length(failed))
    cli::cli_warn(c(
      "{length(failed)} filing{?s} could not be read.",
      "i" = "Their paths are in {.code attr(x, \"failed\")}."))
  attr(x, "failed") <- failed

  if (many) {
    elapsed <- .format_elapsed(Sys.time() - t0)
    cli::cli_alert_success(
      "{length(out)} filing{?s}, {nrow(x)} fact{?s}, {elapsed}.")
  }
  x
}

# A fact carrying a unit or a `decimals` attribute is one the filer declares to
# be a number. If it will not parse as one, that is worth saying out loud.
#
# The reason to check rather than assume: XBRL requires canonical `xs:decimal`,
# so a Danish thousands separator cannot occur -- and across 4,304 filings none
# does. The one that would be dangerous is `1.234` for 1234, because it parses
# silently as 1.234, off by a thousand. All 895 occurrences of that shape in the
# corpus are ratios (`ReturnOnEquity`, `OperatingMargin`) where the decimal is
# real, and the ten commas are house numbers ("7,1" is a first floor). The
# figures are written by filing software, not typed. This guard is what would
# catch a tool that stops doing so.
.warn_unparsed <- function(x) {
  declared <- !is.na(x$unitid) | !is.na(x$decimals)
  bad <- declared & is.na(x$value) & nzchar(x$fact) & grepl("[0-9]", x$fact)
  if (!any(bad)) return(invisible(NULL))

  ex <- unique(paste0(x$elementid[bad], " = ", x$fact[bad]))
  cli::cli_warn(c(
    "{sum(bad)} numeric fact{?s} did not parse as {?a number/numbers}.",
    "i" = "{.val {utils::head(ex, 3)}}",
    "i" = "They are {.field NA} in {.field value}; {.field fact} keeps the text."))
  invisible(NULL)
}

# A directory contributes its files; a file contributes itself. Mixing the two
# in one call is what makes "everything I downloaded, plus this one" easy.
.xbrl_files <- function(path, recurse) {
  if (!is.character(path) || length(path) == 0)
    cli::cli_abort("{.arg path} must be a character vector of files or directories.")

  missing <- path[!file.exists(path)]
  if (length(missing))
    cli::cli_abort(c("{length(missing)} path{?s} do{?es/} not exist.",
                     "x" = "{.path {missing[1]}}"))

  dirs  <- path[dir.exists(path)]
  files <- path[!dir.exists(path)]
  from_dirs <- unlist(lapply(dirs, list.files, pattern = "[.]xml$",
                             recursive = recurse, full.names = TRUE))
  files <- unique(c(files, from_dirs))
  if (length(files) == 0)
    cli::cli_abort(c("No {.field .xml} file in {.arg path}.",
                     "i" = if (!recurse) "Try {.code recurse = TRUE}."))
  files
}

# One instance document. Everything above this is about many of them.
.read_instance <- function(path, encoding = "UTF-8") {
  doc <- xml2::read_xml(path, encoding = encoding)
  ns  <- xml2::xml_ns(doc)

  fact_nodes    <- xml2::xml_find_all(doc, "//*[@contextRef]")
  context_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='context']")
  unit_nodes    <- xml2::xml_find_all(doc, ".//*[local-name()='unit']")

  if (length(fact_nodes) == 0)
    cli::cli_warn(c(
      "No XBRL facts in {.path {basename(path)}}.",
      "i" = "A fact is an element carrying a {.field contextRef} attribute; this file has none."
    ))

  # Every accessor below is vectorised over the whole nodeset. Building the
  # tables row by row was ~70x slower on a filing of ordinary size.
  facts <- data.table::data.table(
    # The taxonomy the filing declares. Carried on every row rather than as an
    # attribute because a panel binds many filings together and each names its
    # own: the version follows when the filing was prepared, not its year.
    schemaref = .schema_ref(doc),
    elementid    = xml2::xml_name(fact_nodes),
    prefix     = .qname_prefix(fact_nodes, ns),
    namespace  = .namespace_uri(fact_nodes, ns),
    contextid = .strip_prefix(xml2::xml_attr(fact_nodes, "contextRef")),
    fact       = xml2::xml_text(fact_nodes, trim = TRUE),
    unitid    = .strip_prefix(xml2::xml_attr(fact_nodes, "unitRef")),
    decimals   = xml2::xml_attr(fact_nodes, "decimals")
  )

  contexts <- data.table::data.table(
    # Ids are stripped on both sides of the join, so an id that does contain a
    # colon cannot break it. In valid XBRL neither side ever does.
    contextid = .strip_prefix(xml2::xml_attr(context_nodes, "id")),
    startdate = .as_date(.child_text(context_nodes, "startDate")),
    enddate   = .as_date(.child_text(context_nodes, "endDate")),
    instant    = .as_date(.child_text(context_nodes, "instant"))
  )
  contexts <- merge(contexts, .context_dimensions(doc, ns), by = "contextid",
                    all.x = TRUE, sort = FALSE)

  units <- data.table::data.table(
    unitid = .strip_prefix(xml2::xml_attr(unit_nodes, "id")),
    unit    = .child_text(unit_nodes, "measure")
  )

  merged <- merge(facts,  contexts, by = "contextid", all.x = TRUE, sort = FALSE)
  merged <- merge(merged, units,    by = "unitid",    all.x = TRUE, sort = FALSE)

  # The figure as a number, once, here. Every caller used to write this line
  # itself, and the ones that forgot compared amounts as text.
  merged$value <- suppressWarnings(as.numeric(merged$fact))

  # The filing's own identity, so that a bound table can be split again.
  merged$file <- path
  merged$cvr  <- .first_fact(merged, "IdentificationNumberCvrOfReportingEntity")
  p <- xbrl_period(merged)
  merged$period_start <- p$start
  merged$period_end   <- p$end
  merged$prev_start   <- p$prev_start
  merged$prev_end     <- p$prev_end

  cols <- c("file", "cvr", "period_start", "period_end", "prev_start",
            "prev_end", "elementid", "prefix", "namespace", "schemaref",
            "contextid", "fact", "value", "unitid", "unit", "decimals",
            "startdate", "enddate", "instant", "dimensions",
            "explicit_member")
  merged[, cols, with = FALSE]
}

# Dates are Date. A filing occasionally writes a datetime or a malformed date;
# that becomes NA rather than stopping the read of 4,000 other filings.
.as_date <- function(x) {
  as.Date(suppressWarnings(substr(x, 1, 10)), format = "%Y-%m-%d")
}

.first_fact <- function(x, elementid) {
  v <- x$fact[x$elementid == elementid & nzchar(x$fact)]
  if (length(v)) v[1] else NA_character_
}

# All explicitMembers per context, collapsed to one row each. A context with
# two dimensions gets both, in document order, so nothing is discarded.
.context_dimensions <- function(doc, ns) {
  nodes <- xml2::xml_find_all(
    doc, ".//*[local-name()='context']//*[local-name()='explicitMember']"
  )
  if (length(nodes) == 0)
    return(data.table::data.table(
      contextid = character(), dimensions = character(),
      explicit_member = character()
    ))

  owner <- xml2::xml_find_first(nodes, "ancestor::*[local-name()='context']")
  d <- data.table::data.table(
    contextid       = .strip_prefix(xml2::xml_attr(owner, "id")),
    dimensions      = .canonical_qname(xml2::xml_attr(nodes, "dimension"), ns),
    explicit_member = .canonical_qname(xml2::xml_text(nodes, trim = TRUE), ns)
  )
  collapse <- function(x) paste(x, collapse = ";")
  data.table::data.table(
    contextid       = names(tapply(d$dimensions, d$contextid, collapse)),
    dimensions      = unname(tapply(d$dimensions, d$contextid, collapse)),
    explicit_member = unname(tapply(d$explicit_member, d$contextid, collapse))
  )
}

# The taxonomy entry point the instance points at, from its single schemaRef.
.schema_ref <- function(doc) {
  n <- xml2::xml_find_first(doc, ".//*[local-name()='schemaRef']")
  if (inherits(n, "xml_missing")) return(NA_character_)
  href <- xml2::xml_attr(n, "href")
  if (is.na(href)) xml2::xml_attr(n, "xlink:href") else href
}

# Trimmed text of a namespace-agnostic child element, e.g. <...:startDate>.
# Vectorised: one value per node, NA where the child is absent.
.child_text <- function(nodes, name) {
  xml2::xml_text(
    xml2::xml_find_first(nodes, sprintf(".//*[local-name()='%s']", name)),
    trim = TRUE
  )
}

# The namespace URI an element belongs to, resolved through the document's own
# prefix bindings.
.namespace_uri <- function(nodes, ns) {
  if (length(nodes) == 0) return(character())
  qn <- xml2::xml_name(nodes, ns = ns)
  as.character(ns)[match(sub(":.*$", "", qn), names(ns))]
}

.qname_prefix <- function(nodes, ns) {
  if (length(nodes) == 0) return(character())
  sub(":.*$", "", xml2::xml_name(nodes, ns = ns))
}

# Rewrite a QName's prefix to the last segment of the namespace it resolves to,
# so the same dimension reads the same way in every filing. Prefixes are
# document-local and filers pick them freely: the member written
# `fsa:LandAndBuildingsMember` in one filing is `g:LandAndBuildingsMember` in
# the next, and `e:` means two different namespaces in two different filings.
.canonical_qname <- function(qnames, ns) {
  if (length(qnames) == 0) return(character())
  has_prefix <- grepl(":", qnames, fixed = TRUE)
  pre <- sub(":.*$", "", qnames)
  loc <- sub("^[^:]*:", "", qnames)
  uri <- as.character(ns)[match(pre, names(ns))]
  ifelse(has_prefix & !is.na(uri), paste0(sub(".*/", "", uri), ":", loc), qnames)
}

.strip_prefix <- function(x) sub("^[^:]+:", "", x)
