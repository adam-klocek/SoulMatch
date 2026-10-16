INTEREST_FEATURES <- c("interest_overlap", "weighted_interest_similarity", "own_interest_satisfaction", "other_interest_satisfaction", "frequency_alignment", "lifestyle_compatibility", "lifestyle_complementarity", "shared_activity_potential", "interest_coverage", "lifestyle_coverage")
weighted_available <- function(values, weights = rep(1, length(values))) {
  keep <- is.finite(values) & is.finite(weights) & weights > 0
  if (any(keep)) stats::weighted.mean(values[keep], weights[keep]) else NA_real_
}
extract_interest_features <- function(a, b, catalog) {
  shared <- intersect(a$selected, b$selected); union <- union(a$selected, b$selected)
  rating_count <- function(state) sum(vapply(state$details[state$selected], function(x) sum(is.finite(unlist(x[c("enjoyment", "frequency", "importance")]))), 0L))
  overlap <- if (length(union)) length(shared) / length(union) else NA_real_
  # Missing selections mean "not reported", not dislike. Satisfaction uses only explicit answers.
  satisfaction <- function(owner, other) {
    v <- w <- numeric()
    for (id in intersect(owner$selected, other$selected)) {
      desire <- owner$details[[id]]$importance; enjoyment <- other$details[[id]]$enjoyment
      if (is.null(desire) || is.null(enjoyment) || is.na(desire) || is.na(enjoyment)) next
      v <- c(v, (enjoyment - 1) / 4); w <- c(w, (desire - 1) / 4)
    }
    weighted_available(v, w)
  }
  enjoyment_similarity <- frequency <- numeric()
  for (id in shared) {
    x <- a$details[[id]]; y <- b$details[[id]]
    if (all(is.finite(c(x$enjoyment, y$enjoyment))) && length(c(x$enjoyment, y$enjoyment)) == 2) enjoyment_similarity <- c(enjoyment_similarity, 1 - abs(x$enjoyment - y$enjoyment) / 4)
    if (all(is.finite(c(x$frequency, y$frequency))) && length(c(x$frequency, y$frequency)) == 2) frequency <- c(frequency, 1 - abs(x$frequency - y$frequency) / 4)
  }
  life <- complement <- weights <- numeric(); possible_life <- length(catalog$definition$lifestyle)
  for (q in catalog$definition$lifestyle) {
    x <- a$lifestyle[[q$id]]; y <- b$lifestyle[[q$id]]
    if (is.null(x) || is.null(y)) next
    if (q$measurement_type == "ordinal") {
      values <- vapply(q$options, `[[`, "", "value")
      similarity <- 1 - abs(match(x, values) - match(y, values)) / (length(values) - 1)
      complement <- c(complement, 1 - similarity)
    } else similarity <- as.numeric(x == y)
    importance <- c(a$lifestyle_importance[[q$id]], b$lifestyle_importance[[q$id]])
    importance <- importance[is.finite(importance)]
    # No specified importance contributes no ranking weight.
    weight <- if (length(importance)) mean((importance - 1) / 4) else 0
    life <- c(life, similarity); weights <- c(weights, weight)
  }
  shared_activities <- intersect(names(a$shared), names(b$shared))
  potentials <- vapply(shared_activities, function(id) {
    x <- a$shared[[id]]; y <- b$shared[[id]]
    if (is.na(x) || is.na(y)) NA_real_ else min(x, y) / 3
  }, 0)
  c(interest_overlap = overlap, weighted_interest_similarity = weighted_available(enjoyment_similarity),
    own_interest_satisfaction = satisfaction(a, b), other_interest_satisfaction = satisfaction(b, a),
    frequency_alignment = weighted_available(frequency), lifestyle_compatibility = weighted_available(life, weights),
    lifestyle_complementarity = weighted_available(complement), shared_activity_potential = weighted_available(potentials),
    interest_coverage = if (length(union)) (rating_count(a) + rating_count(b)) / (6 * length(union)) else 0,
    lifestyle_coverage = length(life) / possible_life)[INTEREST_FEATURES]
}
interest_pair_features <- function(con, a, b, catalog = load_interest_catalog()) {
  x <- read_interest_state(con, a, catalog, completed_only = TRUE)
  y <- read_interest_state(con, b, catalog, completed_only = TRUE)
  extract_interest_features(x, y, catalog)
}
