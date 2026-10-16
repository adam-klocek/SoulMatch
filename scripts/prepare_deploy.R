# Run in a normal CRAN-based development environment, not during app startup.
assert <- function(ok,message)if(!isTRUE(ok))stop(message,call.=FALSE)
assert(file.exists("app.R"),"Run from the application directory.")
assert(requireNamespace("rsconnect",quietly=TRUE),"Install rsconnect first: install.packages('rsconnect')")
rsconnect::writeManifest(appDir=".")
message("Review manifest.json and the deployment file list before committing. Runtime data/secrets must remain excluded. Persistent remote storage is still required for a real cloud pilot.")
