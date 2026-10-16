# Run only as the database operator. Excludes raw answers, message content,
# safety feedback, demo accounts and non-consenting participants.
for(f in c("utils","v1_services","migrations","database","questionnaires","interests_data","interest_features","matching"))source(file.path("R",paste0(f,".R")))
args<-commandArgs(trailingOnly=TRUE);assert(length(args)==1,"Usage: Rscript scripts/export_outcomes.R /private/path/outcomes.jsonl")
con<-open_db(resolve_db_path(Sys.getenv("SOULMATCH_DATA_DIR","data")));records<-export_relationship_training(con,load_registry());DBI::dbDisconnect(con)
assert(length(records)>0,"No eligible consented non-demo pairs with two feedback forms and an earlier consented impression.")
writeLines(vapply(records,to_json,""),args[1],useBytes=TRUE);Sys.chmod(args[1],"0600")
message("Exported ",length(records)," pseudonymous pair outcomes. Keep this file private.")
