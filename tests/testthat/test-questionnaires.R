testthat::test_that("the 10-item introduction scores two reverse-keyed items per domain", {
  f <- fixture(); q <- f$registry[["soulmatch_big_five10@1.0.0"]]
  testthat::expect_equal(q$item_count, 10)
  testthat::expect_true(all(table(q$items$domain) == 2))
  responses <- as.list(rep(1, 10)); names(responses) <- q$items$id
  testthat::expect_true(all(unlist(score_answers(q, responses)) == 3))
  testthat::expect_error(score_answers(q, responses[-1]), "Answer every")
  bad <- responses; bad[[1]] <- 3.5
  testthat::expect_error(score_answers(q, bad), "Answer every")
  save_answers(f$con, f$ids$alex, q, responses)
  q$version <- "2.0.0"; save_answers(f$con, f$ids$alex, q, responses)
  testthat::expect_equal(nrow(DBI::dbGetQuery(f$con, "SELECT 1 FROM responses WHERE user_id=? AND instrument_id=?", params = list(f$ids$alex, q$id))), 2)
  testthat::expect_gte(nrow(DBI::dbGetQuery(f$con, "SELECT 1 FROM response_history WHERE user_id=? AND instrument_id=?", params = list(f$ids$alex, q$id))), 3)
  testthat::expect_true(completed_required(f$con, f$ids$alex, f$registry))
  f$registry[["soulmatch_big_five10@1.0.0"]]$version <- "3.0.0"
  testthat::expect_false(completed_required(f$con, f$ids$alex, f$registry))
})
testthat::test_that("three optional experimental reflections can be independently retired", {
  f <- fixture(); before <- registry_signature(f$registry)
  active <- active_instruments(f$registry)
  testthat::expect_equal(length(active), 4)
  testthat::expect_equal(sum(vapply(active, function(q) !isTRUE(q$required) && q$item_count == 4, TRUE)), 3)
  f$registry[["soulmatch_big_five10@1.0.0"]]$use_for_matching <- FALSE
  sim <- questionnaire_similarity(f$con, f$ids$alex, f$ids$maya, f$registry)
  testthat::expect_length(sim$components, 3)
  testthat::expect_false(identical(before, registry_signature(f$registry)))
  testthat::expect_equal(nrow(DBI::dbGetQuery(f$con, "SELECT 1 FROM responses WHERE instrument_id='soulmatch_big_five10'")), 8)
  testthat::expect_false(f$registry[["bfi2_xs@1.0.0"]]$enabled)
  testthat::expect_false(f$registry[["ipip_bffm50@1.0.0"]]$enabled)
})
