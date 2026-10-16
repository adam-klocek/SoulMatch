load_interest_catalog <- function(path = getOption("soulmatch.interest_dir", "config/interests")) {
  assert(dir.exists(path), "Interest definitions are missing.")
  list(categories = read.csv(file.path(path, "categories.csv"), stringsAsFactors = FALSE),
    interests = read.csv(file.path(path, "interests.csv"), stringsAsFactors = FALSE),
    definition = from_json(paste(readLines(file.path(path, "definition.json"), warn = FALSE), collapse = "\n")))
}
seed_interest_catalog <- function(con, catalog) {
  d <- catalog$definition
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(catalog$categories))) {
      r <- catalog$categories[i, ]; DBI::dbExecute(con, "INSERT INTO interest_categories VALUES(?,?,?) ON CONFLICT(id) DO NOTHING", params = unname(as.list(r)))
    }
    for (i in seq_len(nrow(catalog$interests))) {
      r <- catalog$interests[i, ]; DBI::dbExecute(con, "INSERT INTO interests VALUES(?,?,?,?) ON CONFLICT(id) DO NOTHING", params = unname(as.list(r)))
    }
    for (q in d$lifestyle) DBI::dbExecute(con, "INSERT INTO lifestyle_questions VALUES(?,?,?,?) ON CONFLICT(id) DO NOTHING", params = list(q$id, q$prompt, q$measurement_type, to_json(q$options)))
    DBI::dbExecute(con, "INSERT INTO questionnaire_versions VALUES(?,?,?,?) ON CONFLICT(id) DO NOTHING", params = list(d$version_id, d$id, d$version, now_utc()))
  })
}
empty_interest_state <- function() list(categories = character(), selected = character(), details = list(), lifestyle = list(), lifestyle_importance = list(), shared = list(), custom = "", step = 1L, session_id = NULL)
validate_interest_state <- function(state, catalog) {
  assert(all(state$categories %in% catalog$categories$id), "Unknown interest category.")
  assert(!anyDuplicated(state$selected) && all(state$selected %in% catalog$interests$id), "Choose interests from the catalog.")
  state$custom <- clean_text(state$custom, 300)
  assert(length(state$step) == 1 && state$step %in% 1:6, "Invalid questionnaire step.")
  for (id in state$selected) {
    r <- state$details[[id]] %||% list()
    state$details[[id]] <- list(enjoyment = optional_rating(r$enjoyment), frequency = optional_rating(r$frequency), importance = optional_rating(r$importance))
  }
  state$details <- state$details[state$selected]
  for (q in catalog$definition$lifestyle) {
    value <- state$lifestyle[[q$id]] %||% ""
    assert(length(value) == 1 && (value == "" || value %in% vapply(q$options, `[[`, "", "value")), "Unknown lifestyle response.")
    state$lifestyle[[q$id]] <- if (nzchar(value)) value else NULL
    state$lifestyle_importance[q$id] <- list(optional_rating(state$lifestyle_importance[[q$id]]))
  }
  permitted <- c(vapply(catalog$definition$shared_activities, `[[`, "", "id"), paste0("interest:", state$selected))
  assert(all(names(state$shared) %in% permitted), "Unknown shared activity.")
  state$shared <- lapply(state$shared, optional_rating, max_value = 3L)
  state
}
save_interest_state <- function(con, user_id, state, catalog, complete = FALSE) {
  assert(nrow(DBI::dbGetQuery(con, "SELECT id FROM users WHERE id=?", params = list(user_id))) == 1, "Sign in first.")
  state <- validate_interest_state(state, catalog); version_id <- catalog$definition$version_id
  # Completed snapshots are immutable. A later edit starts a new draft.
  existing <- if (!is.null(state$session_id)) DBI::dbGetQuery(con, "SELECT id,status FROM questionnaire_sessions WHERE id=? AND user_id=? AND questionnaire_version_id=?", params = list(state$session_id, user_id, version_id)) else data.frame()
  if (!nrow(existing) || existing$status[1] != "draft") state$session_id <- new_id()
  id <- state$session_id; stamp <- now_utc(); status <- if (complete) "completed" else "draft"
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "INSERT INTO questionnaire_sessions VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,step=excluded.step,navigation=excluded.navigation,updated_at=excluded.updated_at", params = list(id, user_id, version_id, status, as.integer(state$step), to_json(as.list(state$categories)), stamp, stamp))
    for (table in c("user_interests", "user_interest_partner_preferences", "lifestyle_responses", "lifestyle_partner_preferences", "shared_activity_preferences", "custom_interest_suggestions")) DBI::dbExecute(con, paste0("DELETE FROM ", table, " WHERE session_id=? AND user_id=?"), params = list(id, user_id))
    for (interest in state$selected) {
      r <- state$details[[interest]]
      DBI::dbExecute(con, "INSERT INTO user_interests VALUES(?,?,?,?,?,?,?)", params = list(id, user_id, version_id, interest, r$enjoyment, r$frequency, stamp))
      DBI::dbExecute(con, "INSERT INTO user_interest_partner_preferences VALUES(?,?,?,?,?,?)", params = list(id, user_id, version_id, interest, r$importance, stamp))
    }
    for (q in catalog$definition$lifestyle) {
      DBI::dbExecute(con, "INSERT INTO lifestyle_responses VALUES(?,?,?,?,?,?)", params = list(id, user_id, version_id, q$id, state$lifestyle[[q$id]] %||% NA_character_, stamp))
      DBI::dbExecute(con, "INSERT INTO lifestyle_partner_preferences VALUES(?,?,?,?,?,?)", params = list(id, user_id, version_id, q$id, state$lifestyle_importance[[q$id]], stamp))
    }
    for (activity in names(state$shared)) DBI::dbExecute(con, "INSERT INTO shared_activity_preferences VALUES(?,?,?,?,?,?)", params = list(id, user_id, version_id, activity, state$shared[[activity]], stamp))
    if (nzchar(state$custom)) DBI::dbExecute(con, "INSERT INTO custom_interest_suggestions VALUES(?,?,?,?)", params = list(id, user_id, state$custom, stamp))
  })
  state
}
read_interest_state <- function(con, user_id, catalog, completed_only = FALSE) {
  sql <- paste0("SELECT * FROM questionnaire_sessions WHERE user_id=? AND questionnaire_version_id=?", if (completed_only) " AND status='completed'" else "", " ORDER BY updated_at DESC,id DESC LIMIT 1")
  session <- DBI::dbGetQuery(con, sql, params = list(user_id, catalog$definition$version_id))
  if (!nrow(session)) return(empty_interest_state())
  state <- empty_interest_state(); state$session_id <- session$id[1]; state$step <- session$step[1]; state$categories <- unlist(from_json(session$navigation[1]), use.names = FALSE)
  rows <- function(table) DBI::dbGetQuery(con, paste0("SELECT * FROM ", table, " WHERE session_id=? AND user_id=?"), params = list(state$session_id, user_id))
  ints <- rows("user_interests"); prefs <- rows("user_interest_partner_preferences"); state$selected <- ints$interest_id
  for (i in seq_len(nrow(ints))) state$details[[ints$interest_id[i]]] <- list(enjoyment = ints$enjoyment[i], frequency = ints$frequency[i], importance = prefs$importance[match(ints$interest_id[i], prefs$interest_id)])
  life <- rows("lifestyle_responses"); importance <- rows("lifestyle_partner_preferences")
  for (i in seq_len(nrow(life))) {
    if (!is.na(life$option_value[i])) state$lifestyle[[life$question_id[i]]] <- life$option_value[i]
    state$lifestyle_importance[life$question_id[i]] <- list(importance$importance[match(life$question_id[i], importance$question_id)])
  }
  shared <- rows("shared_activity_preferences"); state$shared <- as.list(setNames(shared$importance, shared$activity_id))
  custom <- rows("custom_interest_suggestions"); if (nrow(custom)) state$custom <- custom$suggestion[1]
  state
}
interest_labels <- function(ids, catalog) unname(catalog$interests$label[match(ids, catalog$interests$id)])
