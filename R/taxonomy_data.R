#' The Danish annual report taxonomies, as tables
#'
#' Every statement line of every entry point of twelve taxonomies, with the
#' dimension defaults that say what an untagged figure means, prepared so that a
#' filing can be given its labels and its structure without a taxonomy package
#' on disk.
#'
#' @section Why two tables and not one, and why not three:
#' A taxonomy offers around a dozen entry points -- balance sheet in account
#' form or report form, income statement by nature or by function, with or
#' without the management's review -- and they share their statements. Each
#' line therefore appears about four times in a flat table. Of 579
#' version-and-statement pairs, 539 are offered by several entry points and
#' presented identically by every one of them, 23 by a single entry point, and
#' only 17 genuinely differ. Those 17 are prose and sector-specific
#' disclosures -- `ManagementsReview`, `GeneralAndSubmissionData`, the
#' statements for investment funds and insurers -- and none of the statements
#' this package reconciles is among them. They keep an `entry` of their own;
#' the rest have `NA`. 239,595 rows become 61,584.
#'
#' A third table, one row per element carrying its label, balance and period
#' type, was tried and taken out again. It looked like an obvious saving --
#' those attributes barely move between versions -- but a filing names its
#' taxonomy in its `schemaRef` and is entitled to *that* version's answer, and
#' they do move: `balance` for 11 elements, `periodtype` for 19, `label` for
#' 275. Under xz the columns compress away regardless: with them on the line
#' the data is 0.18 MB, and without them it was also 0.18 MB. The split cost
#' correctness and saved nothing.
#'
#' What genuinely varies is where a line sits. The code moves between versions
#' for 10.9% of element-and-statement pairs, and every step [check_cascade()]
#' derives comes from codes, so nothing is merged across versions.
#'
#' @format
#' `cvrr_line`, 61,584 rows -- every statement line of every taxonomy:
#' \describe{
#'   \item{version}{The taxonomy, as `"20231001"`.}
#'   \item{entry}{The entry point, where a statement is presented differently
#'     by different ones. `NA` for the 562 that are not.}
#'   \item{statement}{`"BalanceSheetAccountForm"`, `"IncomeStatementByNature"`,
#'     and so on.}
#'   \item{code}{The line's position, as `"501.00.020.100"`. Ordering and
#'     containment are both read from it.}
#'   \item{depth}{Its depth in the presentation tree.}
#'   \item{namespace}{The concept's namespace URI -- half of the key a filing is
#'     joined on, because a filer binds prefixes freely and `e` means fsa in one
#'     filing and sob in another.}
#'   \item{elementid}{The concept's name, without a prefix.}
#'   \item{label}{Its Danish label, as that version gives it.}
#'   \item{balance}{`"debit"`, `"credit"` or `NA`: the direction a figure
#'     contributes, which is what [find_signs()] otherwise has to search for.}
#'   \item{periodtype}{`"instant"` or `"duration"`.}
#'   \item{is_total, is_leaf, abstract}{As the presentation declares them.}
#' }
#'
#' `cvrr_entry`, 2,837 rows -- which statements an entry point offers:
#' \describe{
#'   \item{version, entry}{The taxonomy and its entry point schema.}
#'   \item{statement}{One row per statement offered.}
#' }
#'
#' `cvrr_default`, 301 rows -- the member that applies when a dimension is
#' absent:
#' \describe{
#'   \item{version}{The taxonomy.}
#'   \item{dimension}{The dimension, as `"cmn:ConsolidatedSoloDimension"`.}
#'   \item{default_member}{What an untagged figure means, as
#'     `"cmn:SoloMember"`.}
#' }
#'
#' The last is small and easy to overlook, and it decides what a figure *is*.
#' The consolidated/solo dimension defaults to solo, so a filing that tags
#' nothing is stating the parent company's column -- which is why [add_taxonomy()]
#' can give every figure a `basis`. Leaving it out of these tables gave every
#' figure a `basis` of `NA`, and every check that reads the parent column
#' filtered on a value that was never there: the balance sheet went from 4,267
#' validated to nought, silently, because nothing errored.
#'
#' @source The taxonomy packages published by Erhvervsstyrelsen: thirteen
#'   versions, 20101108 to 20251001. The oldest contributes a dimension default
#'   and no statement lines at all, so `cvrr_line` and `cvrr_entry` hold twelve
#'   versions and `cvrr_default` thirteen.
#'
#'   The URI in a filing's `schemaRef` is an identifier and not an address --
#'   that host answers 404 for every version, the current ones included -- so
#'   the packages come from Erhvervsstyrelsen's *Taksonomier* pages.
#'
#'   These tables are a convenience, not the only route. A version published
#'   after this release is read from the package itself with [read_taxonomy()]
#'   and passed to [add_taxonomy()], and a filing declaring one the tables do
#'   not hold keeps its facts either way -- see [add_taxonomy()].
#'
#' @seealso [add_taxonomy()], which joins a filing to these, and [read_taxonomy()]
#'   for a package these do not yet hold.
#' @name cvrr_taxonomy_tables
#' @aliases cvrr_line cvrr_entry cvrr_default
NULL

# The statement table for a filing's declared entry point, from the packaged
# tables rather than from a taxonomy package on disk.
#
# A schemaRef names both: the version is the path segment after `taxonomy/`,
# and the entry point is the file. Restricting to the statements that entry
# point offers matters -- without it a filing would collect statements from
# every other entry point of the same version.
.packaged_structure <- function(ref) {
  if (is.na(ref)) return(NULL)
  # Built once per entry point and session. The packaged tables do not
  # change, and building the structure for every filing that declares the same
  # entry point was a fifth of what reading a balance sheet cost.
  hit <- .STRUCTURE_CACHE[[ref]]
  if (!is.null(hit)) return(if (identical(hit, FALSE)) NULL else hit)
  out <- .packaged_structure_build(ref)
  assign(ref, if (is.null(out)) FALSE else out, envir = .STRUCTURE_CACHE)
  out
}

.STRUCTURE_CACHE <- new.env(parent = emptyenv())

.packaged_structure_build <- function(ref) {
  version <- sub("^.*/taxonomy/([^/]+)/.*$", "\\1", ref)
  entry <- basename(ref)
  if (identical(version, ref)) return(NULL)

  offered <- cvrr_entry$statement[cvrr_entry$version == version &
                                    cvrr_entry$entry == entry]
  if (length(offered) == 0) return(NULL)

  l <- cvrr_line[cvrr_line$version == version &
                   cvrr_line$statement %in% offered &
                   (is.na(cvrr_line$entry) | cvrr_line$entry == entry), ,
                 drop = FALSE]
  if (nrow(l) == 0) return(NULL)

  data.frame(
    statement = l$statement, code = l$code, depth = l$depth,
    namespace = l$namespace, elementid = l$elementid, label = l$label,
    balance = l$balance, periodtype = l$periodtype,
    is_total = l$is_total, is_leaf = l$is_leaf, abstract = l$abstract,
    stringsAsFactors = FALSE)
}

# The statement table for a ref, from a taxonomy package where one is given and
# from the packaged tables otherwise. Every caller that needs a filing's
# structure goes through here, so the two sources cannot drift apart.
.structure_for <- function(ref, taxonomy = NULL) {
  if (is.null(taxonomy)) return(.packaged_structure(ref))
  tax <- .taxonomy_for(ref, taxonomy)
  if (is.null(tax)) return(NULL)
  .entry_structure(tax, ref)
}

# The dimension defaults for a ref, from a package or from the packaged tables.
#
# These are what make an untagged figure mean the parent company: the taxonomy
# declares `cmn:SoloMember` as the default of `cmn:ConsolidatedSoloDimension`,
# so a filing that tags nothing is stating the parent's column. Leave them out
# and every figure has a `basis` of NA -- and every check that reads the parent
# column filters on a value that is never there, which is what happened the
# first time these tables were run over the corpus.
.defaults_for <- function(ref, taxonomy = NULL) {
  if (!is.null(taxonomy)) {
    tax <- .taxonomy_for(ref, taxonomy)
    return(if (is.null(tax)) NULL else tax$defaults)
  }
  if (is.na(ref)) return(NULL)
  version <- sub("^.*/taxonomy/([^/]+)/.*$", "\\1", ref)
  d <- cvrr_default[cvrr_default$version == version, , drop = FALSE]
  if (nrow(d) == 0) NULL else d
}
