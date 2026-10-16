migrate_soulmatch <- function(con) {
  version <- max(DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version)
  changed <- FALSE
  if (version < 2) DBI::dbWithTransaction(con, {
    if ("weight" %in% DBI::dbListFields(con, "profiles")) DBI::dbExecute(con, "ALTER TABLE profiles DROP COLUMN weight")
    rows <- DBI::dbGetQuery(con, "SELECT user_id,preferences FROM profiles")
    for (i in seq_len(nrow(rows))) DBI::dbExecute(con, "UPDATE profiles SET preferences=?,height=NULL WHERE user_id=?", params = list(to_json(as_preferences(from_json(rows$preferences[i]))), rows$user_id[i]))
    # Legacy feature snapshots can contain contributions from a retired measurement.
    DBI::dbExecute(con, "DELETE FROM impressions")
    statements <- c(
      "CREATE TABLE response_history(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,instrument_id TEXT NOT NULL,version TEXT NOT NULL,answers TEXT NOT NULL,scores TEXT NOT NULL,created_at TEXT NOT NULL)",
      "INSERT INTO response_history SELECT lower(hex(randomblob(16))),user_id,instrument_id,version,answers,scores,updated_at FROM responses",
      "CREATE TABLE response_drafts(user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,instrument_id TEXT NOT NULL,version TEXT NOT NULL,answers TEXT NOT NULL,page INTEGER NOT NULL,updated_at TEXT NOT NULL,PRIMARY KEY(user_id,instrument_id,version))",
      "CREATE TABLE height_responses(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,version TEXT NOT NULL,answers TEXT NOT NULL,reference_group TEXT NOT NULL,raw_score REAL NOT NULL,estimate_cm REAL,lower_cm REAL,upper_cm REAL,allow_matching INTEGER NOT NULL,created_at TEXT NOT NULL)",
      "CREATE TABLE interest_categories(id TEXT PRIMARY KEY,label TEXT NOT NULL,sort_order INTEGER NOT NULL)",
      "CREATE TABLE interests(id TEXT PRIMARY KEY,category_id TEXT NOT NULL REFERENCES interest_categories(id),label TEXT NOT NULL,sort_order INTEGER NOT NULL)",
      "CREATE TABLE lifestyle_questions(id TEXT PRIMARY KEY,prompt TEXT NOT NULL,measurement_type TEXT NOT NULL,options TEXT NOT NULL)",
      "CREATE TABLE questionnaire_versions(id TEXT PRIMARY KEY,instrument_id TEXT NOT NULL,version TEXT NOT NULL,created_at TEXT NOT NULL,UNIQUE(instrument_id,version))",
      "CREATE TABLE questionnaire_sessions(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,questionnaire_version_id TEXT NOT NULL REFERENCES questionnaire_versions(id),status TEXT NOT NULL CHECK(status IN ('draft','completed')),step INTEGER NOT NULL,navigation TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)",
      "CREATE INDEX questionnaire_sessions_owner ON questionnaire_sessions(user_id,questionnaire_version_id,updated_at)",
      "CREATE TABLE user_interests(session_id TEXT NOT NULL REFERENCES questionnaire_sessions(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,questionnaire_version_id TEXT NOT NULL REFERENCES questionnaire_versions(id),interest_id TEXT NOT NULL REFERENCES interests(id),enjoyment INTEGER,frequency INTEGER,updated_at TEXT NOT NULL,PRIMARY KEY(session_id,interest_id))",
      "CREATE TABLE user_interest_partner_preferences(session_id TEXT NOT NULL REFERENCES questionnaire_sessions(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,questionnaire_version_id TEXT NOT NULL REFERENCES questionnaire_versions(id),interest_id TEXT NOT NULL REFERENCES interests(id),importance INTEGER,updated_at TEXT NOT NULL,PRIMARY KEY(session_id,interest_id))",
      "CREATE TABLE lifestyle_responses(session_id TEXT NOT NULL REFERENCES questionnaire_sessions(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,questionnaire_version_id TEXT NOT NULL REFERENCES questionnaire_versions(id),question_id TEXT NOT NULL REFERENCES lifestyle_questions(id),option_value TEXT,updated_at TEXT NOT NULL,PRIMARY KEY(session_id,question_id))",
      "CREATE TABLE lifestyle_partner_preferences(session_id TEXT NOT NULL REFERENCES questionnaire_sessions(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,questionnaire_version_id TEXT NOT NULL REFERENCES questionnaire_versions(id),question_id TEXT NOT NULL REFERENCES lifestyle_questions(id),importance INTEGER,updated_at TEXT NOT NULL,PRIMARY KEY(session_id,question_id))",
      "CREATE TABLE shared_activity_preferences(session_id TEXT NOT NULL REFERENCES questionnaire_sessions(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,questionnaire_version_id TEXT NOT NULL REFERENCES questionnaire_versions(id),activity_id TEXT NOT NULL,importance INTEGER,updated_at TEXT NOT NULL,PRIMARY KEY(session_id,activity_id))",
      "CREATE TABLE custom_interest_suggestions(session_id TEXT PRIMARY KEY REFERENCES questionnaire_sessions(id) ON DELETE CASCADE,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,suggestion TEXT NOT NULL,updated_at TEXT NOT NULL)",
      "INSERT INTO schema_version VALUES(2)")
    for (sql in statements) DBI::dbExecute(con, sql)
    changed <- TRUE
  })
  if (version < 3) DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "ALTER TABLE profiles ADD COLUMN connection_modes TEXT NOT NULL DEFAULT '[\"love\"]'")
    DBI::dbExecute(con, "ALTER TABLE decisions RENAME TO decisions_legacy")
    DBI::dbExecute(con, "CREATE TABLE decisions(actor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,decision TEXT NOT NULL CHECK(decision IN ('like','pass')),updated_at TEXT NOT NULL,mode TEXT NOT NULL CHECK(mode IN ('love','friends')),CHECK(actor_id<>target_id),PRIMARY KEY(actor_id,target_id,mode))")
    DBI::dbExecute(con, "INSERT INTO decisions SELECT actor_id,target_id,decision,updated_at,'love' FROM decisions_legacy")
    DBI::dbExecute(con, "DROP TABLE decisions_legacy")
    DBI::dbExecute(con, "ALTER TABLE messages ADD COLUMN mode TEXT NOT NULL DEFAULT 'love'")
    DBI::dbExecute(con, "ALTER TABLE impressions ADD COLUMN mode TEXT NOT NULL DEFAULT 'love'")
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES(3)")
    changed <- TRUE
  })
  if (changed) {
    DBI::dbExecute(con, "PRAGMA wal_checkpoint(TRUNCATE)")
    DBI::dbExecute(con, "VACUUM")
  }
  invisible(changed)
}
