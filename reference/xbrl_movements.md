# The fixed asset note, movement by movement

A filing's fixed asset schedule as it is printed: cost at the start of
the year, the year's additions, disposals and transfers, cost at the
end, then the same for accumulated depreciation and revaluation, and the
carrying amount that falls out of them. One row per movement, per asset
class, per filing.

## Usage

``` r
xbrl_movements(
  x,
  category = c("tangible", "intangible"),
  basis = c("parent", "consolidated"),
  fill = TRUE
)
```

## Arguments

- x:

  A tibble from
  [`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).

- category:

  Which note: `"tangible"`, `"intangible"`, or both, which is the
  default. Financial assets are deliberately not here – buying shares in
  a subsidiary is not capital formation, and a note that swept them in
  would not be the fixed asset note.

- basis:

  `"parent"` (default) or `"consolidated"`. A group and its parent both
  report a fixed asset note, and the two sit next to each other
  undimensioned by class – without choosing, the same block comes back
  twice with different figures. An untagged figure is the parent's,
  because the taxonomy says so; see
  [`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md).

- fill:

  Derive a block the filer left out from the other two. `FALSE` returns
  only what was reported.

## Value

A tibble in note order: the key – `cvr`, `name`, `period_start`,
`period_end` – then what the row is (`category`, `class`, `layer`,
`item`, `label`, `elementid`), what it says (`value` with the sign
applied, `tagged` as the filer wrote it, `currency`, `source`), and how
far to trust it (`sign`, `sign_source`, `reconciled`, `covers_balance`,
`covers_fixed_assets`, `continuous`), with `file` last. A movement the
filing does not report has no row.

## Why long and not wide

The note is a roll-forward, and its point is that the arithmetic closes:
opening plus additions less disposals equals closing, on each of three
layers, and the three layers together give the carrying amount. A row
per movement lets that be followed, checked, and filtered on. The note's
own printed layout is one `pivot_wider()` away.

## What the columns mean

`layer` is which of the note's blocks the row belongs to – `"cost"`,
`"depreciation"` (accumulated depreciation, amortisation and
impairment), `"revaluation"`, or `"carrying"` for the net figure the
balance sheet carries. `item` is the row within the block: `"opening"`
and `"closing"` for the balances, and `"additions"`, `"disposals"`,
`"transfers"`, `"charge"`, `"reversals"` or `"revaluations"` for the
movements between them. `label` is the two of them in Danish, as a
printed note writes the line: "Kostpris primo", "Tilgang", "Årets af- og
nedskrivninger".

The label is the package's own and not the taxonomy's, because the
taxonomy's cannot name these rows. Opening and closing are the same
element at two dates – `PropertyPlantAndEquipmentGross` is cost, and
which balance it is depends on the instant it is tagged against – so the
element's label names both and distinguishes neither. The filing's own
declared period is what decides: `period_end` is the closing instant and
the preceding period's end is the opening one. A row derived from the
other two layers has no element at all, and is labelled just the same.

## The signs are solved, and applied

A Danish filer tags a disposal as a positive number about as often as a
negative one, so the figures as tagged do not roll forward. What decides
the sign is the arithmetic: a layer closes for one assignment of plus
and minus and not for the others, and there are few enough movements in
a block to enumerate them.

`value` is the figure with that sign applied – a disposal is negative in
it whatever the filer wrote – so a block sums: opening plus its
movements is closing, and `sum(value)` over a company's additions is
what it invested. `tagged` keeps the filer's own number beside it, `NA`
on a derived row because no one tagged it.

`sign_source` says how the sign was arrived at, and the three answers
are not equally strong:

- `"balance"` – an opening or closing balance. A stated amount is not a
  movement and needs no sign; it is `+1` and always was.

- `"solved"` – the block's arithmetic closes for exactly this
  assignment.

- `"convention"` – nothing could be solved, so the direction is taken
  from what the row is: a disposal or a reversal reduces its layer,
  everything else keeps the sign it was given. Checked against the rows
  where the arithmetic *did* settle it, the rule agrees 5,121 times out
  of 5,148.

Over the corpus that is 23,135 rows signed as balances, 5,148 solved and
498 by convention – and no row left without a figure to add up.

A caller who will only accept solved arithmetic filters on
`sign_source`; one who wants the note as the filer wrote it reads
`tagged`.

## What is derived, and what is checked

`source` is `"reported"`, `"derived: layers"`, or
`"derived: first year"` for the opening balance of a company that did
not yet exist. The three blocks are a partition of one asset – carrying
= cost - depreciation + revaluation at any instant – so a block the
filer left out is determined by the other two. Over the whole corpus the
identity closes to within a krone for 2,290 of the 2,358 blocks stating
all three; read with depreciation added rather than subtracted it closes
for 176. `fill = FALSE` returns only what was reported.

Four columns say whether to trust the result, and they answer different
questions. A note can pass any one of them and fail another.

- `reconciled` – does this block's roll-forward close *within* the year?
  Per filing, per class, per layer. `NA` where the filing gives no
  movements to check.

- `covers_balance` – do the note's classes add up to the balance sheet
  line they belong to? A note covering land and buildings and stopping
  there is not wrong, but a figure taken from it is not the company's
  fixed assets. Over 4,304 filings, 1,378 class-broken notes cover their
  line and 99 do not. `NA` where the note has no class breakdown,
  because then the note's figure and the balance sheet's are the same
  fact and comparing them would be a tautology reported as a check.

- `covers_fixed_assets` – do the two notes *together* account for the
  fixed assets the balance sheet carries? Per filing. A note can pass
  `covers_balance` and fail this: a filing that breaks down its tangible
  assets in full and says nothing about its intangibles is complete on
  the line it covers and silent on the rest. 1,198 filings pass and 109
  fail; the remainder have no class-broken note to judge.

- `continuous` – is the block's opening balance last year's closing
  balance? A schedule can close perfectly in every year and still break
  between them, when a company restates its cost or a filer starts the
  note over. The comparison is made on the opening row and the verdict
  is carried across the block, like the other three. Of 10,965 opening
  balances in the corpus, 7,387 had a preceding filing to compare with:
  6,875 matched and 512 did not. `NA` where the company has no preceding
  filing **in `x`** – read one year and every row is `NA`, which is the
  commonest reason for seeing no `TRUE` at all.

## The asset class

A note is tagged per class – land and buildings, plant and machinery,
fixtures and fittings – with the total column often left untagged,
because the balance sheet already carries it. `class` is the class where
the filing tagged one and `NA` for the undimensioned figure. Summing
across classes *and* the `NA` row counts everything twice.

## How much of this a filing actually has

3,521 of 4,304 filings state a note at all, and most of them state very
little of it. Counted by how many filings use each tangible-asset
element: the carrying amount 3,471, cost 1,297, accumulated depreciation
1,181, the year's charge 1,120, additions 790, disposals 406, transfers
99. Intangible assets are a fraction of that again. The carrying amount
and the charge are near-universal and the full schedule is a minority,
so the rows simply do not appear where the filing is silent.

## See also

[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
which returns this beside the statements,
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md)
for the same reconciliation run over the raw facts, and
[`find_signs()`](https://dataniel.github.io/cvrr/reference/find_signs.md)
for the sign search on its own.

Other taxonomy:
[`add_taxonomy()`](https://dataniel.github.io/cvrr/reference/add_taxonomy.md),
[`check_breakdown()`](https://dataniel.github.io/cvrr/reference/check_breakdown.md),
[`check_cascade()`](https://dataniel.github.io/cvrr/reference/check_cascade.md),
[`check_continuity()`](https://dataniel.github.io/cvrr/reference/check_continuity.md),
[`check_inclusion()`](https://dataniel.github.io/cvrr/reference/check_inclusion.md),
[`check_movement()`](https://dataniel.github.io/cvrr/reference/check_movement.md),
[`check_statement()`](https://dataniel.github.io/cvrr/reference/check_statement.md),
[`read_taxonomy()`](https://dataniel.github.io/cvrr/reference/read_taxonomy.md),
[`xbrl_accounts()`](https://dataniel.github.io/cvrr/reference/xbrl_accounts.md),
[`xbrl_company()`](https://dataniel.github.io/cvrr/reference/xbrl_company.md),
[`xbrl_fill()`](https://dataniel.github.io/cvrr/reference/xbrl_fill.md),
[`xbrl_lines()`](https://dataniel.github.io/cvrr/reference/xbrl_lines.md),
[`xbrl_note_tables()`](https://dataniel.github.io/cvrr/reference/xbrl_note_tables.md),
[`xbrl_period()`](https://dataniel.github.io/cvrr/reference/xbrl_period.md),
[`xbrl_resolve()`](https://dataniel.github.io/cvrr/reference/xbrl_resolve.md)

## Examples

``` r
if (FALSE) { # \dontrun{
x <- read_xbrl("materiale/xbrl")
m <- xbrl_movements(x)

# the note as it is printed
tidyr::pivot_wider(m, names_from = c(layer, item), values_from = value)

# what the companies invested in tangible assets, by year
a <- m[m$category == "tangible" & m$item == "additions", ]
tapply(a$value, format(a$period_end, "%Y"), sum)

# the same, on the schedules that close and nothing assumed
b <- a[a$reconciled %in% TRUE & a$sign_source == "solved", ]
} # }
```
