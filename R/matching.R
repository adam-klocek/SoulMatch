FEATURE_NAMES <- c("own_preferences", "other_preferences", "questionnaire_similarity", "questionnaire_coverage", "shared_interests", "same_goal", "same_city", "own_preference_coverage", "other_preference_coverage", INTEREST_FEATURES, "is_friend_mode")
numeric_fit <- function(value, range, span) {
  if (is.null(value) || is.na(value)) return(NA_real_)
  range <- as.numeric(unlist(range))
  clamp(1 - max(range[1] - value, value - range[2], 0) / span)
}
preference_fit <- function(viewer, candidate, mode = "love") {
  if (mode == "friends") return(list(score = 1, coverage = 1))
  pref <- as_preferences(viewer$preferences)
  fits <- c(age = numeric_fit(candidate$age, pref$age, 25),
    height = numeric_fit(candidate$height, pref$height, 50))
  if (length(pref$income)) fits <- c(fits, income = if (candidate$income == INCOMES[1]) NA_real_ else as.numeric(candidate$income %in% unlist(pref$income)))
  if (length(pref$styles)) fits <- c(fits, styles = as.numeric(candidate$style %in% unlist(pref$styles)))
  if (pref$smoking != "Any") fits <- c(fits, smoking = as.numeric(candidate$smoking == pref$smoking))
  if (pref$goal != "Any") fits <- c(fits, goal = as.numeric(candidate$goal == pref$goal))
  list(score = if (all(is.na(fits))) 0.5 else mean(fits, na.rm = TRUE), coverage = mean(!is.na(fits)))
}
meets_boundaries <- function(viewer, candidate) {
  p <- as_preferences(viewer$preferences)
  for (key in "age") {
    if (!isTRUE(p[[paste0("hard_", key)]])) next
    v <- candidate[[key]]; range <- as.numeric(unlist(p[[key]]))
    if (is.null(v) || is.na(v) || v < range[1] || v > range[2]) return(FALSE)
  }
  for (key in c("smoking", "goal")) if (isTRUE(p[[paste0("hard_", key)]]) && p[[key]] != "Any" && candidate[[key]] != p[[key]]) return(FALSE)
  if (isTRUE(p$hard_income) && length(p$income) && !(candidate$income %in% unlist(p$income))) return(FALSE)
  if (isTRUE(p$hard_styles) && length(p$styles) && !(candidate$style %in% unlist(p$styles))) return(FALSE)
  TRUE
}
eligible_pair <- function(con, a, b, mode = "love") {
  !is.null(a) && !is.null(b) && a$user_id != b$user_id && a$age >= 18 && b$age >= 18 &&
    mode %in% CONNECTION_MODES && mode %in% a$connection_modes && mode %in% b$connection_modes &&
    !has_block(con, a$user_id, b$user_id) && (mode == "friends" ||
      (b$gender %in% a$interested && a$gender %in% b$interested && meets_boundaries(a, b) && meets_boundaries(b, a)))
}
pair_features <- function(con, a, b, registry, exclude = character(), mode = "love") {
  ab <- preference_fit(a, b, mode); ba <- preference_fit(b, a, mode)
  qs <- questionnaire_similarity(con, a$user_id, b$user_id, registry, exclude)
  hobbies <- union(a$hobbies, b$hobbies)
  result <- c(own_preferences = ab$score, other_preferences = ba$score,
    questionnaire_similarity = qs$similarity, questionnaire_coverage = qs$coverage,
    shared_interests = if (length(hobbies)) length(intersect(a$hobbies, b$hobbies)) / length(hobbies) else 0,
    same_goal = as.numeric(a$goal == b$goal), same_city = as.numeric(tolower(a$city) == tolower(b$city)),
    own_preference_coverage = ab$coverage, other_preference_coverage = ba$coverage)
  interests <- interest_pair_features(con, a$user_id, b$user_id)
  interests[is.na(interests)] <- .5
  c(result, interests, is_friend_mode = as.numeric(mode == "friends"))[FEATURE_NAMES]
}
reverse_features <- function(x) {
  y <- x
  y[c("own_preferences", "other_preferences")] <- x[c("other_preferences", "own_preferences")]
  y[c("own_preference_coverage", "other_preference_coverage")] <- x[c("other_preference_coverage", "own_preference_coverage")]
  y[c("own_interest_satisfaction", "other_interest_satisfaction")] <- x[c("other_interest_satisfaction", "own_interest_satisfaction")]
  y
}
register_algorithm <- function(registry, id, label, version, score, description, learned = FALSE) {
  assert(is.function(score) && nzchar(id) && is.null(registry[[id]]), "Algorithm ID must be unique and score must be a function.")
  registry[[id]] <- list(id = id, label = label, version = version, score = score, description = description, learned = learned)
  registry
}
algorithm_registry <- function(questionnaires, model_path = "config/models/like_glm.rds") {
  algorithms <- list()
  algorithms <- register_algorithm(algorithms, "balanced", "Thoughtful balance", "2.0.0",
    function(x) if (x["is_friend_mode"] == 1) .35 * mean(x[c("own_interest_satisfaction", "other_interest_satisfaction")]) + .25 * x["lifestyle_compatibility"] + .2 * x["shared_activity_potential"] + .1 * x["same_city"] + .1 * x["interest_overlap"] else .4 * mean(x[c("own_preferences", "other_preferences")]) + .2 * x["questionnaire_similarity"] + .15 * mean(x[c("own_interest_satisfaction", "other_interest_satisfaction")]) + .1 * x["lifestyle_compatibility"] + .1 * x["shared_activity_potential"] + .05 * x["same_goal"],
    "Balances what matters to both of you. Friends emphasizes shared activities and lifestyle; Love also considers romantic preferences. Experimental ranking.")
  algorithms <- register_algorithm(algorithms, "reciprocal", "Mutual fit first", "2.0.0",
    function(x) if (x["is_friend_mode"] == 1) .5 * min(x[c("own_interest_satisfaction", "other_interest_satisfaction")]) + .3 * x["shared_activity_potential"] + .2 * x["lifestyle_compatibility"] else .65 * min(x[c("own_preferences", "other_preferences")]) + .15 * x["questionnaire_similarity"] + .1 * x["shared_activity_potential"] + .1 * x["same_goal"],
    "Gives more weight to the weaker of the two preference fits. Experimental heuristic.")
  if (file.exists(model_path)) {
    # Trusted administrator artifact only. Never load user-uploaded RDS files.
    model <- readRDS(model_path)
    compatible <- identical(model$feature_names, FEATURE_NAMES) && identical(model$registry_signature, registry_signature(questionnaires)) && identical(model$status, "approved_for_pilot") && length(model$supported_modes) > 0
    if (compatible) {
      prediction <- function(x) {
        mode <- if (x[["is_friend_mode"]] == 1) "friends" else "love"
        assert(mode %in% model$supported_modes, "This model is not evaluated for the selected connection mode.")
        raw <- clamp(as.numeric(stats::predict(model$fit, newdata = as.data.frame(as.list(x)), type = "response")))
        stats::plogis(model$calibration[[1]] + model$calibration[[2]] * stats::qlogis(pmax(1e-6, pmin(1 - 1e-6, raw))))
      }
      algorithms <- register_algorithm(algorithms, "like_glm", "Learned like model · pilot", model$version,
        function(x) min(prediction(x), prediction(reverse_features(x))),
        "Supervised logistic model trained on opted-in, explicit decisions. Predicts a profile like following a view; it does not predict relationships.", learned = TRUE)
      algorithms$like_glm$predict <- prediction
      algorithms$like_glm$metrics <- model$metrics
      algorithms$like_glm$supported_modes <- model$supported_modes
    } else warning("Learned model not loaded: approval, feature schema, or questionnaire registry differs.")
  }
  algorithms
}
discover <- function(con, viewer, questionnaires, algorithm, explore = FALSE, mode = "love") {
  ids <- DBI::dbGetQuery(con, "SELECT user_id FROM profiles WHERE user_id<>? AND user_id NOT IN (SELECT target_id FROM decisions WHERE actor_id=? AND mode=?)", params = list(viewer$user_id, viewer$user_id, mode))$user_id
  results <- list()
  for (id in ids) {
    candidate <- get_profile(con, id)
    if (!eligible_pair(con, viewer, candidate, mode) || !completed_required(con, id, questionnaires)) next
    x <- pair_features(con, viewer, candidate, questionnaires, mode = mode)
    score <- as.numeric(algorithm$score(x))
    assert(length(score) == 1 && is.finite(score) && score >= 0 && score <= 1, "Matching algorithm returned an invalid score.")
    results[[length(results) + 1L]] <- list(profile = candidate, features = x, score = score,
      mode = mode, outside_preferences = preference_fit(viewer, candidate, mode)$score < 1)
  }
  if (!length(results)) return(results)
  # Discovery promotes soft-preference exceptions; orientation and firm boundaries always hold.
  rank <- order(vapply(results, function(r) if (explore && r$outside_preferences) r$score + 1 else r$score, 0), decreasing = TRUE)
  results[rank]
}
log_impression <- function(con, actor, target, algorithm, registry, features, mode = "love") {
  id <- new_id(); a <- get_profile(con, actor); b <- get_profile(con, target)
  components <- questionnaire_similarity(con, actor, target, registry)$components
  DBI::dbExecute(con, "INSERT INTO impressions(id,actor_id,target_id,algorithm,algorithm_version,registry_signature,features,instrument_features,consent,created_at,mode) VALUES(?,?,?,?,?,?,?,?,?,?,?)", params = list(id, actor, target, algorithm$id, algorithm$version, registry_signature(registry), to_json(as.list(features)), to_json(components), as.integer(isTRUE(as.logical(a$consent)) && isTRUE(as.logical(b$consent))), now_utc(), mode))
  id
}
