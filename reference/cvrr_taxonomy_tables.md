# The Danish annual report taxonomies, as tables

Every statement line of every entry point of twelve taxonomies, with the
dimension defaults that say what an untagged figure means, prepared so
that a filing can be given its labels and its structure without a
taxonomy package on disk.

## Format

`cvrr_line`, 61,584 rows – every statement line of every taxonomy:

- version:

  The taxonomy, as `"20231001"`.

- entry:

  The entry point, where a statement is presented differently by
  different ones. `NA` for the 562 that are not.

- statement:

  `"BalanceSheetAccountForm"`, `"IncomeStatementByNature"`, and so on.

- code:

  The line's position, as `"501.00.020.100"`. Ordering and containment
  are both read from it.

- depth:

  Its depth in the presentation tree.

- namespace:

  The concept's namespace URI – half of the key a filing is joined on,
  because a filer binds prefixes freely and `e` means fsa in one filing
  and sob in another.

- elementid:

  The concept's name, without a prefix.

- label:

  Its Danish label, as that version gives it.

- balance:

  `"debit"`, `"credit"` or `NA`: the direction a figure contributes,
  which is what
  [`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
  otherwise has to search for.

- periodtype:

  `"instant"` or `"duration"`.

- is_total, is_leaf, abstract:

  As the presentation declares them.

`cvrr_entry`, 2,837 rows – which statements an entry point offers:

- version, entry:

  The taxonomy and its entry point schema.

- statement:

  One row per statement offered.

`cvrr_default`, 301 rows – the member that applies when a dimension is
absent:

- version:

  The taxonomy.

- dimension:

  The dimension, as `"cmn:ConsolidatedSoloDimension"`.

- default_member:

  What an untagged figure means, as `"cmn:SoloMember"`.

The last is small and easy to overlook, and it decides what a figure
*is*. The consolidated/solo dimension defaults to solo, so a filing that
tags nothing is stating the parent company's column – which is why
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md)
can give every figure a `basis`. Leaving it out of these tables gave
every figure a `basis` of `NA`, and every check that reads the parent
column filtered on a value that was never there: the balance sheet went
from 4,267 validated to nought, silently, because nothing errored.

## Source

The taxonomy packages published by Erhvervsstyrelsen: thirteen versions,
20101108 to 20251001. The oldest contributes a dimension default and no
statement lines at all, so `cvrr_line` and `cvrr_entry` hold twelve
versions and `cvrr_default` thirteen.

The URI in a filing's `schemaRef` is an identifier and not an address –
that host answers 404 for every version, the current ones included – so
the packages come from Erhvervsstyrelsen's *Taksonomier* pages.

These tables are a convenience, not the only route. A version published
after this release is read from the package itself with
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md)
and passed to
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
and a filing declaring one the tables do not hold keeps its facts either
way – see
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

## Why two tables and not one, and why not three

A taxonomy offers around a dozen entry points – balance sheet in account
form or report form, income statement by nature or by function, with or
without the management's review – and they share their statements. Each
line therefore appears about four times in a flat table. Of 579
version-and-statement pairs, 539 are offered by several entry points and
presented identically by every one of them, 23 by a single entry point,
and only 17 genuinely differ. Those 17 are prose and sector-specific
disclosures – `ManagementsReview`, `GeneralAndSubmissionData`, the
statements for investment funds and insurers – and none of the
statements this package reconciles is among them. They keep an `entry`
of their own; the rest have `NA`. 239,595 rows become 61,584.

A third table, one row per element carrying its label, balance and
period type, was tried and taken out again. It looked like an obvious
saving – those attributes barely move between versions – but a filing
names its taxonomy in its `schemaRef` and is entitled to *that*
version's answer, and they do move: `balance` for 11 elements,
`periodtype` for 19, `label` for 275. Under xz the columns compress away
regardless: with them on the line the data is 0.18 MB, and without them
it was also 0.18 MB. The split cost correctness and saved nothing.

What genuinely varies is where a line sits. The code moves between
versions for 10.9% of element-and-statement pairs, and every step
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md)
derives comes from codes, so nothing is merged across versions.

## See also

[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
which joins a filing to these, and
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md)
for a package these do not yet hold.
