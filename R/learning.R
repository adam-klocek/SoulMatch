export_training <- function(con, registry) {
  # Labels are explicit decisions following a logged view. Silence is never a rejection.
  rows <- DBI::dbGetQuery(con, "SELECT i.* FROM impressions i JOIN profiles a ON a.user_id=i.actor_id JOIN profiles b ON b.user_id=i.target_id JOIN users u ON u.id=i.actor_id JOIN users v ON v.id=i.target_id WHERE i.consent=1 AND a.consent=1 AND b.consent=1 AND u.is_demo=0 AND v.is_demo=0 AND i.decision IS NOT NULL AND i.registry_signature=? ORDER BY i.created_at,i.id", params = list(registry_signature(registry)))
  if (!nrow(rows)) return(list())
  # Do not give repeated views extra training weight. Retain the first labeled directed pair.
  rows <- rows[!duplicated(paste(rows$actor_id, rows$target_id, rows$mode, sep = ":")), , drop = FALSE]
  pairs <- vapply(seq_len(nrow(rows)), function(i) paste(sort(c(rows$actor_id[i], rows$target_id[i])), collapse = ":"), "")
  pair_ids <- match(pairs, unique(pairs))
  lapply(seq_len(nrow(rows)), function(i) list(schema_version = 2, mode = rows$mode[i], pair_id = pair_ids[i], created_at = rows$created_at[i], registry_signature = rows$registry_signature[i], algorithm = rows$algorithm[i], algorithm_version = rows$algorithm_version[i], features = from_json(rows$features[i]), instruments = from_json(rows$instrument_features[i]), label = as.integer(rows$decision[i] == "like")))
}
auc_score <- function(y, p) {
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  if (!n1 || !n0) return(NA_real_)
  (sum(rank(p)[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
cluster_brier_interval <- function(y,p,groups=seq_along(y),repetitions=200L) {
  blocks<-split(seq_along(y),groups)
  if(length(blocks)<10)return(c(NA_real_,NA_real_))
  draws<-replicate(repetitions,{i<-unlist(blocks[sample(seq_along(blocks),length(blocks),replace=TRUE)],use.names=FALSE);mean((p[i]-y[i])^2)})
  unname(stats::quantile(draws,c(.025,.975)))
}
model_metrics <- function(y, p, groups=seq_along(y)) {
  bin <- cut(p, breaks = seq(0, 1, length.out = 11), include.lowest = TRUE)
  ece <- sum(vapply(split(seq_along(y), bin), function(i) if (length(i)) length(i) / length(y) * abs(mean(y[i]) - mean(p[i])) else 0, 0))
  list(n = length(y), positive = sum(y), brier = mean((p - y)^2), brier_ci = cluster_brier_interval(y,p,groups), auc = auc_score(y, p), ece = ece)
}
time_pair_split <- function(records) {
  ids <- vapply(records,function(r)as.character(r$pair_id),"")
  times <- vapply(records,function(r)r$created_at,"")
  first <- vapply(split(times,ids),min,""); pairs <- names(sort(first))
  assert(length(pairs)>=10,"Too few distinct pairs.")
  n<-length(pairs);mapping<-setNames(c(rep("train",floor(.6*n)),rep("calibrate",floor(.2*n)),rep("test",n-floor(.6*n)-floor(.2*n))),pairs)
  attr(mapping,"calibration_start")<-min(first[names(mapping)[mapping=="calibrate"]])
  attr(mapping,"test_start")<-min(first[names(mapping)[mapping=="test"]])
  mapping
}
fit_like_model <- function(data, splits) {
  assert(all(vapply(split(data$label, splits), function(y) length(unique(y)) == 2, TRUE)), "Each partition needs positive and negative decisions.")
  variable <- FEATURE_NAMES[vapply(data[splits == "train", FEATURE_NAMES], function(x) length(unique(x)) > 1, TRUE)]
  assert(length(variable) > 0, "Training features have no variation.")
  design <- stats::model.matrix(stats::reformulate(variable), data = data[splits == "train", ])
  qr_design <- qr(design)
  independent <- colnames(design)[qr_design$pivot[seq_len(qr_design$rank)]]
  variable <- intersect(variable, independent)
  assert(length(variable) > 0, "Training features are not independently estimable.")
  fit <- stats::glm(stats::reformulate(variable, response = "label"), data = data[splits == "train", ], family = stats::binomial())
  assert(isTRUE(fit$converged) && all(is.finite(stats::coef(fit))), "Model failed or has aliased features. Collect more varied data before fitting.")
  raw <- function(d) pmax(1e-6, pmin(1 - 1e-6, as.numeric(stats::predict(fit, newdata = d, type = "response"))))
  calibration_data <- data.frame(label = data$label[splits == "calibrate"], logit = stats::qlogis(raw(data[splits == "calibrate", ])))
  calibration <- stats::glm(label ~ logit, data = calibration_data, family = stats::binomial())
  assert(isTRUE(calibration$converged) && all(is.finite(stats::coef(calibration))), "Calibration failed.")
  coefficients <- unname(stats::coef(calibration))
  predictions <- stats::plogis(coefficients[1] + coefficients[2] * stats::qlogis(raw(data[splits == "test", ])))
  list(fit = fit, calibration = coefficients, predictions = predictions, metrics = model_metrics(data$label[splits == "test"], predictions))
}
train_like_model <- function(records, registry, approve = FALSE) {
  assert(length(records) >= 2000, "Collect at least 2,000 opted-in explicit decisions from non-demo users first.")
  assert(all(vapply(records, function(r) identical(r$registry_signature, registry_signature(registry)), TRUE)), "Export and current questionnaire registry differ.")
  assert(all(vapply(records, function(r) setequal(names(r$features), FEATURE_NAMES), TRUE)), "Feature schema mismatch.")
  data <- as.data.frame(do.call(rbind, lapply(records, function(r) as.numeric(unlist(r$features[FEATURE_NAMES])))))
  names(data) <- FEATURE_NAMES
  data$label <- vapply(records, function(r) as.integer(r$label), 0L)
  assert(all(data$label %in% 0:1) && all(vapply(data[FEATURE_NAMES], function(x) all(is.finite(x) & x >= 0 & x <= 1), TRUE)), "Invalid features or labels.")
  assert(all(data$is_friend_mode %in% 0:1), "Connection mode must be 0 (Love) or 1 (Friends).")
  mapping <- time_pair_split(records)
  splits <- unname(mapping[vapply(records, function(r) as.character(r$pair_id), "")])
  times <- vapply(records,function(r)r$created_at,"")
  # A pair stays in one partition; later events from old pairs are dropped,
  # rather than leaking events past a temporal boundary into training.
  keep <- (splits=="train" & times<attr(mapping,"calibration_start")) | (splits=="calibrate" & times>=attr(mapping,"calibration_start") & times<attr(mapping,"test_start")) | (splits=="test" & times>=attr(mapping,"test_start"))
  if (identical(records[[1]]$target,"mutual_second_date_interest")) {
    outcomes <- vapply(records,function(r)r$outcome_at,"")
    keep <- keep & ((splits=="train" & outcomes<attr(mapping,"calibration_start")) | (splits=="calibrate" & outcomes<attr(mapping,"test_start")) | splits=="test")
  }
  excluded_temporal <- sum(!keep);data<-data[keep,,drop=FALSE];records<-records[keep];splits<-splits[keep]
  result <- fit_like_model(data, splits)
  result$metrics$brier_ci <- cluster_brier_interval(data$label[splits=="test"],result$predictions,vapply(records[splits=="test"],function(r)as.character(r$pair_id),""))
  prevalence <- mean(data$label[splits == "train"])
  baseline_brier <- mean((prevalence - data$label[splits == "test"])^2)
  test_modes <- ifelse(data$is_friend_mode[splits == "test"] == 1, "friends", "love")
  mode_metrics <- lapply(CONNECTION_MODES, function(mode) {
    keep <- test_modes == mode
    if (!any(keep)) return(list(n = 0L))
    model_metrics(data$label[splits == "test"][keep], result$predictions[keep])
  }); names(mode_metrics) <- CONNECTION_MODES
  supported_modes <- CONNECTION_MODES[vapply(mode_metrics, function(m) m$n >= 100 && m$positive >= 25 && (m$n - m$positive) >= 25 && is.finite(m$ece) && m$ece <= .15, TRUE)]
  metrics <- c(result$metrics, list(baseline_brier = baseline_brier, train_n = sum(splits == "train"), calibration_n = sum(splits == "calibrate"), excluded_temporal = excluded_temporal, split = "Strict time windows with unordered pairs kept together. Later events/outcomes from earlier pairs are excluded. Users may appear in multiple partitions."))
  # Exploratory ablations preserve train/calibrate/test membership. They are not a causal validity test.
  instruments <- names(records[[1]]$instruments)
  ablations <- lapply(instruments, function(removed) {
    ablated <- data
    for (i in seq_along(records)) {
      component <- records[[i]]$instruments[setdiff(instruments, removed)]
      present <- unlist(component, use.names = FALSE)
      ablated$questionnaire_similarity[i] <- if (length(present)) mean(present) else .5
      ablated$questionnaire_coverage[i] <- if (length(component)) length(present) / length(component) else 0
    }
    tryCatch({
      # Removing the sole available instrument produces constant features; omit those predictors.
      variable <- FEATURE_NAMES[vapply(ablated[splits == "train", FEATURE_NAMES], function(x) length(unique(x)) > 1, TRUE)]
      fit <- stats::glm(stats::reformulate(variable, response = "label"), data = ablated[splits == "train", ], family = stats::binomial())
      raw <- function(d) pmax(1e-6, pmin(1 - 1e-6, as.numeric(stats::predict(fit, d, type = "response"))))
      cal <- stats::glm(y ~ z, data = data.frame(y = ablated$label[splits == "calibrate"], z = stats::qlogis(raw(ablated[splits == "calibrate", ]))), family = stats::binomial())
      pred <- stats::plogis(stats::coef(cal)[1] + stats::coef(cal)[2] * stats::qlogis(raw(ablated[splits == "test", ])))
      m <- model_metrics(ablated$label[splits == "test"], pred)
      loss_difference <- (pred-ablated$label[splits=="test"])^2-(result$predictions-data$label[splits=="test"])^2
      groups <- vapply(records[splits=="test"],function(r)as.character(r$pair_id),"");blocks<-split(seq_along(loss_difference),groups)
      boot<-replicate(200,{i<-unlist(blocks[sample(seq_along(blocks),length(blocks),replace=TRUE)],use.names=FALSE);mean(loss_difference[i])})
      list(removed=removed,metrics=m,brier_increase_when_removed=m$brier-result$metrics$brier,difference_ci=unname(stats::quantile(boot,c(.025,.975))),bootstrap_p=min(1,2*min((1+sum(boot<=0))/(length(boot)+1),(1+sum(boot>=0))/(length(boot)+1))))
    }, error = function(e) list(removed = removed, error = conditionMessage(e)))
  })
  p_values<-vapply(ablations,function(a)a$bootstrap_p%||%NA_real_,0)
  adjusted<-stats::p.adjust(p_values,method="BH")
  for(i in seq_along(ablations))ablations[[i]]$bh_adjusted_p<-adjusted[[i]]
  gates <- metrics$n >= 300 && metrics$positive >= 50 && (metrics$n - metrics$positive) >= 50 &&
    is.finite(metrics$auc) && metrics$brier < baseline_brier && metrics$ece <= .10 && result$calibration[2] > 0
  if (approve) assert(!identical(records[[1]]$target,"mutual_second_date_interest"), "Relationship-outcome models are evaluation-only; they cannot activate as directional like predictors.")
  if (approve) assert(gates, "Pilot approval gates failed; inspect the evaluation report.")
  if (approve) assert(length(supported_modes) > 0, "No connection mode has enough held-out outcomes for a pilot.")
  list(status = if (approve) "approved_for_pilot" else "evaluation_only", version = format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC"),
    target = if(identical(records[[1]]$target,"mutual_second_date_interest")) "P(mutual second-date interest among consented reported meetings)" else "P(actor requests a connection after a logged view, conditional on mode)", feature_names = FEATURE_NAMES,
    registry_signature = registry_signature(registry), fit = result$fit, calibration = result$calibration,
    metrics = metrics, mode_metrics = mode_metrics, supported_modes = supported_modes, ablations = ablations, pilot_gates_passed = gates, trained_at = now_utc())
}
