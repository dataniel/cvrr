# Meet-in-the-middle search for sign assignments.
#
# Split the items in two halves, enumerate every assignment of each half, and
# match one half's sums against what the other half needs to reach the target.
# That turns 3^n into 2 * 3^(n/2) -- for 24 items, 531k rows per half instead
# of 282 billion.
#
# Returns an integer matrix, one row per solution, one column per item, in the
# order `c(v1, v2)`. Zero rows means no assignment reaches the target.

.meet_in_middle <- function(v1, v2, target, max_zeros, c1, c2,
                            tol = 1e-6, max_solutions = 10000L) {
  n1 <- length(v1)
  n2 <- length(v2)

  # A tolerance finer than the arithmetic can resolve is not a tolerance. Two
  # sums of the same items in a different order differ in their last bits, and
  # at a group's accounts of 1e11 kroner that is around 1e-5 -- so the default
  # `1e-6` rejected exact solutions as unsolved. Worse, the bucket keys below
  # are `sum / tol`, and past 2^53 a key and its neighbours are the same
  # double: every solution was found once per probe and a unique answer came
  # back `ambiguous` with three solutions. Measured against an exhaustive
  # search over 4,000 random cases, 184 disagreed, every one of them with
  # values over 1e8 and the default tolerance. Raising the tolerance to what
  # the magnitudes allow keeps the keys below 2^53 and removes both.
  scale <- sum(abs(v1)) + sum(abs(v2)) + abs(target)
  tol <- max(tol, 64 * .Machine$double.eps * scale)

  half <- function(v, constraints) {
    if (length(v) == 0)
      return(list(vals = matrix(integer(0), nrow = 1L), sums = 0, zeros = 0L))
    vals <- .sign_grid(length(v), constraints)
    list(vals = vals, sums = drop(vals %*% v), zeros = rowSums(vals == 0L))
  }

  h2 <- half(v2, c2)
  # Bucket the sums so the two halves can be matched by a hash join rather
  # than compared pairwise. A bucket is `tol` wide, so two sums within `tol`
  # of each other land in the same bucket or in adjacent ones -- never further
  # apart. Both neighbours are therefore probed as well, and every candidate
  # is then checked against `tol` directly. Probing only the exact bucket
  # would make `tol` a grid instead of a distance, and a filing out by exactly
  # one krone would be reported as irreconcilable.
  keys2    <- floor(h2$sums / tol)
  ord2     <- order(keys2)
  keys2_s  <- keys2[ord2]
  zeros2_s <- h2$zeros[ord2]
  sums2_s  <- h2$sums[ord2]
  vals2_s  <- h2$vals[ord2, , drop = FALSE]

  h1        <- half(v1, c1)
  need      <- target - h1$sums
  need_keys <- floor(need / tol)

  keep1 <- which(h1$zeros <= max_zeros)
  if (length(keep1) == 0)
    return(matrix(integer(0), nrow = 0L, ncol = n1 + n2))

  need_keys <- need_keys[keep1]
  need      <- need[keep1]
  zeros1    <- h1$zeros[keep1]
  vals1     <- h1$vals[keep1, , drop = FALSE]

  results <- vector("list", 64L)
  n_res   <- 0L
  truncated <- FALSE

  for (offset in c(0L, -1L, 1L)) {
    hits <- match(need_keys + offset, keys2_s)
    for (i in which(!is.na(hits))) {
      z1 <- zeros1[i]
      j  <- hits[i]
      while (j <= length(keys2_s) && keys2_s[j] == need_keys[i] + offset) {
        if (z1 + zeros2_s[j] <= max_zeros &&
            abs(need[i] - sums2_s[j]) <= tol) {
          n_res <- n_res + 1L
          if (n_res > max_solutions) { truncated <- TRUE; break }
          if (n_res > length(results)) length(results) <- length(results) * 2L
          results[[n_res]] <- c(vals1[i, ], vals2_s[j, ])
        }
        j <- j + 1L
      }
      if (truncated) break
    }
    if (truncated) break
  }

  out <- if (n_res == 0L) {
    matrix(integer(0), nrow = 0L, ncol = n1 + n2)
  } else {
    matrix(unlist(results[seq_len(min(n_res, max_solutions))]),
           ncol = n1 + n2, byrow = TRUE)
  }
  attr(out, "truncated") <- truncated
  out
}

# Every assignment of `n` items. A constraint of 1 restricts an item to
# {0, +1}, -1 to {-1, 0}, and 0 leaves it free over {-1, 0, +1}.
.sign_grid <- function(n, constraints) {
  ranges <- lapply(constraints, function(k)
    if (k == 1L) c(0L, 1L) else if (k == -1L) c(-1L, 0L) else c(-1L, 0L, 1L)
  )
  sizes <- lengths(ranges)
  total <- prod(sizes)
  mat   <- matrix(0L, nrow = total, ncol = n)
  rep_each <- 1L
  for (k in seq_len(n)) {
    r        <- ranges[[k]]
    mat[, k] <- rep(rep(r, each = rep_each), total / (rep_each * sizes[k]))
    rep_each <- rep_each * sizes[k]
  }
  mat
}

# How many rows the two halves would enumerate. Used to refuse a search that
# would exhaust memory before it refuses itself.
.sign_grid_rows <- function(constraints) {
  prod(ifelse(constraints == 0L, 3, 2))
}
