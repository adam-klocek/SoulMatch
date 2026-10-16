testthat::test_that("a Shiny session can discover, form a mutual connection and chat", {
  f <- fixture(); photo_dir <- tempfile()
  testthat::expect_s3_class(app_ui(TRUE, f$algorithms, f$registry), "shiny.tag.list")
  server <- function(input, output, session) {
    state <- app_server(input, output, session, f$path, photo_dir, f$registry, f$algorithms, TRUE)
    user <- state$user; candidate <- state$candidate; impression <- state$impression; con <- state$con; current_mode <- state$current_mode
    questionnaires <- f$registry; algorithms <- f$algorithms
  }
  shiny::testServer(server, {
    session$setInputs(username = "alex", password = "SoulMatchDemo!2026", login = 1)
    testthat::expect_identical(user(), f$ids$alex)
    session$setInputs(algorithm = "balanced", explore = TRUE, discovery_mode = "love", instrument = "soulmatch_big_five10@1.0.0")
    testthat::expect_true(!is.null(candidate()))
    testthat::expect_match(output$screen$html, "A little closer to", fixed = TRUE)
    testthat::expect_match(output$question_form$html, "life of the party", fixed = TRUE)
    testthat::expect_match(output$profile_editor$html, "First name", fixed = TRUE)
    testthat::expect_true(!is.null(output$candidate_card))
    p <- get_profile(con, f$ids$maya); x <- pair_features(con, get_profile(con, user()), p, questionnaires)
    candidate(list(profile = p, features = x, score = .7, outside_preferences = TRUE, mode = "love"))
    impression(log_impression(con, user(), p$user_id, algorithms$balanced, questionnaires, x))
    session$setInputs(like = 1)
    testthat::expect_true(is_mutual(con, user(), f$ids$maya, "love"))
    testthat::expect_true(!is.null(output$connection_picker))
    session$setInputs(chat_person = paste0("love:", f$ids$maya), message = "A tested hello", send = 1)
    testthat::expect_identical(read_messages(con, user(), f$ids$maya)$body, "A tested hello")
    session$setInputs(discovery_mode = "friends")
    testthat::expect_identical(current_mode(), "friends")
    testthat::expect_identical(candidate()$mode, "friends")
    session$setInputs(logout = 1); testthat::expect_null(user())
  })
})
testthat::test_that("new adults complete ten questions with persistent draft pages", {
  f <- fixture()
  server <- function(input, output, session) {
    state <- app_server(input, output, session, f$path, tempfile(), f$registry, f$algorithms, TRUE)
    user <- state$user; candidate <- state$candidate; con <- state$con
  }
  shiny::testServer(server, {
    session$setInputs(username = "new_member", password = "a-new-strong-password", adult = TRUE, register = 1)
    testthat::expect_true(!is.null(user()))
    session$setInputs(p_name = "Robin", p_age = 28, p_gender = "Nonbinary", p_interested = GENDERS, p_modes = CONNECTION_MODES,
      p_city = "Prague", p_bio = "A new person", p_income = INCOMES[1], p_style = "Casual", p_smoking = "No", p_goal = GOALS[1], p_hobbies = c("Books", "Music"), p_consent = FALSE,
      pref_age = c(22, 45), pref_height = c(140, 210), pref_smoking = "Any", pref_goal = "Any", save_profile = 1)
    testthat::expect_identical(get_profile(con, user())$name, "Robin")
    testthat::expect_null(candidate())
    session$setInputs(instrument = "soulmatch_big_five10@1.0.0", algorithm = "balanced", explore = TRUE, discovery_mode = "friends")
    q <- f$registry[["soulmatch_big_five10@1.0.0"]]
    inputs <- as.list(rep("3", 5)); names(inputs) <- paste0("answer_", q$items$id[1:5]); do.call(session$setInputs, inputs)
    session$setInputs(save_question_draft = 1)
    testthat::expect_equal(nrow(DBI::dbGetQuery(con, "SELECT 1 FROM response_drafts WHERE user_id=?", params = list(user()))), 1)
    session$setInputs(save_question_page = 1)
    draft <- DBI::dbGetQuery(con, "SELECT page FROM response_drafts WHERE user_id=?", params = list(user()))
    testthat::expect_equal(draft$page, 2)
    inputs <- as.list(rep("3", 5)); names(inputs) <- paste0("answer_", q$items$id[6:10]); do.call(session$setInputs, inputs)
    session$setInputs(save_question_page = 2)
    testthat::expect_true(completed_required(con, user(), f$registry))
    testthat::expect_equal(nrow(DBI::dbGetQuery(con, "SELECT 1 FROM response_drafts WHERE user_id=?", params = list(user()))), 0)
    testthat::expect_true(!is.null(candidate()))
    testthat::expect_identical(candidate()$mode, "friends")
    session$setInputs(delete_password = "a-new-strong-password", delete_ack = TRUE, delete_account = 1)
    testthat::expect_null(user())
    testthat::expect_equal(nrow(DBI::dbGetQuery(con, "SELECT 1 FROM users WHERE username='new_member'")), 0)
  })
})
