testthat::test_that("catalog IDs are stable and all requested categories are seeded", {
  f <- fixture(); catalog <- load_interest_catalog()
  testthat::expect_equal(nrow(catalog$categories), 16)
  testthat::expect_equal(nrow(catalog$interests), 195)
  testthat::expect_false(anyDuplicated(catalog$interests$id) > 0)
  testthat::expect_equal(length(catalog$definition$lifestyle), 7)
  testthat::expect_equal(length(catalog$definition$shared_activities), 12)
  seed_interest_catalog(f$con, catalog)
  testthat::expect_equal(nrow(DBI::dbGetQuery(f$con, "SELECT id FROM interests")), 195)
})
testthat::test_that("interest snapshots preserve missing responses and previous completed sessions", {
  f <- fixture(); catalog <- load_interest_catalog(); a <- f$ids$alex
  before <- nrow(DBI::dbGetQuery(f$con, "SELECT * FROM questionnaire_sessions WHERE user_id=? AND status='completed'", params = list(a)))
  state <- empty_interest_state(); state$selected <- "food_drinks_01"; state$categories <- "food_drinks"
  state$details <- list(food_drinks_01 = list(enjoyment = 5, frequency = 1, importance = 2)); state$step <- 3L
  draft <- save_interest_state(f$con, a, state, catalog)
  restored <- read_interest_state(f$con, a, catalog)
  testthat::expect_identical(restored$session_id, draft$session_id)
  testthat::expect_equal(restored$details$food_drinks_01$frequency, 1)
  testthat::expect_equal(restored$details$food_drinks_01$importance, 2)
  testthat::expect_equal(restored$step, 3)
  testthat::expect_true(all(is.na(DBI::dbGetQuery(f$con, "SELECT importance FROM lifestyle_partner_preferences WHERE session_id=?", params = list(draft$session_id))$importance)))
  done <- save_interest_state(f$con, a, restored, catalog, TRUE)
  edited <- done; edited$details$food_drinks_01$enjoyment <- 2
  newer <- save_interest_state(f$con, a, edited, catalog, TRUE)
  testthat::expect_false(identical(done$session_id, newer$session_id))
  testthat::expect_equal(DBI::dbGetQuery(f$con, "SELECT enjoyment FROM user_interests WHERE session_id=?", params = list(done$session_id))$enjoyment, 5)
  testthat::expect_equal(nrow(DBI::dbGetQuery(f$con, "SELECT 1 FROM questionnaire_sessions WHERE user_id=? AND status='completed'", params = list(a))), before + 2)
  forged <- done; forged$session_id <- read_interest_state(f$con, f$ids$maya, catalog)$session_id
  own <- save_interest_state(f$con, a, forged, catalog)
  testthat::expect_false(identical(own$session_id, forged$session_id))
  bad <- done; bad$selected <- "not_in_catalog"
  testthat::expect_error(save_interest_state(f$con, a, bad, catalog), "catalog")
  bad <- done; bad$details$food_drinks_01$enjoyment <- 6
  testthat::expect_error(save_interest_state(f$con, a, bad, catalog), "valid response")
})
testthat::test_that("enjoyment, sharing preference, missingness and nominal lifestyle are independent", {
  catalog <- load_interest_catalog(); a <- b <- empty_interest_state()
  a$selected <- b$selected <- "food_drinks_01"
  a$details <- list(food_drinks_01 = list(enjoyment = 1, frequency = 5, importance = 5))
  b$details <- list(food_drinks_01 = list(enjoyment = 5, frequency = 1, importance = 1))
  a$lifestyle$spending <- "spending_1"; b$lifestyle$spending <- "spending_2"
  a$lifestyle_importance$spending <- b$lifestyle_importance$spending <- 5
  x <- extract_interest_features(a, b, catalog)
  testthat::expect_equal(x[["interest_overlap"]], 1)
  testthat::expect_equal(x[["own_interest_satisfaction"]], 1)
  testthat::expect_true(is.na(x[["other_interest_satisfaction"]]))
  testthat::expect_equal(x[["frequency_alignment"]], 0)
  testthat::expect_equal(x[["lifestyle_compatibility"]], 0)
  testthat::expect_true(is.na(x[["lifestyle_complementarity"]]))
  missing <- extract_interest_features(empty_interest_state(), empty_interest_state(), catalog)
  testthat::expect_true(is.na(missing[["interest_overlap"]]))
  testthat::expect_true(is.na(missing[["shared_activity_potential"]]))
  testthat::expect_equal(missing[["lifestyle_coverage"]], 0)
})
testthat::test_that("the six-step Shiny questionnaire persists and resumes independently", {
  f <- fixture(); catalog <- load_interest_catalog()
  uid <- register_user(f$con, "interest_member", "a-new-strong-password")
  p <- get_profile(f$con, f$ids$alex); p$name <- "Robin"; save_profile(f$con, uid, p)
  who <- shiny::reactiveVal(uid)
  shiny::testServer(interestsModuleServer, args = list(con = f$con, user = who, catalog = catalog), {
    session$flushReact()
    testthat::expect_equal(step(), 1)
    session$setInputs(`categories-categories` = "food_drinks", next_step = 1)
    testthat::expect_equal(step(), 2)
    session$setInputs(`chips-chips_food_drinks` = "food_drinks_01", next_step = 2)
    testthat::expect_equal(step(), 3)
    session$setInputs(`details-enjoyment_food_drinks_01` = "5", `details-frequency_food_drinks_01` = "2", `details-importance_food_drinks_01` = "1", save_later = 1)
    saved <- read_interest_state(f$con, uid, catalog)
    testthat::expect_equal(saved$step, 3)
    testthat::expect_equal(saved$details$food_drinks_01$enjoyment, 5)
    testthat::expect_equal(saved$details$food_drinks_01$importance, 1)
  })
  shiny::testServer(interestsModuleServer, args = list(con = f$con, user = who, catalog = catalog), {
    session$flushReact()
    testthat::expect_equal(step(), 3)
    testthat::expect_identical(loaded()$selected, "food_drinks_01")
    # Mock the restored browser bindings; real browsers send these selected values automatically.
    session$setInputs(`categories-categories` = "food_drinks", `chips-chips_food_drinks` = "food_drinks_01", `details-enjoyment_food_drinks_01` = "5", `details-frequency_food_drinks_01` = "2", `details-importance_food_drinks_01` = "1", next_step = 1)
    testthat::expect_equal(step(), 4)
    session$setInputs(`lifestyle-planning` = "planning_2", `lifestyle-importance_planning` = "4", next_step = 2)
    testthat::expect_equal(step(), 5)
    session$setInputs(`shared-activities` = "shared_01", `shared-shared_shared_01` = "3", next_step = 3)
    testthat::expect_equal(step(), 6)
    session$setInputs(next_step = 4)
    saved <- read_interest_state(f$con, uid, catalog, TRUE)
    testthat::expect_identical(saved$selected, "food_drinks_01")
    testthat::expect_identical(saved$lifestyle$planning, "planning_2")
    testthat::expect_equal(saved$shared$shared_01, 3)
    # Removing every interest is a valid answer, not a fallback to old selections.
    session$setInputs(`categories-categories` = character(), `chips-chips_food_drinks` = character(), `shared-activities` = character(), save_later = 1)
    testthat::expect_length(read_interest_state(f$con, uid, catalog)$selected, 0)
  })
})
