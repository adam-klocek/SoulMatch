fixture <- function() {
  path <- tempfile(fileext = ".sqlite"); con <- open_db(path); registry <- load_registry()
  withr::defer(DBI::dbDisconnect(con), envir = parent.frame())
  seed_interest_catalog(con, load_interest_catalog())
  seed_demo(con, registry)
  users <- DBI::dbGetQuery(con, "SELECT id,username FROM users")
  ids <- as.list(setNames(users$id, users$username))
  list(con = con, path = path, registry = registry, ids = ids, algorithms = algorithm_registry(registry))
}
make_impression <- function(f, a, b) log_impression(f$con, a, b, f$algorithms$balanced, f$registry, pair_features(f$con, get_profile(f$con, a), get_profile(f$con, b), f$registry))
