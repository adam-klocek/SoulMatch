# Dry-run by default. Retains accounts/history unless the operator sets a policy.
for(f in c("utils","v1_services","migrations","database"))source(file.path("R",paste0(f,".R")))
args<-commandArgs(trailingOnly=TRUE);con<-open_db(resolve_db_path(Sys.getenv("SOULMATCH_DATA_DIR","data")))
cutoff<-format(Sys.time()-86400,"%Y-%m-%dT%H:%M:%OS6Z",tz="UTC")
n<-DBI::dbGetQuery(con,"SELECT COUNT(*) AS n FROM rate_limit_events WHERE created_at<?",params=list(cutoff))$n[[1]]
message("Expired rate-limit events: ",n)
if("--apply"%in%args)DBI::dbExecute(con,"DELETE FROM rate_limit_events WHERE created_at<?",params=list(cutoff))
DBI::dbDisconnect(con)
