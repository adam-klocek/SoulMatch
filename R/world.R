# A strict presentation model: no questionnaire responses, scores by item,
# income, preference values, or private profile fields leave this boundary.
connection_summaries <- function(con, viewer, registry, algorithms, catalog = load_interest_catalog()) {
  me <- get_profile(con, viewer)
  if (is.null(me)) return(list())
  rows <- DBI::dbGetQuery(con, "SELECT target_id,mode FROM decisions WHERE actor_id=? AND decision='like' ORDER BY updated_at DESC,target_id,mode", params = list(viewer))
  cards <- list()
  for (i in seq_len(nrow(rows))) {
    id <- rows$target_id[i]; mode <- rows$mode[i]; other <- get_profile(con, id)
    if (is.null(other) || has_block(con, viewer, id) || !mode %in% me$connection_modes || !mode %in% other$connection_modes) next
    mutual <- is_mutual(con, viewer, id, mode)
    if (!mutual && (!eligible_pair(con, me, other, mode) || !completed_required(con, id, registry))) next
    features <- pair_features(con, me, other, registry, mode = mode)
    interests <- interest_pair_features(con, viewer, id, catalog)
    qs <- questionnaire_similarity(con, viewer, id, registry)
    metrics <- c("Overall fit" = as.numeric(algorithms$balanced$score(features)),
      "Your preference fit" = if (mode == "love") unname(features["own_preferences"]) else NA_real_,
      "Their preference fit" = if (mode == "love") unname(features["other_preferences"]) else NA_real_,
      "Reflection similarity" = if (qs$coverage > 0) qs$similarity else NA_real_,
      "Lifestyle fit" = unname(interests["lifestyle_compatibility"]),
      "Shared interests" = unname(interests["interest_overlap"]),
      "Activity potential" = unname(interests["shared_activity_potential"]))
    # There is no meaningful overall fit without any observed input relevant to
    # this space. The algorithm's neutral imputations are not measured fit.
    if (mode == "friends" && !any(is.finite(interests[c("lifestyle_compatibility", "shared_activity_potential", "interest_overlap")]))) metrics["Overall fit"] <- NA_real_
    portrait <- if (isTRUE(as.logical(other$is_demo))) switch(other$name, Maya = "female", Leo = "male", Alex = "nonbinary", NULL) else NULL
    photo <- DBI::dbGetQuery(con, "SELECT id FROM photos WHERE user_id=? ORDER BY created_at LIMIT 1", params = list(id))
    cards[[length(cards) + 1L]] <- list(photo_key = if (nrow(photo)) photo$id[[1]] else NULL, id = id, mode = mode, status = if (mutual) "mutual" else "pending", name = other$name, age = other$age, gender = other$gender, city = other$city, portrait = portrait, metrics = metrics)
  }
  cards
}
discovery_module_definitions <- function(registry) {
  active <- active_instruments(registry)
  extras <- c("Explore the kind of closeness that feels comfortable to you.", "Reflect on how you listen, express yourself, and work through differences.", "Notice how you meet change and make room for new experiences.")
  optional_index <- 0L
  modules <- lapply(seq_along(active), function(i) {
    q <- active[[i]]
    if (!isTRUE(q$required)) optional_index <<- optional_index + 1L
    list(key = paste0("reflection_", i), kind = "reflection", instrument = names(active)[i], title = q$label,
      description = if (isTRUE(q$required)) "Ten small reflections on how you move through the world." else extras[min(optional_index, length(extras))],
      meta = paste(q$item_count, "questions", if (isTRUE(q$required)) "· Start here" else "· Optional"), icon = "questions")
  })
  c(modules, list(list(key = "interests", kind = "interests", title = "Interests & everyday life", description = "Your interests, rhythms, and the things you would love to share.", meta = "6 short steps · Optional", icon = "interests"),
    list(key = "height", kind = "height", title = "Your height story", description = "An optional reflection through everyday experiences, without a measuring tape.", meta = "11 questions · Optional", icon = "profile")))
}
module_completion <- function(con, user, module, registry, catalog) {
  if (module$kind == "reflection") {
    q <- registry[[module$instrument]]
    return(nrow(DBI::dbGetQuery(con, "SELECT 1 FROM responses WHERE user_id=? AND instrument_id=? AND version=?", params = list(user, q$id, q$version))) > 0)
  }
  if (module$kind == "interests") return(!is.null(read_interest_state(con, user, catalog, TRUE)$session_id))
  nrow(DBI::dbGetQuery(con, "SELECT 1 FROM height_responses WHERE user_id=? AND version='1.0.0'", params = list(user))) > 0
}
