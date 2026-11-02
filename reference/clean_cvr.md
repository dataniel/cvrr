# Standardise CVR numbers

Cleans a vector of Danish CVR numbers to the canonical 8-digit form:
dashes and spaces are stripped (`"12 34 56 78"` -\> `"12345678"`), and a
leading `"DK"` VAT prefix is removed (`"DK12345678"` -\> `"12345678"`).
This is the form
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md)
requires, so CVR numbers from a spreadsheet or another register go
through `clean_cvr()` first.

## Usage

``` r
clean_cvr(x)
```

## Arguments

- x:

  A character vector of CVR numbers. Numeric vectors are converted with
  [`as.character()`](https://rdrr.io/r/base/character.html) first.

## Value

A character vector of the same length.

## Details

Seven-digit values are *not* zero-padded: a lost leading zero cannot be
distinguished from a typo, and inventing a digit would let a malformed
number slip past the 8-digit check in
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md).
Values are returned cleaned but otherwise untouched, so malformed
numbers stay visibly malformed. This differs from `clean_cpr()` in the
pnrr package, which does pad CPR numbers: birth days 01-09 make that
padding unambiguous.

`clean_cvr()` started in the daos package and moved here unchanged, next
to the functions that use CVR numbers.

## See also

[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md)

Other cvr:
[`cvr_download()`](https://dataniel.github.io/cvrr/reference/cvr_download.md),
[`cvr_hits()`](https://dataniel.github.io/cvrr/reference/cvr_hits.md),
[`cvr_query()`](https://dataniel.github.io/cvrr/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/cvrr/reference/cvr_search.md)

## Examples

``` r
clean_cvr(c("DK12345678", "12 34 56 78", "12345678", NA))
#> [1] "12345678" "12345678" "12345678" NA        

# Typical use: clean, then query
# cvr_query(clean_cvr(firms$cvr), "2024-01-01", "2024-12-31")
```
