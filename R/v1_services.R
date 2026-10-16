# Version 1 services. UI inputs never supply the authenticated actor ID.
INTENTIONS <- c("Long-term committed relationship", "Marriage-oriented relationship", "Dating with openness to long-term", "Casual dating", "Friendship first", "Still exploring")
CONTEXT_FIELDS <- list(children = c("Want children", "Do not want children", "Undecided"), existing_children = c("Yes", "No"), structure = c("Monogamy", "Consensual non-monogamy", "Exploring"), relocation = c("Open to relocating", "Prefer to stay"), alcohol = c("Never", "Occasionally", "Regularly"), pets = c("Have pets", "Want pets", "Prefer no pets"))
BEYOND_PROMPTS <- c(sunday = "A perfect Sunday for me is…", care = "Something I care deeply about is…", relationship = "A relationship works best for me when…", activity = "An activity I would love to share is…", misunderstood = "Something people misunderstand about me is…")
v1_migrate <- function(con) {
  version <- max(DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version)
  if (version >= 4) return(invisible(FALSE))
  DBI::dbWithTransaction(con, {
    for (sql in c(
      "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'member' CHECK(role IN ('member','admin'))",
      "ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended'))",
      "CREATE TABLE member_context(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,availability TEXT NOT NULL DEFAULT 'active' CHECK(availability IN ('active','open','paused')),intentions TEXT NOT NULL DEFAULT '[]',attributes TEXT NOT NULL DEFAULT '{}',preferences TEXT NOT NULL DEFAULT '{}',beyond TEXT NOT NULL DEFAULT '{}',updated_at TEXT NOT NULL)",
      "CREATE TABLE matching_algorithms(id TEXT PRIMARY KEY,version TEXT NOT NULL,label TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL)",
      "CREATE TABLE matching_experiments(id TEXT PRIMARY KEY,mode TEXT NOT NULL,algorithms TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL)",
      "CREATE TABLE matching_experiment_assignments(experiment_id TEXT NOT NULL REFERENCES matching_experiments(id),user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,algorithm TEXT NOT NULL,assigned_at TEXT NOT NULL,PRIMARY KEY(experiment_id,user_id))",
      "CREATE TABLE recommendation_batches(id TEXT PRIMARY KEY,actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,mode TEXT NOT NULL,day_key TEXT NOT NULL,algorithm TEXT NOT NULL,algorithm_version TEXT NOT NULL,experiment_id TEXT,created_at TEXT NOT NULL)",
      "CREATE TABLE candidate_eligibility_snapshots(batch_id TEXT NOT NULL REFERENCES recommendation_batches(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,eligible INTEGER NOT NULL,PRIMARY KEY(batch_id,target_id))",
      "CREATE TABLE daily_connections(id TEXT PRIMARY KEY,batch_id TEXT NOT NULL REFERENCES recommendation_batches(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,position INTEGER NOT NULL,ranking_score REAL NOT NULL,features TEXT NOT NULL,explanations TEXT NOT NULL,selection_probability REAL NOT NULL,shown_at TEXT,impression_id TEXT,UNIQUE(batch_id,target_id))",
      "CREATE TABLE saved_connections(actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,mode TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(actor_id,target_id,mode))",
      "CREATE TABLE user_interest_events(id TEXT PRIMARY KEY,actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,mode TEXT NOT NULL,decision TEXT NOT NULL,impression_id TEXT,created_at TEXT NOT NULL)",
      "CREATE TABLE meeting_confirmations(actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,mode TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(actor_id,target_id,mode))",
      "CREATE TABLE post_date_feedback(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,mode TEXT NOT NULL,comfort INTEGER,attraction INTEGER,naturalness INTEGER,second_date TEXT,profile_accuracy INTEGER,relationship_formed TEXT,satisfaction INTEGER,research_consent INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL,UNIQUE(user_id,target_id,mode))",
      "CREATE TABLE private_safety_feedback(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,mode TEXT NOT NULL,safe_respected TEXT NOT NULL,created_at TEXT NOT NULL,UNIQUE(user_id,target_id,mode))",
      "CREATE TABLE administrator_audit(id TEXT PRIMARY KEY,actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,action TEXT NOT NULL,target_id TEXT REFERENCES users(id) ON DELETE SET NULL,details TEXT NOT NULL,created_at TEXT NOT NULL)",
      "CREATE TABLE moderation_events(id TEXT PRIMARY KEY,actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,target_id TEXT REFERENCES users(id) ON DELETE SET NULL,status TEXT NOT NULL,reason TEXT NOT NULL,created_at TEXT NOT NULL)",
      "CREATE TABLE model_evaluation_results(id TEXT PRIMARY KEY,model_version TEXT NOT NULL,registry_signature TEXT NOT NULL,result TEXT NOT NULL,created_at TEXT NOT NULL)",
      "CREATE TABLE rate_limit_events(subject TEXT NOT NULL,action TEXT NOT NULL,created_at TEXT NOT NULL)",
      "CREATE INDEX recommendation_actor_day ON recommendation_batches(actor_id,mode,day_key)",
      "CREATE INDEX daily_target_shown ON daily_connections(target_id,shown_at)",
      "CREATE INDEX interest_event_time ON user_interest_events(created_at,mode)",
      "CREATE INDEX rate_limit_subject ON rate_limit_events(subject,action,created_at)",
      "INSERT INTO schema_version VALUES(4)")) DBI::dbExecute(con, sql)
  })
  invisible(TRUE)
}
member_context <- function(con, id) {
  row <- DBI::dbGetQuery(con, "SELECT * FROM member_context WHERE user_id=?", params = list(id))
  if (!nrow(row)) return(list(availability = "active", intentions = character(), attributes = list(), preferences = list(), beyond = list()))
  x <- as.list(row[1,]); for (key in c("intentions", "attributes", "preferences", "beyond")) x[[key]] <- from_json(x[[key]])
  x$intentions <- unlist(x$intentions, use.names = FALSE); x
}
save_member_context <- function(con, id, context) {
  assert(!is.null(get_profile(con, id)), "Save your introduction first.")
  x <- context; assert(x$availability %in% c("active", "open", "paused"), "Choose your availability.")
  x$intentions <- unique(x$intentions %||% character()); assert(all(x$intentions %in% INTENTIONS), "Unknown intention.")
  x$attributes <- x$attributes %||% list(); x$preferences <- x$preferences %||% list(); x$beyond <- x$beyond %||% list()
  allowed <- c(names(CONTEXT_FIELDS), "faith", "culture", "region")
  assert(all(names(x$attributes) %in% allowed) && all(names(x$preferences) %in% c(names(CONTEXT_FIELDS), "faith", "culture", "region", "intentions")), "Unknown context field.")
  for (key in names(x$attributes)) {
    v <- clean_text(x$attributes[[key]], 100); if (key %in% names(CONTEXT_FIELDS)) assert(v == "" || v %in% CONTEXT_FIELDS[[key]], "Unknown context answer.")
    x$attributes[[key]] <- v
  }
  for (key in names(x$preferences)) {
    p <- x$preferences[[key]]; assert(p$importance %in% c("essential", "strong", "nice"), "Choose preference importance.")
    p$values <- unique(as.character(unlist(p$values))); values <- if (key == "intentions") INTENTIONS else CONTEXT_FIELDS[[key]]
    if (!is.null(values)) assert(all(p$values %in% values), "Unknown preference.") else { assert(length(p$values) <= 1, "Use a single optional context preference."); p$values <- vapply(p$values, clean_text, "", max_n = 100) }
    x$preferences[[key]] <- p
  }
  assert(all(names(x$beyond) %in% names(BEYOND_PROMPTS)), "Unknown profile prompt.")
  x$beyond <- lapply(x$beyond, clean_text, max_n = 300)
  DBI::dbExecute(con, "INSERT INTO member_context VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET availability=excluded.availability,intentions=excluded.intentions,attributes=excluded.attributes,preferences=excluded.preferences,beyond=excluded.beyond,updated_at=excluded.updated_at", params = list(id, x$availability, to_json(as.list(x$intentions)), to_json(x$attributes), to_json(x$preferences), to_json(x$beyond), now_utc()))
  invisible(x)
}
user_active <- function(con, id) {
  row <- DBI::dbGetQuery(con, "SELECT status FROM users WHERE id=?", params = list(id))
  nrow(row) == 1 && row$status[[1]] == "active"
}
context_fit <- function(a, b, essential_only = FALSE) {
  values <- weights <- numeric()
  for (key in names(a$preferences)) {
    p <- a$preferences[[key]]; wanted <- unlist(p$values)
    if (!length(wanted) || (essential_only && p$importance != "essential")) next
    actual <- if (key == "intentions") b$intentions else b$attributes[[key]]
    known <- length(actual) > 0 && any(nzchar(actual))
    fits <- known && length(intersect(tolower(wanted), tolower(actual))) > 0
    if (essential_only && !fits) return(FALSE)
    if (!known) next
    values <- c(values, as.numeric(fits)); weights <- c(weights, switch(p$importance, essential = 3, strong = 2, nice = 1))
  }
  if (essential_only) TRUE else weighted_available(values, weights)
}
v1_pair_allowed <- function(con, a, b, mode) {
  if (!user_active(con, a$user_id) || !user_active(con, b$user_id)) return(FALSE)
  x <- member_context(con, a$user_id); y <- member_context(con, b$user_id)
  x$availability != "paused" && y$availability != "paused" && (mode == "friends" || (context_fit(x, y, TRUE) && context_fit(y, x, TRUE)))
}
audit_event <- function(con, actor, action, target = NULL, details = list()) DBI::dbExecute(con, "INSERT INTO administrator_audit VALUES(?,?,?,?,?,?)", params = list(new_id(), actor, action, target %||% NA_character_, to_json(details), now_utc()))
require_admin <- function(con, id) {
  row <- DBI::dbGetQuery(con, "SELECT role,status FROM users WHERE id=?", params = list(id))
  assert(nrow(row) == 1 && row$role[[1]] == "admin" && row$status[[1]] == "active", "Administrator access required.")
  invisible(TRUE)
}
is_admin <- function(con, id) isTRUE(tryCatch({ require_admin(con, id); TRUE }, error = function(e) FALSE))
rate_limit <- function(con, subject, action, limit = 30L, seconds = 60L) {
  cutoff <- format(Sys.time() - seconds, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
  n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM rate_limit_events WHERE subject=? AND action=? AND created_at>?", params = list(subject, action, cutoff))$n[[1]]
  assert(n < limit, "Please slow down and try again shortly.")
  expiry <- format(Sys.time()-86400,"%Y-%m-%dT%H:%M:%OS6Z",tz="UTC")
  DBI::dbExecute(con,"DELETE FROM rate_limit_events WHERE created_at<?",params=list(expiry))
  DBI::dbExecute(con, "INSERT INTO rate_limit_events VALUES(?,?,?)", params = list(subject, action, now_utc()))
}
matching_config <- function(path = getOption("soulmatch.matching_file", "config/matching.json")) {
  x <- from_json(paste(readLines(path, warn = FALSE), collapse = "\n"))
  assert(x$daily_count %in% 1:20 && x$exploration >= 0 && x$exploration <= .5 && x$exposure_bonus >= 0 && x$exposure_bonus <= .2, "Invalid recommendation configuration.")
  x
}
match_explanations <- function(con, a, b, mode) {
  common <- intersect(a$hobbies, b$hobbies); x <- interest_pair_features(con, a$user_id, b$user_id)
  reasons <- character()
  if (length(common)) reasons <- c(reasons, "You have shared interests worth exploring.")
  if (is.finite(x[["lifestyle_compatibility"]]) && x[["lifestyle_compatibility"]] >= .65) reasons <- c(reasons, "Your everyday rhythms have common ground.")
  if (is.finite(x[["shared_activity_potential"]]) && x[["shared_activity_potential"]] > .5) reasons <- c(reasons, "There are activities you could enjoy together.")
  if (mode == "love" && a$goal == b$goal) reasons <- c(reasons, "Your relationship intentions have common ground.")
  head(unique(c(reasons, "You meet each other's essential requirements in this space.")), 3)
}
reciprocal_interest_service <- function(algorithm, features) {
  if (!isTRUE(algorithm$learned) || !is.function(algorithm$predict)) return(list(status = "not_estimated", forward = NA_real_, reverse = NA_real_, rank = NA_real_, uncertainty = NULL))
  ab <- as.numeric(algorithm$predict(features)); ba <- as.numeric(algorithm$predict(reverse_features(features)))
  assert(all(is.finite(c(ab, ba))) && all(c(ab,ba) >= 0 & c(ab,ba) <= 1), "Invalid directional predictions.")
  list(status = "experimental_internal", forward = ab, reverse = ba, rank = min(ab,ba), uncertainty = NULL)
}
registered_algorithms <- function(con, algorithms) {
  for (a in algorithms) DBI::dbExecute(con, "INSERT INTO matching_algorithms VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET version=excluded.version,label=excluded.label", params = list(a$id, a$version, a$label, 1L, now_utc()))
  algorithms
}
experiment_algorithm <- function(con, actor, mode, algorithms, fallback) {
  rows <- DBI::dbGetQuery(con, "SELECT * FROM matching_experiments WHERE enabled=1 AND mode=? ORDER BY created_at LIMIT 1", params = list(mode))
  if (!nrow(rows)) return(list(algorithm = fallback, experiment = NULL))
  ex <- rows[1,]; spec <- from_json(ex$algorithms); keys <- intersect(names(spec),names(algorithms))
  assert(length(keys)>=2 && all(vapply(keys,function(k)identical(spec[[k]],algorithms[[k]]$version),TRUE)),"Experiment versions changed; close it and create a new experiment ID.")
  assignment <- DBI::dbGetQuery(con, "SELECT algorithm FROM matching_experiment_assignments WHERE experiment_id=? AND user_id=?", params = list(ex$id, actor))
  if (!nrow(assignment)) { key <- sample(keys, 1); DBI::dbExecute(con, "INSERT INTO matching_experiment_assignments VALUES(?,?,?,?)", params = list(ex$id, actor, key, now_utc())) } else key <- assignment$algorithm[[1]]
  if (!key %in% names(algorithms)) return(list(algorithm = fallback, experiment = NULL))
  list(algorithm = algorithms[[key]], experiment = ex$id)
}
new_daily_batch <- function(con, actor, registry, algorithm, explore = TRUE, mode = "love", config = matching_config(), experiment = NULL) {
  me <- get_profile(con, actor); assert(!is.null(me) && completed_required(con, actor, registry), "Complete your introduction first.")
  enabled <- DBI::dbGetQuery(con,"SELECT enabled FROM matching_algorithms WHERE id=?",params=list(algorithm$id))
  assert(!nrow(enabled) || enabled$enabled[[1]]==1,"This algorithm is disabled.")
  if(isTRUE(algorithm$learned))assert(mode %in% algorithm$supported_modes,"This model is not evaluated for this space.")
  batch <- new_id(); day <- format(Sys.time(), "%Y-%m-%d", tz = "Europe/Prague")
  pool <- discover(con, me, registry, algorithm, FALSE, mode)
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "INSERT INTO recommendation_batches VALUES(?,?,?,?,?,?,?,?)", params = list(batch, actor, mode, day, algorithm$id, algorithm$version, experiment %||% NA_character_, now_utc()))
    for (r in pool) DBI::dbExecute(con, "INSERT INTO candidate_eligibility_snapshots VALUES(?,?,1)", params = list(batch, r$profile$user_id))
    # Do not repeat a person in the same day's curated batches, even after Save.
    seen <- DBI::dbGetQuery(con, "SELECT d.target_id FROM daily_connections d JOIN recommendation_batches b ON b.id=d.batch_id WHERE b.actor_id=? AND b.mode=? AND b.day_key=?", params = list(actor, mode, day))$target_id
    pool <- Filter(function(r) !r$profile$user_id %in% seen, pool)
    for (position in seq_len(min(length(pool), as.integer(config$daily_count)))) {
      count <- vapply(pool, function(r) DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM daily_connections WHERE target_id=? AND shown_at IS NOT NULL", params = list(r$profile$user_id))$n[[1]], 0)
      adjusted <- vapply(pool, `[[`, 0, "score") + config$exposure_bonus / sqrt(1 + count)
      best <- which.max(adjusted); epsilon <- if (explore) config$exploration else 0
      probabilities <- rep(epsilon / length(pool), length(pool)); probabilities[best] <- probabilities[best] + 1 - epsilon
      index <- sample(seq_along(pool), 1, prob = probabilities); r <- pool[[index]]
      DBI::dbExecute(con, "INSERT INTO daily_connections VALUES(?,?,?,?,?,?,?,?,?,?)", params = list(new_id(), batch, r$profile$user_id, position, r$score, to_json(as.list(r$features)), to_json(as.list(match_explanations(con, me, r$profile, mode))), probabilities[index], NA_character_, NA_character_))
      pool <- pool[-index]
    }
  })
  batch
}
daily_connection <- function(con, actor, registry, algorithms, algorithm, mode, explore = TRUE, more = FALSE, record_view = TRUE) {
  day <- format(Sys.time(), "%Y-%m-%d", tz = "Europe/Prague")
  batches <- DBI::dbGetQuery(con, "SELECT id FROM recommendation_batches WHERE actor_id=? AND mode=? AND day_key=? ORDER BY created_at", params = list(actor, mode, day))
  if (!nrow(batches) || more) {
    selected <- experiment_algorithm(con, actor, mode, algorithms, algorithm)
    new_daily_batch(con, actor, registry, selected$algorithm, explore, mode, experiment = selected$experiment)
  }
  rows <- DBI::dbGetQuery(con, "SELECT d.*,b.mode,b.algorithm,b.algorithm_version FROM daily_connections d JOIN recommendation_batches b ON b.id=d.batch_id WHERE b.actor_id=? AND b.mode=? AND b.day_key=? AND NOT EXISTS(SELECT 1 FROM decisions q WHERE q.actor_id=b.actor_id AND q.target_id=d.target_id AND q.mode=b.mode) AND NOT EXISTS(SELECT 1 FROM saved_connections s WHERE s.actor_id=b.actor_id AND s.target_id=d.target_id AND s.mode=b.mode) ORDER BY b.created_at,d.position", params = list(actor, mode, day))
  for (i in seq_len(nrow(rows))) {
    r <- rows[i,]; p <- get_profile(con, r$target_id); me <- get_profile(con, actor)
    if (!eligible_pair(con, me, p, mode) || !completed_required(con, p$user_id, registry)) next
    a <- algorithms[[r$algorithm]]; if (is.null(a) || !identical(a$version, r$algorithm_version)) next
    enabled <- DBI::dbGetQuery(con, "SELECT enabled FROM matching_algorithms WHERE id=?", params = list(a$id))
    if (nrow(enabled) && enabled$enabled[[1]] != 1) next
    if (is.na(r$impression_id) && record_view) {
      imp <- log_impression(con, actor, p$user_id, a, registry, pair_features(con,me,p,registry,mode=mode), mode)
      DBI::dbExecute(con, "UPDATE daily_connections SET shown_at=?,impression_id=? WHERE id=?", params = list(now_utc(), imp, r$id))
    } else imp <- if(is.na(r$impression_id)) NULL else r$impression_id
    # Recompute with current consent/preferences rather than using stale private inputs.
    x <- pair_features(con, me, p, registry, mode = mode)
    return(list(profile = p, features = x, score = as.numeric(a$score(x)), mode = mode, outside_preferences = preference_fit(me,p,mode)$score < 1, daily_id = r$id, impression_id = imp, explanations = match_explanations(con,me,p,mode), algorithm_id = a$id))
  }
  NULL
}
save_for_later <- function(con, actor, target, mode) {
  assert(eligible_pair(con, get_profile(con,actor), get_profile(con,target),mode), "This profile is unavailable.")
  DBI::dbExecute(con, "INSERT INTO saved_connections VALUES(?,?,?,?) ON CONFLICT(actor_id,target_id,mode) DO NOTHING", params = list(actor,target,mode,now_utc()))
}
unmatch <- function(con, actor, target, mode) {
  assert(is_mutual(con,actor,target,mode), "Choose an active mutual connection.")
  DBI::dbExecute(con, "UPDATE decisions SET decision='pass',updated_at=? WHERE actor_id=? AND target_id=? AND mode=?", params = list(now_utc(),actor,target,mode))
}
conversation_starter <- function(con, a, b) {
  x <- get_profile(con,a); y <- get_profile(con,b); shared <- intersect(x$hobbies,y$hobbies)
  if (length(shared)) paste0("You both enjoy ", tolower(shared[[1]]), ". What is a recent experience you would recommend?") else "What is one small thing you have been looking forward to lately?"
}
confirm_meeting <- function(con, actor, target, mode) {
  assert(is_mutual(con,actor,target,mode), "Choose an active mutual connection.")
  DBI::dbExecute(con, "INSERT INTO meeting_confirmations VALUES(?,?,?,?) ON CONFLICT(actor_id,target_id,mode) DO NOTHING", params = list(actor,target,mode,now_utc()))
}
both_met <- function(con,a,b,mode) DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM meeting_confirmations WHERE mode=? AND ((actor_id=? AND target_id=?) OR (actor_id=? AND target_id=?))", params = list(mode,a,b,b,a))$n[[1]] == 2
save_post_date <- function(con, actor, target, mode, feedback) {
  assert(is_mutual(con,actor,target,mode) && both_met(con,actor,target,mode), "Both people must confirm meeting before this optional feedback opens.")
  f <- feedback
  for (key in c("comfort","attraction","naturalness","profile_accuracy","satisfaction")) f[[key]] <- optional_rating(f[[key]])
  for (key in c("second_date","relationship_formed","safe_respected")) assert((f[[key]] %||% "") %in% c("","yes","no","unsure"), "Choose a valid feedback option.")
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "INSERT INTO post_date_feedback VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id,target_id,mode) DO UPDATE SET comfort=excluded.comfort,attraction=excluded.attraction,naturalness=excluded.naturalness,second_date=excluded.second_date,profile_accuracy=excluded.profile_accuracy,relationship_formed=excluded.relationship_formed,satisfaction=excluded.satisfaction,research_consent=excluded.research_consent,created_at=excluded.created_at", params = list(new_id(),actor,target,mode,f$comfort,f$attraction,f$naturalness,f$second_date %||% "",f$profile_accuracy,f$relationship_formed %||% "",f$satisfaction,as.integer(isTRUE(f$research_consent)),now_utc()))
    if (nzchar(f$safe_respected %||% "")) DBI::dbExecute(con, "INSERT INTO private_safety_feedback VALUES(?,?,?,?,?,?) ON CONFLICT(user_id,target_id,mode) DO UPDATE SET safe_respected=excluded.safe_respected,created_at=excluded.created_at", params = list(new_id(),actor,target,mode,f$safe_respected,now_utc()))
  })
}
dating_insights <- function(con, actor, registry, mode = "love") {
  a <- get_profile(con,actor); assert(!is.null(a), "Save your profile first.")
  ids <- DBI::dbGetQuery(con, "SELECT user_id FROM profiles WHERE user_id<>?", params = list(actor))$user_id
  base <- Filter(function(b) user_active(con,b$user_id) && mode %in% b$connection_modes && !has_block(con,actor,b$user_id) && completed_required(con,b$user_id,registry) && member_context(con,b$user_id)$availability != "paused", lapply(ids,function(id)get_profile(con,id)))
  eligible <- Filter(function(b) eligible_pair(con,a,b,mode),base)
  preferred <- Filter(function(b) preference_fit(a,b,mode)$score >= .8,eligible)
  # Return only pool counts: never the identity or private values of excluded people.
  list(active_pool = length(base), eligible_pool = length(eligible), close_to_soft = length(preferred), outside_soft = length(eligible)-length(preferred), mode = mode)
}
admin_set_algorithm <- function(con, actor, key, enabled) {
  require_admin(con,actor); n <- DBI::dbGetQuery(con, "SELECT id FROM matching_algorithms WHERE id=?", params = list(key)); assert(nrow(n)==1,"Unknown algorithm.")
  if (!enabled) assert(DBI::dbGetQuery(con,"SELECT COUNT(*) AS n FROM matching_algorithms WHERE enabled=1")$n[[1]] > 1,"Keep at least one algorithm enabled.")
  DBI::dbExecute(con,"UPDATE matching_algorithms SET enabled=?,updated_at=? WHERE id=?",params=list(as.integer(enabled),now_utc(),key)); audit_event(con,actor,"algorithm_status",details=list(id=key,enabled=enabled))
}
admin_moderate <- function(con, actor, target, status, reason) {
  require_admin(con,actor); assert(status %in% c("active","suspended") && target != actor,"Choose another account and valid status.")
  reason <- clean_text(reason,500); assert(nzchar(reason),"Record a reason.")
  assert(nrow(DBI::dbGetQuery(con,"SELECT id FROM users WHERE id=?",params=list(target)))==1,"Unknown account.")
  DBI::dbExecute(con,"UPDATE users SET status=? WHERE id=?",params=list(status,target))
  DBI::dbExecute(con,"INSERT INTO moderation_events VALUES(?,?,?,?,?,?)",params=list(new_id(),actor,target,status,reason,now_utc())); audit_event(con,actor,"moderation",target,list(status=status))
}
export_own_data <- function(con, actor) {
  assert(!is.null(get_profile(con,actor)),"Save your profile first.")
  result <- list(exported_at=now_utc(),profile=get_profile(con,actor),context=member_context(con,actor))
  for (table in c("responses","response_history","response_drafts","height_responses","questionnaire_sessions","user_interests","user_interest_partner_preferences","lifestyle_responses","lifestyle_partner_preferences","shared_activity_preferences","post_date_feedback","private_safety_feedback")) result[[table]] <- DBI::dbGetQuery(con,paste0("SELECT * FROM ",table," WHERE user_id=?"),params=list(actor))
  result$messages <- DBI::dbGetQuery(con,"SELECT * FROM messages WHERE sender_id=? OR receiver_id=?",params=list(actor,actor))
  result$decisions <- DBI::dbGetQuery(con,"SELECT * FROM decisions WHERE actor_id=?",params=list(actor))
  result$profile$is_demo <- NULL; result
}
admin_research_summary <- function(con, actor, registry, days = 30L) {
  require_admin(con,actor); assert(days %in% c(7L,30L,90L),"Choose a reporting window.")
  cutoff <- format(Sys.time()-days*86400,"%Y-%m-%dT%H:%M:%OS6Z",tz="UTC")
  # Live research excludes all fictional/demo accounts. Counts disclose no item answers.
  batches <- DBI::dbGetQuery(con,"SELECT b.* FROM recommendation_batches b JOIN users u ON u.id=b.actor_id WHERE u.is_demo=0 AND b.created_at>=?",params=list(cutoff))
  exposure <- DBI::dbGetQuery(con,"SELECT d.target_id,COUNT(*) AS served FROM daily_connections d JOIN recommendation_batches b ON b.id=d.batch_id JOIN users a ON a.id=b.actor_id JOIN users z ON z.id=d.target_id WHERE a.is_demo=0 AND z.is_demo=0 AND d.shown_at>=? GROUP BY d.target_id",params=list(cutoff))
  opportunities <- DBI::dbGetQuery(con,"SELECT e.target_id,COUNT(*) AS eligible FROM candidate_eligibility_snapshots e JOIN recommendation_batches b ON b.id=e.batch_id JOIN users a ON a.id=b.actor_id JOIN users z ON z.id=e.target_id WHERE a.is_demo=0 AND z.is_demo=0 AND b.created_at>=? AND e.eligible=1 GROUP BY e.target_id",params=list(cutoff))
  attention <- merge(opportunities,exposure,by="target_id",all.x=TRUE); if(nrow(attention)){attention$served[is.na(attention$served)]<-0;attention$served_per_opportunity<-attention$served/pmax(1,attention$eligible);attention$profile<-substr(attention$target_id,1,8);attention$target_id<-NULL}
  decisions <- DBI::dbGetQuery(con,"SELECT e.decision,COUNT(*) AS n FROM user_interest_events e JOIN users a ON a.id=e.actor_id JOIN users b ON b.id=e.target_id WHERE a.is_demo=0 AND b.is_demo=0 AND e.created_at>=? GROUP BY e.decision",params=list(cutoff))
  mutual_rows<-DBI::dbGetQuery(con,"SELECT a.actor_id,a.target_id,a.mode FROM decisions a JOIN decisions b ON b.actor_id=a.target_id AND b.target_id=a.actor_id AND b.mode=a.mode JOIN users u ON u.id=a.actor_id JOIN users v ON v.id=a.target_id WHERE a.decision='like' AND b.decision='like' AND a.actor_id<a.target_id AND u.is_demo=0 AND v.is_demo=0 AND (a.updated_at>=? OR b.updated_at>=?)",params=list(cutoff,cutoff))
  active_mutual<-sum(vapply(seq_len(nrow(mutual_rows)),function(i)is_mutual(con,mutual_rows$actor_id[i],mutual_rows$target_id[i],mutual_rows$mode[i]),TRUE))
  messages <- DBI::dbGetQuery(con,"SELECT m.sender_id,m.receiver_id,m.mode FROM messages m JOIN users a ON a.id=m.sender_id JOIN users b ON b.id=m.receiver_id WHERE a.is_demo=0 AND b.is_demo=0 AND m.created_at>=?",params=list(cutoff))
  pairs <- if(nrow(messages)) split(seq_len(nrow(messages)),vapply(seq_len(nrow(messages)),function(i)paste(c(sort(c(messages$sender_id[i],messages$receiver_id[i])),messages$mode[i]),collapse=":"),"")) else list()
  mutual_participation <- sum(vapply(pairs,function(i)length(unique(messages$sender_id[i]))==2,TRUE))
  outcomes <- DBI::dbGetQuery(con,"SELECT f.* FROM post_date_feedback f JOIN users a ON a.id=f.user_id JOIN users b ON b.id=f.target_id JOIN profiles p ON p.user_id=f.user_id JOIN profiles q ON q.user_id=f.target_id WHERE a.is_demo=0 AND b.is_demo=0 AND p.consent=1 AND q.consent=1 AND f.research_consent=1 AND f.created_at>=?",params=list(cutoff))
  outcome_pairs <- if(nrow(outcomes)) split(seq_len(nrow(outcomes)),vapply(seq_len(nrow(outcomes)),function(i)paste(c(sort(c(outcomes$user_id[i],outcomes$target_id[i])),outcomes$mode[i]),collapse=":"),"")) else list()
  complete_pairs <- Filter(function(i)length(unique(outcomes$user_id[i]))==2,outcome_pairs)
  second <- sum(vapply(complete_pairs,function(i)all(outcomes$second_date[i]=="yes"),TRUE))
  metrics <- data.frame(Measure=c("Eligible recommendation opportunities","Served introductions","Explicit decisions","Interested decisions","Active mutual connections updated in window","Conversations with a message","Conversations with both participating","Pairs with two consented feedback forms","Mutual second-date interest"),Count=c(sum(opportunities$eligible),sum(exposure$served),sum(decisions$n),sum(decisions$n[decisions$decision=="like"]),active_mutual,length(pairs),mutual_participation,length(complete_pairs),second),Denominator=c("Eligible target × batch, before daily exclusions","Actual rendered introductions; not verified attention","Recorded decisions in the window","Explicit decisions in the window","Current active unordered pair + mode; either decision updated in window, not historical match total","Unique unordered pair + mode in the window","Conversations with at least one message in the window","Two independently opted-in forms in the window","Pairs with two consented forms in the window"))
  psych <- do.call(rbind,lapply(registry,function(q){
    if(!isTRUE(q$enabled))return(data.frame(Instrument=q$label,Version=q$version,Status="Inactive",Consented_n=0,Items=q$item_count,Alpha="Not evaluated"))
    r<-DBI::dbGetQuery(con,"SELECT r.answers FROM responses r JOIN users u ON u.id=r.user_id JOIN profiles p ON p.user_id=r.user_id WHERE r.instrument_id=? AND r.version=? AND u.is_demo=0 AND p.consent=1",params=list(q$id,q$version))
    # Whole-scale alpha is inappropriate for a deliberately multidimensional tool;
    # calculate each subscale only when at least 30 independent members completed it.
    alpha <- "Insufficient data (need 30)"
    if(nrow(r)>=30){
      matrix<-do.call(rbind,lapply(r$answers,function(z)as.numeric(unlist(from_json(z)[q$items$id]))))
      rev<-q$items$reverse==1;matrix[,rev]<-q$scale_max+q$scale_min-matrix[,rev]
      domains<-unique(q$items$domain)
      alpha<-paste(vapply(domains,function(d){m<-matrix[,q$items$domain==d,drop=FALSE];k<-ncol(m);v<-stats::var(rowSums(m));a<-if(k>1&&is.finite(v)&&v>0)k/(k-1)*(1-sum(apply(m,2,stats::var))/v) else NA_real_;paste(d,if(is.finite(a))sprintf("%.2f",a) else "unavailable")},""),collapse="; ")
    }
    data.frame(Instrument=q$label,Version=q$version,Status=if(isTRUE(q$use_for_matching))"Active in matching" else "Reflection only",Consented_n=nrow(r),Items=q$item_count,Alpha=alpha)
  }))
  audit_event(con,actor,"research_dashboard",details=list(days=days))
  list(metrics=metrics,exposure=attention,psychometrics=psych,cutoff=cutoff)
}
export_relationship_training <- function(con, registry) {
  # Features precede the meeting. Neither feedback nor private message contents
  # can enter predictors. Consent is checked at impression, feedback and export.
  f<-DBI::dbGetQuery(con,"SELECT f.* FROM post_date_feedback f JOIN users a ON a.id=f.user_id JOIN users b ON b.id=f.target_id JOIN profiles p ON p.user_id=f.user_id JOIN profiles q ON q.user_id=f.target_id WHERE a.is_demo=0 AND b.is_demo=0 AND p.consent=1 AND q.consent=1 AND f.research_consent=1 ORDER BY f.created_at")
  records<-list();keys<-character()
  for(i in seq_len(nrow(f))){
    a<-f$user_id[i];b<-f$target_id[i];mode<-f$mode[i];key<-paste(c(sort(c(a,b)),mode),collapse=":")
    if(key %in% keys)next
    reverse<-which(f$user_id==b & f$target_id==a & f$mode==mode)
    if(length(reverse)!=1||!f$second_date[i]%in%c("yes","no")||!f$second_date[reverse]%in%c("yes","no"))next
    met<-DBI::dbGetQuery(con,"SELECT MIN(created_at) AS t FROM meeting_confirmations WHERE mode=? AND ((actor_id=? AND target_id=?) OR (actor_id=? AND target_id=?))",params=list(mode,a,b,b,a))$t[[1]]
    if(is.na(met))next
    imp<-DBI::dbGetQuery(con,"SELECT * FROM impressions WHERE mode=? AND actor_id=? AND target_id=? AND consent=1 AND created_at<? AND registry_signature=? ORDER BY created_at LIMIT 1",params=list(mode,a,b,met,registry_signature(registry)))
    if(!nrow(imp))next
    keys<-c(keys,key);records[[length(records)+1L]]<-list(pair_id=length(keys),created_at=imp$created_at[[1]],outcome_at=max(f$created_at[c(i,reverse)]),mode=mode,registry_signature=imp$registry_signature[[1]],features=from_json(imp$features[[1]]),instruments=from_json(imp$instrument_features[[1]]),label=as.integer(f$second_date[i]=="yes"&&f$second_date[reverse]=="yes"),target="mutual_second_date_interest")
  }
  records
}
create_matching_experiment <- function(con, actor, id, mode, keys, algorithms) {
  require_admin(con,actor);assert(grepl("^[a-z0-9_-]{3,60}$",id)&&mode%in%CONNECTION_MODES,"Choose a stable experiment ID and mode.")
  assert(length(unique(keys))>=2&&all(keys%in%names(algorithms)),"Choose at least two registered algorithms.")
  assert(!any(vapply(algorithms[keys],function(a)isTRUE(a$learned)&&!mode%in%a$supported_modes,TRUE)),"A model is not evaluated for this space.")
  assert(nrow(DBI::dbGetQuery(con,"SELECT id FROM matching_experiments WHERE enabled=1 AND mode=?",params=list(mode)))==0,"Close the active experiment in this space first.")
  spec<-as.list(vapply(algorithms[keys],`[[`,"","version"))
  DBI::dbExecute(con,"INSERT INTO matching_experiments VALUES(?,?,?,1,?)",params=list(id,mode,to_json(spec),now_utc()))
  audit_event(con,actor,"experiment_started",details=list(id=id,mode=mode,versions=spec))
}

serve_daily_card <- function(con,actor,card,algorithm,registry) {
  req_id<-card$daily_id
  assert(!is.null(req_id),"Choose a daily introduction.")
  DBI::dbWithTransaction(con,{
    row<-DBI::dbGetQuery(con,"SELECT d.impression_id FROM daily_connections d JOIN recommendation_batches b ON b.id=d.batch_id WHERE d.id=? AND b.actor_id=? AND d.target_id=? AND b.mode=?",params=list(req_id,actor,card$profile$user_id,card$mode))
    assert(nrow(row)==1,"Introduction unavailable.")
    assert(eligible_pair(con,get_profile(con,actor),get_profile(con,card$profile$user_id),card$mode),"Introduction unavailable.")
    imp<-row$impression_id[[1]]
    if(is.na(imp)){imp<-log_impression(con,actor,card$profile$user_id,algorithm,registry,card$features,card$mode);DBI::dbExecute(con,"UPDATE daily_connections SET shown_at=?,impression_id=? WHERE id=?",params=list(now_utc(),imp,req_id))}
    imp
  })
}
