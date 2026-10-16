brand_mark <- function(class = "", animated = FALSE) {
  path <- file.path(getOption("soulmatch.www_dir", "www"), "brand", "soulmatch-icon.svg")
  svg <- paste(readLines(path, warn = FALSE), collapse = "")
  svg <- sub('<svg ', paste0('<svg class="brand-mark ', class, if (animated) ' spark-animate' else '', '" width="32" height="44" '), svg, fixed = TRUE)
  HTML(svg)
}
brand_logo <- function(dark = FALSE, class = "") tags$img(class = paste("soulmatch-logo", class), src = paste0("brand/soulmatch-logo-", if (dark) "dark" else "primary", ".svg"), width = "220", height = "62", alt = "SoulMatch — meaningful connections begin with a spark")
brand_moment <- function(label = "YOUR NEXT CHAPTER") tags$div(class = "brand-moment", brand_mark(), tags$span(label))
