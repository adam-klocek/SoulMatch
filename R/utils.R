`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
now_utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
new_id <- function() paste(sprintf("%02x", as.integer(sodium::random(16))), collapse = "")
to_json <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = 12)
from_json <- function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)
assert <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)
clamp <- function(x) pmax(0, pmin(1, x))
safe_num <- function(x) if (is.null(x) || !length(x) || is.na(x)) NA_real_ else as.numeric(x)
clean_text <- function(x, max_n = 600L) {
  x <- trimws(as.character(x %||% ""))
  assert(length(x) == 1 && nchar(x) <= max_n, paste("Text must be at most", max_n, "characters."))
  x
}
GENDERS <- c("Male", "Female", "Nonbinary")
CONNECTION_MODES <- c("love", "friends")
resolve_db_path <- function(data_dir) {
  configured <- Sys.getenv("SOULMATCH_DB_PATH", "")
  if (nzchar(configured)) return(configured)
  current <- file.path(data_dir, "soulmatch.sqlite"); legacy <- file.path(data_dir, "kindred.sqlite")
  if (!file.exists(current) && file.exists(legacy)) legacy else current
}
GOALS <- c("Long-term relationship", "Open to exploring", "Casual dating")
INCOMES <- c("Prefer not to say", "Under 25k", "25–50k", "50–100k", "100k+")
STYLES <- c("Casual", "Creative", "Sporty", "Classic", "Alternative")
HOBBIES <- c("Hiking", "Books", "Music", "Cooking", "Art", "Travel", "Gaming", "Fitness", "Science", "Cinema")
DEFAULT_PREFS <- list(age = c(22, 45), height = c(140, 210),
  income = character(), styles = character(), smoking = "Any", goal = "Any",
  hard_age = FALSE, hard_smoking = FALSE,
  hard_goal = FALSE, hard_income = FALSE, hard_styles = FALSE)
as_preferences <- function(x) {
  x <- x %||% list()
  # Strict whitelist: retired measurements and unknown preference keys never enter matching.
  modifyList(DEFAULT_PREFS, x[intersect(names(x), names(DEFAULT_PREFS))])
}
optional_rating <- function(x, max_value = 5L) {
  if (is.null(x) || !length(x) || identical(x, "") || is.na(x)) return(NA_integer_)
  value <- suppressWarnings(as.numeric(x))
  assert(length(value) == 1 && is.finite(value) && value == floor(value) && value >= 1 && value <= max_value, "Choose a valid response or leave it unanswered.")
  as.integer(value)
}
