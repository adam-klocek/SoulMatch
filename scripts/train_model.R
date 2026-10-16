for (f in c("utils", "questionnaires", "interest_features", "matching", "learning")) source(file.path("R", paste0(f, ".R")))
args <- commandArgs(trailingOnly = TRUE)
assert(length(args) >= 2, "Usage: Rscript scripts/train_model.R decisions.jsonl output.rds [--approve-for-pilot]")
records <- lapply(readLines(args[1], warn = FALSE), from_json)
model <- train_like_model(records, load_registry(), approve = "--approve-for-pilot" %in% args)
saveRDS(model, args[2]); Sys.chmod(args[2], "0600")
report <- model[setdiff(names(model), c("fit"))]
writeLines(jsonlite::toJSON(report, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"), paste0(args[2], ".report.json"))
message("Saved ", model$status, " model and held-out evaluation report.")
