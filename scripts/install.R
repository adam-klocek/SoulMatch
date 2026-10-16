packages <- c("shiny", "bslib", "DBI", "RSQLite", "jsonlite", "sodium", "png", "jpeg", "testthat")
missing <- packages[!vapply(packages, requireNamespace, quietly = TRUE, FUN.VALUE = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Dependencies ready. Run shiny::runApp('.') from this project directory.")
