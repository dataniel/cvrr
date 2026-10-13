#' Read an XBRL taxonomy package
#'
#' Opens a taxonomy package -- a ZIP, or a directory already unpacked from one
#' -- and returns the object [add_taxonomy()] needs to give a filing's facts their
#' names, their place in a statement, and their sign convention.
#'
#' @section Why this is a separate step:
#' An XBRL instance carries facts, contexts and units and no readable text at
#' all. Every label, every statement hierarchy, every debit/credit marking
#' lives in the taxonomy the filing names in one `link:schemaRef`. That URI is
#' an *identifier*, not a download address -- for Danish filings the host it
#' points at answers 404 -- so the package has to be obtained separately and
#' resolved locally. `META-INF/catalog.xml` holds the rewrite rules that map
#' the URI onto a path inside the archive, and this function follows them.
#'
#' Get the Danish packages from Erhvervsstyrelsen's *Taksonomier, aktuelle* and
#' *Taksonomier, historiske* pages. One package per year is needed: the version
#' a filing declares follows when it was *prepared*, not its accounting year,
#' so a single year of accounts routinely spans several.
#'
#' @param path Path to a taxonomy package `.zip`, or to a directory holding an
#'   unpacked one.
#' @param exdir Directory to unpack a ZIP into. Defaults to a session temporary
#'   directory; give a stable path to unpack each package only once. On Windows
#'   keep it short: the deepest names inside a Danish package are long enough
#'   that a long `exdir` pushes the total past the 260-character path limit.
#'
#' @return An object of class `cvrr_taxonomy`: a list with `version`, `path`,
#'   `entrypoints` (the entry point schemas it offers), `defaults` (the member
#'   that applies when a dimension is absent) and the internals
#'   [add_taxonomy()] uses.
#'
#' @examples
#' \dontrun{
#' tax <- read_taxonomy("XBRL20241001.zip")
#' tax$entrypoints
#' tax$defaults
#' }
#'
#' @seealso [add_taxonomy()] to join a filing's facts to it, [read_xbrl()] to read
#'   the filing.
#' @family taxonomy
#'
#' @section An archive without a catalog:
#' Some archives in circulation are repacks and carry no `META-INF/catalog.xml`
#' -- the 20171001 taxonomy is only obtainable that way, and 31 filings of a
#' 4,304-filing corpus declare it.
#'
#' All the catalog does for these packages is map
#' `http://archprod.service.eogs.dk/taxonomy/<version>/` onto the directory the
#' files sit in, and the archive states the version in its own layout. Where
#' there is no catalog that mapping is reconstructed from the entry point
#' schemas' location, and a warning says so: it is a convention read off the
#' archive, not a rule the archive declared.
#'
#' @importFrom cli cli_abort cli_alert_info
#' @importFrom tibble as_tibble
#' @export
read_taxonomy <- function(path, exdir = NULL) {
  if (!file.exists(path))
    cli::cli_abort("No taxonomy package at {.path {path}}.")

  root <- if (dir.exists(path)) path else {
    ex <- exdir %||% file.path(tempdir(), "cvrr-taxonomy",
                               tools::file_path_sans_ext(basename(path)))
    if (!dir.exists(ex) || length(list.files(ex)) == 0) {
      dir.create(ex, recursive = TRUE, showWarnings = FALSE)
      .unzip_needed(path, ex)
    }
    ex
  }

  entries <- list.files(root, pattern = "^entry.*[.]xsd$", recursive = TRUE,
                        full.names = TRUE)

  catalog <- list.files(root, pattern = "^catalog[.]xml$", recursive = TRUE,
                        full.names = TRUE)
  rewrites <- if (length(catalog) > 0) .catalog_rewrites(catalog[1]) else
    .conventional_rewrites(root, entries, path)
  defaults <- .dimension_defaults(list.files(root, pattern = "_def[.]xml$",
                                             recursive = TRUE, full.names = TRUE))

  structure(
    list(
      version     = sub(".*?([0-9]{8}).*", "\\1", basename(path)),
      path        = normalizePath(root, winslash = "/", mustWork = FALSE),
      entrypoints = sort(basename(entries)),
      defaults    = tibble::as_tibble(defaults),
      rewrites    = rewrites,
      entry_paths = stats::setNames(entries, basename(entries)),
      cache       = new.env(parent = emptyenv())
    ),
    class = "cvrr_taxonomy"
  )
}

#' @export
print.cvrr_taxonomy <- function(x, ...) {
  cat("<cvrr_taxonomy>", x$version, "\n")
  cat("  ", length(x$entrypoints), " entry points, ",
      nrow(x$defaults), " dimension defaults\n", sep = "")
  cat("  ", x$path, "\n", sep = "")
  invisible(x)
}

# Unpack only what the resolver reads. A Danish package carries an
# `frm_injection/` tree whose file names run to 170 characters, which is never
# read and which pushes the extracted path past Windows' 260-character limit.
.unzip_needed <- function(zip, exdir) {
  inside <- utils::unzip(zip, list = TRUE)$Name
  keep <- grepl("META-INF/catalog[.]xml$", inside) |
    grepl("[.]xsd$", inside) |
    grepl("_(pre|def)[.]xml$", inside) |
    grepl("[-_]lab[-_][a-z]{2}[.]xml$", inside)
  keep <- keep & !grepl("frm_injection/", inside, fixed = TRUE)

  too_long <- nchar(file.path(exdir, inside[keep])) > 250
  if (any(too_long))
    cli::cli_abort(c(
      "{sum(too_long)} file{?s} in the package would exceed the path limit under {.path {exdir}}.",
      "i" = "Pass a shorter {.arg exdir}, e.g. {.code exdir = \"C:/tax\"}."
    ))

  utils::unzip(zip, files = inside[keep], exdir = exdir)
  invisible(sum(keep))
}

# catalog.xml maps the archprod URI onto a path inside the package. One rule is
# usually enough, but the spec allows several and they are longest-match.
.catalog_rewrites <- function(path) {
  doc <- xml2::read_xml(path)
  n <- xml2::xml_find_all(doc, ".//*[local-name()='rewriteURI']")
  d <- data.frame(
    from = xml2::xml_attr(n, "uriStartString"),
    to   = xml2::xml_attr(n, "rewritePrefix"),
    stringsAsFactors = FALSE
  )
  d[order(-nchar(d$from)), ]
}

# The member that applies when a dimension is absent from a context. This is
# what decides parent-versus-group: consolidated figures carry a tag, parent
# figures carry nothing, and reading the absence correctly is only legitimate
# because the taxonomy declares SoloMember the default.
.dimension_defaults <- function(def_files) {
  rows <- lapply(def_files, function(f) {
    doc  <- xml2::read_xml(f)
    arcs <- xml2::xml_find_all(doc, ".//*[local-name()='definitionArc']")
    arcs <- arcs[grepl("dimension-default", .xattr(arcs, "arcrole"))]
    if (length(arcs) == 0) return(NULL)
    locs <- xml2::xml_find_all(doc, ".//*[local-name()='loc']")
    map  <- stats::setNames(sub(".*#", "", .xattr(locs, "href")), .xattr(locs, "label"))
    data.frame(
      dimension      = sub("_", ":", unname(map[.xattr(arcs, "from")])),
      default_member = sub("_", ":", unname(map[.xattr(arcs, "to")])),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) return(data.frame(dimension = character(),
                                      default_member = character()))
  unique(out[!is.na(out$dimension), ])
}

# xlink:-prefixed attributes: which spelling xml2 reports depends on how the
# document declares the namespace, so ask for both.
.xattr <- function(nodes, name) {
  v <- xml2::xml_attr(nodes, name)
  if (all(is.na(v))) v <- xml2::xml_attr(nodes, paste0("xlink:", name))
  v
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# What the catalog would have said. Every Danish package maps one URI prefix --
# archprod's taxonomy path for its own version -- onto the directory holding
# the files, and the version is written into the entry point's own file name.
# Only reached where the archive carries no catalog, which is how the 20171001
# taxonomy circulates.
.conventional_rewrites <- function(root, entries, path) {
  if (length(entries) == 0)
    cli::cli_abort(c(
      "No {.file META-INF/catalog.xml} and no entry point schema in {.path {path}}.",
      "i" = "A package carries one of the two; without either there is nothing to resolve a filing against."
    ))
  version <- regmatches(basename(entries[1]),
                        regexpr("[0-9]{8}", basename(entries[1])))
  if (length(version) == 0)
    version <- regmatches(basename(path), regexpr("[0-9]{8}", basename(path)))
  if (length(version) == 0)
    cli::cli_abort(c(
      "No {.file META-INF/catalog.xml} in {.path {path}}, and no version to reconstruct one from.",
      "i" = "The version is normally written into the entry point's file name."
    ))

  from <- paste0("http://archprod.service.eogs.dk/taxonomy/", version, "/")
  cli::cli_warn(c(
    "No {.file META-INF/catalog.xml} in {.path {basename(path)}}; assuming the usual layout.",
    "i" = "{.val {from}} is read as {.path {dirname(entries[1])}}."
  ))
  data.frame(from = from, to = paste0(dirname(entries[1]), "/"),
             stringsAsFactors = FALSE)
}
