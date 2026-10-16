testthat::test_that("exports require both current and historical consent and exclude demos", {
  f <- fixture(); a <- f$ids$alex; b <- f$ids$maya
  id <- make_impression(f, a, b); save_decision(f$con, a, b, "like", id, f$registry)
  testthat::expect_length(export_training(f$con, f$registry), 0)
  for (who in c(a, b)) { p <- get_profile(f$con, who); p$consent <- TRUE; save_profile(f$con, who, p) }
  testthat::expect_length(export_training(f$con, f$registry), 0)
  DBI::dbExecute(f$con, "UPDATE decisions SET decision='pass' WHERE actor_id=? AND target_id=?", params = list(a, b))
  id <- make_impression(f, a, b); save_decision(f$con, a, b, "like", id, f$registry)
  testthat::expect_length(export_training(f$con, f$registry), 0)
  DBI::dbExecute(f$con, "UPDATE users SET is_demo=0 WHERE id IN (?,?)", params = list(a, b))
  records <- export_training(f$con, f$registry)
  testthat::expect_length(records, 1)
  testthat::expect_identical(records[[1]]$label, 1L)
  testthat::expect_false(any(c("actor_id", "target_id", "answers", "username") %in% names(records[[1]])))
  testthat::expect_length(records[[1]]$instruments, 4)
  p <- get_profile(f$con, a); p$consent <- FALSE; save_profile(f$con, a, p)
  testthat::expect_length(export_training(f$con, f$registry), 0)
  testthat::expect_error(train_like_model(list(), f$registry), "2,000")
})
testthat::test_that("learning fits, calibrates, evaluates, ablates, and respects model activation", {
  registry <- load_registry(); set.seed(420)
  records <- lapply(seq_len(2400), function(i) {
    x <- setNames(runif(length(FEATURE_NAMES)), FEATURE_NAMES)
    # Coverage and flags reflect realistic all-complete cohorts, including constant predictors.
    x[c("questionnaire_coverage", "own_preference_coverage", "other_preference_coverage")] <- 1
    x[c("same_city", "same_goal")] <- rbinom(2, 1, .6)
    x["is_friend_mode"] <- rbinom(1, 1, .5)
    p <- plogis(-3 + 3 * x["own_preferences"] + 2 * x["questionnaire_similarity"])
    list(pair_id = i, created_at = sprintf("2026-%05d", i), registry_signature = registry_signature(registry), features = as.list(x), instruments = list("soulmatch_big_five10@1.0.0" = x[["questionnaire_similarity"]], "soulmatch_communication@1.0.0" = x[["questionnaire_similarity"]]), label = rbinom(1, 1, p))
  })
  model <- train_like_model(records, registry)
  testthat::expect_identical(model$status, "evaluation_only")
  testthat::expect_true(model$metrics$brier < model$metrics$baseline_brier)
  testthat::expect_gt(model$metrics$auc, .65)
  testthat::expect_length(model$ablations, 2)
  path <- tempfile(fileext = ".rds"); saveRDS(model, path)
  testthat::expect_warning(testthat::expect_length(algorithm_registry(registry, path), 3), "not loaded")
  model <- train_like_model(records, registry, approve = TRUE); saveRDS(model, path)
  algorithms <- algorithm_registry(registry, path)
  testthat::expect_true(algorithms$like_glm$learned)
  p <- algorithms$like_glm$predict(unlist(records[[1]]$features))
  testthat::expect_true(p >= 0 && p <= 1)
  registry[["soulmatch_big_five10@1.0.0"]]$use_for_matching <- FALSE
  testthat::expect_warning(testthat::expect_length(algorithm_registry(registry, path), 3), "not loaded")
  records[[2]]$pair_id <- records[[1]]$pair_id
  split <- time_pair_split(records)
  testthat::expect_identical(unname(split[as.character(records[[1]]$pair_id)]), unname(split[as.character(records[[2]]$pair_id)]))
})
