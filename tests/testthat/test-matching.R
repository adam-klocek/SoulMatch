testthat::test_that("Love respects reciprocal interests and firm boundaries; height stays soft", {
  f <- fixture(); a <- get_profile(f$con, f$ids$alex); b <- get_profile(f$con, f$ids$maya)
  testthat::expect_true(eligible_pair(f$con, a, b))
  a$interested <- "Male"; testthat::expect_false(eligible_pair(f$con, a, b))
  a$interested <- GENDERS; b$interested <- "Male"; testthat::expect_false(eligible_pair(f$con, a, b))
  b <- get_profile(f$con, f$ids$maya); b$height <- 160; a$preferences$height <- c(190, 200)
  testthat::expect_true(eligible_pair(f$con, a, b))
  testthat::expect_lt(preference_fit(a, b)$score, 1)
  a$preferences$hard_height <- TRUE
  testthat::expect_true(eligible_pair(f$con, a, b))
  a$preferences$age <- c(40, 50); a$preferences$hard_age <- TRUE
  testthat::expect_false(eligible_pair(f$con, a, b))
})
testthat::test_that("missing optional estimates, exploration and directional features are bounded", {
  f <- fixture(); a <- get_profile(f$con, f$ids$alex); b <- get_profile(f$con, f$ids$maya)
  b$height <- NA_real_; fit <- preference_fit(a, b)
  testthat::expect_lt(fit$coverage, 1); testthat::expect_true(is.finite(fit$score))
  for (algorithm in f$algorithms) {
    found <- discover(f$con, a, f$registry, algorithm, TRUE)
    testthat::expect_gt(length(found), 0)
    testthat::expect_true(all(vapply(found, function(r) r$score >= 0 && r$score <= 1, TRUE)))
    testthat::expect_true(found[[1]]$outside_preferences)
    for (card in found) testthat::expect_true(eligible_pair(f$con, a, card$profile))
  }
  x <- pair_features(f$con, a, b, f$registry)
  testthat::expect_identical(names(x), FEATURE_NAMES)
  testthat::expect_equal(reverse_features(reverse_features(x)), x)
})
