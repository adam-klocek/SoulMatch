open_db <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE, mode = "0700")
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  DBI::dbExecute(con, "PRAGMA foreign_keys=ON")
  DBI::dbExecute(con, "PRAGMA secure_delete=ON")
  DBI::dbExecute(con, "PRAGMA journal_mode=WAL")
  DBI::dbExecute(con, "PRAGMA busy_timeout=5000")
  statements <- c(
    "CREATE TABLE IF NOT EXISTS schema_version(version INTEGER PRIMARY KEY)",
    "INSERT OR IGNORE INTO schema_version VALUES(1)",
    "CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TEXT NOT NULL, is_demo INTEGER NOT NULL DEFAULT 0)",
    "CREATE TABLE IF NOT EXISTS profiles(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, name TEXT NOT NULL, age INTEGER NOT NULL CHECK(age BETWEEN 18 AND 100), gender TEXT NOT NULL CHECK(gender IN ('Male','Female','Nonbinary')), interested TEXT NOT NULL, city TEXT NOT NULL, bio TEXT NOT NULL, height REAL, income TEXT NOT NULL, style TEXT NOT NULL, smoking TEXT NOT NULL, goal TEXT NOT NULL, hobbies TEXT NOT NULL, preferences TEXT NOT NULL, consent INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS responses(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, instrument_id TEXT NOT NULL, version TEXT NOT NULL, answers TEXT NOT NULL, scores TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(user_id,instrument_id,version))",
    "CREATE TABLE IF NOT EXISTS decisions(actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, decision TEXT NOT NULL CHECK(decision IN ('like','pass')), updated_at TEXT NOT NULL, CHECK(actor_id<>target_id), PRIMARY KEY(actor_id,target_id))",
    "CREATE TABLE IF NOT EXISTS blocks(actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at TEXT NOT NULL, PRIMARY KEY(actor_id,target_id))",
    "CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT, sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, receiver_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, body TEXT NOT NULL CHECK(length(body) BETWEEN 1 AND 2000), created_at TEXT NOT NULL)",
    "CREATE INDEX IF NOT EXISTS messages_pair ON messages(sender_id,receiver_id,id)",
    "CREATE TABLE IF NOT EXISTS photos(id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, filename TEXT NOT NULL, created_at TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS impressions(id TEXT PRIMARY KEY, actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, algorithm TEXT NOT NULL, algorithm_version TEXT NOT NULL, registry_signature TEXT NOT NULL, features TEXT NOT NULL, instrument_features TEXT NOT NULL, consent INTEGER NOT NULL, created_at TEXT NOT NULL, decision TEXT CHECK(decision IN ('like','pass')), CHECK(actor_id<>target_id))",
    "CREATE TABLE IF NOT EXISTS reports(id TEXT PRIMARY KEY, actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, reason TEXT NOT NULL, created_at TEXT NOT NULL)")
  for (sql in statements) DBI::dbExecute(con, sql)
  migrate_soulmatch(con)
  con
}
get_profile <- function(con, id) {
  p <- DBI::dbGetQuery(con, "SELECT p.*,u.is_demo FROM profiles p JOIN users u ON u.id=p.user_id WHERE p.user_id=?", params = list(id))
  if (!nrow(p)) return(NULL)
  p <- as.list(p[1, ])
  for (key in c("interested", "hobbies", "preferences")) p[[key]] <- from_json(p[[key]])
  p$interested <- unlist(p$interested, use.names = FALSE)
  p$hobbies <- unlist(p$hobbies, use.names = FALSE)
  p$preferences <- as_preferences(p$preferences)
  p$connection_modes <- unlist(from_json(p$connection_modes), use.names = FALSE)
  p
}
register_user <- function(con, username, password) {
  username <- tolower(trimws(username))
  assert(grepl("^[a-z0-9_]{3,30}$", username), "Use 3–30 lowercase letters, numbers or underscores.")
  assert(nchar(password) >= 12 && nchar(password) <= 200, "Use a password of 12–200 characters.")
  assert(!nrow(DBI::dbGetQuery(con, "SELECT id FROM users WHERE username=?", params = list(username))), "That username is unavailable.")
  id <- new_id()
  DBI::dbExecute(con, "INSERT INTO users(id,username,password_hash,created_at) VALUES(?,?,?,?)", params = list(id, username, sodium::password_store(password), now_utc()))
  id
}
authenticate <- function(con, username, password) {
  u <- DBI::dbGetQuery(con, "SELECT id,password_hash FROM users WHERE username=?", params = list(tolower(trimws(username))))
  if (!nrow(u) || !isTRUE(tryCatch(sodium::password_verify(u$password_hash[[1]], password), error = function(e) FALSE))) return(NULL)
  u$id[[1]]
}
save_profile <- function(con, id, p) {
  assert(nrow(DBI::dbGetQuery(con, "SELECT id FROM users WHERE id=?", params = list(id))) == 1, "Sign in first.")
  p$name <- clean_text(p$name, 40); p$city <- clean_text(p$city, 80); p$bio <- clean_text(p$bio, 600)
  assert(nzchar(p$name) && nzchar(p$city), "Add your name and city.")
  assert(is.finite(p$age) && p$age == floor(p$age) && p$age >= 18 && p$age <= 100, "This app is for adults aged 18–100.")
  assert(p$gender %in% GENDERS, "Select your gender.")
  if (is.null(p$connection_modes)) p$connection_modes <- "love"
  assert(length(p$connection_modes) > 0 && all(p$connection_modes %in% CONNECTION_MODES), "Choose Love, Friends, or both.")
  assert(all(p$interested %in% GENDERS) && (!("love" %in% p$connection_modes) || length(p$interested) > 0), "For Love, choose at least one gender you are interested in.")
  assert(p$goal %in% GOALS && p$income %in% INCOMES && p$style %in% STYLES && p$smoking %in% c("No", "Sometimes", "Yes"), "Invalid profile choice.")
  assert(all(p$hobbies %in% HOBBIES), "Invalid interest.")
  # Height can only be supplied by the separate questionnaire service, never a profile input.
  existing <- DBI::dbGetQuery(con, "SELECT height FROM profiles WHERE user_id=?", params = list(id))
  derived_height <- if (nrow(existing)) existing$height[[1]] else NA_real_
  prefs <- as_preferences(p$preferences)
  for (key in c("age", "height")) {
    values <- as.numeric(unlist(prefs[[key]])); bounds <- switch(key, age = c(18, 100), height = c(100, 250))
    assert(length(values) == 2 && all(is.finite(values)) && values[1] <= values[2] && values[1] >= bounds[1] && values[2] <= bounds[2], "Invalid preference range.")
    prefs[[key]] <- values
  }
  assert(all(unlist(prefs$income) %in% INCOMES[-1]) && all(unlist(prefs$styles) %in% STYLES), "Invalid preference category.")
  assert(prefs$smoking %in% c("Any", "No", "Sometimes", "Yes") && prefs$goal %in% c("Any", GOALS), "Invalid preference.")
  for (key in names(prefs)[startsWith(names(prefs), "hard_")]) assert(is.logical(prefs[[key]]) && length(prefs[[key]]) == 1 && !is.na(prefs[[key]]), "Invalid firm boundary.")
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "INSERT INTO profiles(user_id,name,age,gender,interested,city,bio,height,income,style,smoking,goal,hobbies,preferences,consent,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET name=excluded.name,age=excluded.age,gender=excluded.gender,interested=excluded.interested,city=excluded.city,bio=excluded.bio,income=excluded.income,style=excluded.style,smoking=excluded.smoking,goal=excluded.goal,hobbies=excluded.hobbies,preferences=excluded.preferences,consent=excluded.consent,updated_at=excluded.updated_at", params = list(id, p$name, as.integer(p$age), p$gender, to_json(as.list(p$interested)), p$city, p$bio, derived_height, p$income, p$style, p$smoking, p$goal, to_json(as.list(p$hobbies)), to_json(prefs), as.integer(isTRUE(as.logical(p$consent))), now_utc()))
    # Withdrawal excludes historical impressions from any later training export.
    if (!isTRUE(as.logical(p$consent))) DBI::dbExecute(con, "UPDATE impressions SET consent=0 WHERE actor_id=? OR target_id=?", params = list(id, id))
    DBI::dbExecute(con, "UPDATE profiles SET connection_modes=? WHERE user_id=?", params = list(to_json(as.list(unique(p$connection_modes))), id))
  })
  invisible(id)
}
has_block <- function(con, a, b) nrow(DBI::dbGetQuery(con, "SELECT 1 FROM blocks WHERE (actor_id=? AND target_id=?) OR (actor_id=? AND target_id=?)", params = list(a, b, b, a))) > 0
is_mutual <- function(con, a, b, mode = "love") {
  if (identical(a, b) || has_block(con, a, b)) return(FALSE)
  p <- get_profile(con, a); q <- get_profile(con, b)
  if (is.null(p) || is.null(q) || !(mode %in% p$connection_modes) || !(mode %in% q$connection_modes)) return(FALSE)
  nrow(DBI::dbGetQuery(con, "SELECT 1 FROM decisions WHERE decision='like' AND mode=? AND ((actor_id=? AND target_id=?) OR (actor_id=? AND target_id=?))", params = list(mode, a, b, b, a))) == 2
}
save_decision <- function(con, actor, target, decision, impression_id, registry, mode = "love") {
  assert(decision %in% c("like", "pass"), "Invalid decision.")
  DBI::dbWithTransaction(con, {
    a <- get_profile(con, actor); b <- get_profile(con, target)
    assert(!is.null(a) && !is.null(b) && completed_required(con, actor, registry) && completed_required(con, target, registry) && eligible_pair(con, a, b, mode), "This profile is no longer available in this mode.")
    impression <- DBI::dbGetQuery(con, "SELECT id FROM impressions WHERE id=? AND actor_id=? AND target_id=? AND mode=? AND decision IS NULL", params = list(impression_id, actor, target, mode))
    assert(nrow(impression) == 1, "Refresh discovery before deciding.")
    DBI::dbExecute(con, "INSERT INTO decisions VALUES(?,?,?,?,?) ON CONFLICT(actor_id,target_id,mode) DO UPDATE SET decision=excluded.decision,updated_at=excluded.updated_at", params = list(actor, target, decision, now_utc(), mode))
    DBI::dbExecute(con, "UPDATE impressions SET decision=? WHERE id=?", params = list(decision, impression_id))
  })
}
send_message <- function(con, sender, receiver, body, mode = "love") {
  body <- clean_text(body, 2000)
  assert(nzchar(body), "Write a message first.")
  DBI::dbWithTransaction(con, {
    assert(is_mutual(con, sender, receiver, mode), "Chat requires an active mutual connection in this mode.")
    DBI::dbExecute(con, "INSERT INTO messages(sender_id,receiver_id,body,created_at,mode) VALUES(?,?,?,?,?)", params = list(sender, receiver, body, now_utc(), mode))
  })
}
read_messages <- function(con, a, b, mode = "love") {
  assert(is_mutual(con, a, b, mode), "This conversation is unavailable.")
  DBI::dbGetQuery(con, "SELECT * FROM (SELECT * FROM messages WHERE mode=? AND ((sender_id=? AND receiver_id=?) OR (sender_id=? AND receiver_id=?)) ORDER BY id DESC LIMIT 200) ORDER BY id", params = list(mode, a, b, b, a))
}
delete_account <- function(con, id, photo_dir) {
  files <- DBI::dbGetQuery(con, "SELECT filename FROM photos WHERE user_id=?", params = list(id))$filename
  DBI::dbExecute(con, "DELETE FROM users WHERE id=?", params = list(id))
  for (f in files) unlink(file.path(photo_dir, basename(f)))
}
