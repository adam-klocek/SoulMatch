load_registry <- function(path = getOption("soulmatch.questionnaire_dir", "config/questionnaires")) {
  assert(dir.exists(path), paste("Questionnaire directory not found:", path))
  specs <- lapply(list.files(path, pattern = "\\.json$", full.names = TRUE), function(file) {
    q <- from_json(paste(readLines(file, warn = FALSE), collapse = "\n"))
    q$items <- NULL
    if (isTRUE(q$enabled)) {
      assert(is.numeric(q$scale_min) && is.numeric(q$scale_max) && q$scale_max > q$scale_min && length(q$scale_labels) == q$scale_max - q$scale_min + 1, "Invalid response scale.")
      item_path <- file.path(path, q$item_file)
      assert(file.exists(item_path), paste("Missing item file:", item_path))
      q$items <- read.csv(item_path, stringsAsFactors = FALSE, check.names = FALSE)
      assert(all(c("id", "text", "domain", "reverse") %in% names(q$items)), "Questionnaires require id,text,domain,reverse columns.")
      assert(nrow(q$items) == q$item_count && !anyDuplicated(q$items$id) && all(nzchar(q$items$text)) && all(nzchar(q$items$domain)), paste("Invalid item set:", q$id))
      assert(all(q$items$reverse %in% c(0, 1)), "Reverse must be 0 or 1.")
      assert(!is.null(q$permission_note) && nzchar(q$permission_note), "Record instrument usage permission before enabling.")
    }
    q
  })
  keys <- vapply(specs, function(q) paste(q$id, q$version, sep = "@"), "")
  assert(length(specs) > 0, "The questionnaire registry is empty.")
  assert(!anyDuplicated(keys), "Duplicate instrument version.")
  # One active version per instrument avoids silently selecting between versions.
  active <- vapply(specs, function(q) isTRUE(q$enabled), TRUE)
  assert(!anyDuplicated(vapply(specs[active], `[[`, "", "id")), "Only one active version per instrument ID is allowed.")
  names(specs) <- keys
  specs
}
active_instruments <- function(registry) Filter(function(q) isTRUE(q$enabled), registry)
registry_signature <- function(registry) {
  active <- active_instruments(registry)
  paste0("soulmatch-v3:context-preferences:interests_lifestyle@1.0.0:scoped-modes|", paste(vapply(active, function(q) paste(q$id, q$version, isTRUE(q$use_for_matching), sep = ":"), ""), collapse = "|"))
}
score_answers <- function(q, answers) {
  assert(isTRUE(q$enabled), "This questionnaire is not active.")
  values <- suppressWarnings(as.numeric(unlist(answers[q$items$id], use.names = FALSE)))
  assert(length(values) == nrow(q$items) && all(is.finite(values)) && all(values == floor(values)) && all(values >= q$scale_min & values <= q$scale_max), "Answer every item before saving.")
  values[q$items$reverse == 1] <- q$scale_min + q$scale_max - values[q$items$reverse == 1]
  as.list(tapply(values, q$items$domain, mean))
}
save_answers <- function(con, user_id, q, answers) {
  scores <- score_answers(q, answers)
  DBI::dbWithTransaction(con, {
    stamp <- now_utc()
    DBI::dbExecute(con, "INSERT INTO responses VALUES(?,?,?,?,?,?) ON CONFLICT(user_id,instrument_id,version) DO UPDATE SET answers=excluded.answers,scores=excluded.scores,updated_at=excluded.updated_at", params = list(user_id, q$id, q$version, to_json(answers[q$items$id]), to_json(scores), stamp))
    DBI::dbExecute(con, "INSERT INTO response_history VALUES(?,?,?,?,?,?,?)", params = list(new_id(), user_id, q$id, q$version, to_json(answers[q$items$id]), to_json(scores), stamp))
    DBI::dbExecute(con, "DELETE FROM response_drafts WHERE user_id=? AND instrument_id=? AND version=?", params = list(user_id, q$id, q$version))
  })
  scores
}
completed_required <- function(con, user_id, registry) {
  required <- Filter(function(q) isTRUE(q$required), active_instruments(registry))
  all(vapply(required, function(q) nrow(DBI::dbGetQuery(con, "SELECT 1 FROM responses WHERE user_id=? AND instrument_id=? AND version=?", params = list(user_id, q$id, q$version))) == 1, TRUE))
}
questionnaire_similarity <- function(con, a, b, registry, exclude = character()) {
  qs <- Filter(function(q) isTRUE(q$use_for_matching) && !(q$id %in% exclude), active_instruments(registry))
  scores <- numeric(); possible <- 0; components <- list()
  for (q in qs) {
    possible <- possible + 1
    key <- paste(q$id, q$version, sep = "@"); components[key] <- list(NULL)
    rows <- DBI::dbGetQuery(con, "SELECT user_id,scores FROM responses WHERE user_id IN (?,?) AND instrument_id=? AND version=?", params = list(a, b, q$id, q$version))
    if (nrow(rows) != 2) next
    x <- unlist(from_json(rows$scores[rows$user_id == a])); y <- unlist(from_json(rows$scores[rows$user_id == b]))
    common <- intersect(names(x), names(y))
    if (length(common)) {
      similarity <- 1 - mean(abs(x[common] - y[common])) / (q$scale_max - q$scale_min)
      scores <- c(scores, similarity); components[[key]] <- similarity
    }
  }
  list(similarity = if (length(scores)) mean(scores) else 0.5, coverage = if (possible) length(scores) / possible else 0, components = components)
}
