# Find sign combinations that sum to a target

Given a set of labelled values and a target total, determines which
multipliers (`+1`, `-1`, or `0`) to apply to each value so that the
signed sum equals the target. Uses a *meet-in-the-middle* search, so the
cost is `2 * 3^(n/2)` rather than `3^n`.

## Usage

``` r
find_signs(
  df,
  label_col,
  value_col,
  total_label = "total",
  positive = NULL,
  negative = NULL,
  by = NULL,
  max_zeros = 2L,
  tol = 1e-06
)
```

## Arguments

- df:

  A data frame containing labels and values.

- label_col:

  Column containing item labels, unquoted or as a string.

- value_col:

  Column containing numeric values, unquoted or as a string.

- total_label:

  Label of the row whose value is the reconciliation target. Default:
  `"total"`.

- positive, negative:

  Labels constrained to a non-negative multiplier (`+1`, or `0` where
  `max_zeros` allows the item to be dropped) or a non-positive one (`-1`
  or `0`). Optional. Labels that match nothing are reported.

- by:

  Optional grouping columns: unquoted (`by = year`), several
  (`by = c(year, firm)`), or as strings. The reconciliation is performed
  separately for each group.

- max_zeros:

  Maximum number of zero coefficients allowed in a solution, i.e. how
  many items may be excluded. Default: `2L`.

- tol:

  Absolute tolerance when comparing a signed sum to the target. Default
  `1e-6`. Filings that round to whole thousands may need more.

## Value

A tibble with one row per input row, carrying the grouping columns, the
label and value columns, and four more: `sign` (the resolved multiplier,
`NA` when unresolved), `certain` (whether every candidate agreed on it),
`n_solutions` and `status`. The value column holds the signed value, or
`NA` where the sign is unresolved.

## Details

This reconciles accounting line items whose sign convention is unknown:
XBRL amounts often arrive without a meaningful sign, because the
convention varies between preparers. An income statement has to add up,
and that is enough to recover the signs.

## What "solved" means, and what it does not

Uniqueness is not proof. If the true assignment is excluded – say more
items than `max_zeros` genuinely do not belong – a coincidental one can
fit alone and be reported as certain. Read a `status` of `"unique"` as
"only one combination reaches the total", not as "this combination is
right".

Nothing is dropped. Every input row comes back, and `status` says what
happened to its group:

- `"unique"` – exactly one assignment reaches the total.

- `"ambiguous"` – several do. Items that get the *same* sign in all of
  them are still determined, so their `sign` is filled in with
  `certain = TRUE`; the rest are `NA`. This is a logical consequence,
  not a guess.

- `"unsolved"` – no assignment reaches the total within `max_zeros`.

- `"no_total"` / `"duplicate_total"` – the group has no row labelled
  `total_label`, or more than one.

Among competing assignments, those using the fewest zeros are preferred:
a solution that uses every reported line item is more plausible than one
that discards two. `status` and `n_solutions` describe the group *after*
that preference is applied.

## See also

[`read_xbrl()`](https://dataniel.github.io/cvrr/reference/read_xbrl.md).
The XBRL taxonomy publishes these weights in its calculation linkbase,
which makes this search an independent check on them rather than the
only route to a sign.

## Examples

``` r
items <- data.frame(
  label = c("revenue", "costs", "depreciation", "total"),
  value = c(100, 40, 10, 50)
)
find_signs(items, label, value, total_label = "total")
#> # A tibble: 4 × 6
#>   label        value  sign certain n_solutions status
#>   <chr>        <dbl> <int> <lgl>         <int> <chr> 
#> 1 revenue        100     1 TRUE              1 unique
#> 2 costs          -40    -1 TRUE              1 unique
#> 3 depreciation   -10    -1 TRUE              1 unique
#> 4 total           50     1 TRUE              1 unique
```
