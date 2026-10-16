# Database-operator CLI. There is no self-service administrator signup.
for(f in c("utils","v1_services","migrations","database","questionnaires","interests_data","interest_features","matching"))source(file.path("R",paste0(f,".R")))
args<-commandArgs(trailingOnly=TRUE)
assert(length(args)>=2,"Usage: Rscript scripts/admin.R role USERNAME admin|member; or experiment ADMIN_USERNAME ID love|friends ALGORITHM_A ALGORITHM_B; or stop-experiment ADMIN_USERNAME ID")
con<-open_db(resolve_db_path(Sys.getenv("SOULMATCH_DATA_DIR","data")))
row<-DBI::dbGetQuery(con,"SELECT id FROM users WHERE username=?",params=list(tolower(args[2])));assert(nrow(row)==1,"Account not found.");actor<-row$id[[1]]
if(args[1]=="role"){
  assert(length(args)==3&&args[3]%in%c("admin","member"),"Choose admin or member.")
  DBI::dbExecute(con,"UPDATE users SET role=? WHERE id=?",params=list(args[3],actor));audit_event(con,actor,"operator_role_assignment",actor,list(role=args[3]))
} else if(args[1]=="experiment"){
  assert(length(args)>=6,"Provide experiment ID, mode and two algorithm IDs.")
  algorithms<-algorithm_registry(load_registry());registered_algorithms(con,algorithms);create_matching_experiment(con,actor,args[3],args[4],args[5:length(args)],algorithms)
} else if(args[1]=="stop-experiment"){
  require_admin(con,actor);assert(length(args)==3,"Provide experiment ID.");DBI::dbExecute(con,"UPDATE matching_experiments SET enabled=0 WHERE id=?",params=list(args[3]));audit_event(con,actor,"experiment_stopped",details=list(id=args[3]))
} else stop("Unknown operation.")
DBI::dbDisconnect(con);message("Operator action recorded.")
