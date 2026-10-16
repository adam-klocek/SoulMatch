for (f in c("utils", "v1_services", "questionnaires", "interest_features", "matching", "learning")) source(file.path("R", paste0(f, ".R")))
args <- commandArgs(trailingOnly = TRUE)
assert(length(args) >= 2, "Usage: Rscript scripts/train_model.R decisions.jsonl output.rds [--approve-for-pilot]")
records <- lapply(readLines(args[1], warn = FALSE), from_json)
model <- train_like_model(records, load_registry(), approve = "--approve-for-pilot" %in% args)
saveRDS(model, args[2]); Sys.chmod(args[2], "0600")
report <- model[setdiff(names(model), c("fit"))]
writeLines(jsonlite::toJSON(report, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"), paste0(args[2], ".report.json"))
message("Saved ", model$status, " model and held-out evaluation report.")
if ("--record-db" %in% args) {
  source("R/migrations.R"); source("R/database.R")
  con <- open_db(resolve_db_path(Sys.getenv("SOULMATCH_DATA_DIR", "data")))
  DBI::dbExecute(con,"INSERT INTO model_evaluation_results VALUES(?,?,?,?,?)",params=list(new_id(),model$version,model$registry_signature,to_json(report),now_utc()))
  DBI::dbDisconnect(con)
  message("Offline evaluation recorded for the administrator dashboard.")
}
