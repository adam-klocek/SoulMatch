# Adapted 2026 from Hynek Cígler (2019), Height-questionnaire (GPL-3.0).
# Original items: Karel Rečka (2018); short-form selection: Martin Tancoš (2019).
# Original Czech source and full GPL license are in third_party/height/.
load_height_definition <- function(path = getOption("soulmatch.height_file", "config/height.json")) from_json(paste(readLines(path, warn = FALSE), collapse = "\n"))
score_height <- function(answers, reference = "none") {
  ids <- paste0("p", 1:11); values <- suppressWarnings(as.numeric(unlist(answers[ids], use.names = FALSE)))
  assert(length(values) == 11 && all(is.finite(values)) && all(values %in% 0:3), "Please answer all 11 height-story questions before completing it.")
  assert(reference %in% c("none", "men", "women"), "Choose one of the original reference samples, or no estimate.")
  raw <- 18 + sum(values[1:5]) - sum(values[6:11])
  estimate <- lower <- upper <- NA_real_
  if (reference != "none") {
    intercept <- if (reference == "men") 161.22621 else 155.8392013
    slope <- if (reference == "men") 1.04240 else .8456295
    sd <- if (reference == "men") 7.56 else 7.03
    validity <- if (reference == "men") .8643642 else .8895554
    estimate <- intercept + slope * raw
    interval <- estimate + c(-1, 1) * stats::qnorm(.975) * sd * sqrt(1 - validity^2)
    lower <- interval[1]; upper <- interval[2]
  }
  list(raw_score = raw, estimate_cm = estimate, lower_cm = lower, upper_cm = upper)
}
save_height <- function(con, user, answers, reference = "none", allow_matching = FALSE) {
  assert(!is.null(get_profile(con, user)), "Save your profile first.")
  result <- score_height(answers, reference)
  allow <- isTRUE(allow_matching) && reference != "none"
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "INSERT INTO height_responses VALUES(?,?,?,?,?,?,?,?,?,?,?)", params = list(new_id(), user, "1.0.0", to_json(answers[paste0("p", 1:11)]), reference, result$raw_score, result$estimate_cm, result$lower_cm, result$upper_cm, as.integer(allow), now_utc()))
    DBI::dbExecute(con, "UPDATE profiles SET height=?,updated_at=? WHERE user_id=?", params = list(if (allow) result$estimate_cm else NA_real_, now_utc(), user))
    DBI::dbExecute(con, "DELETE FROM response_drafts WHERE user_id=? AND instrument_id='brno_height11'", params = list(user))
  })
  result
}
heightModuleUI <- function(id) {
  ns <- NS(id)
  tags$div(class = "height-layout", panel("Your height story", pill("OPTIONAL · 11 QUESTIONS", "lavender"), tags$p("No measuring tape needed. Tell us about a few everyday experiences."),
    tags$p(class = "fine-print", "Adapted from the Brno educational height questionnaire. Estimates are uncertain and are not a verified measurement. You can skip this entirely."), uiOutput(ns("form")),
    tags$div(class = "wizard-actions", actionButton(ns("save_draft"), "Save for later", class = "btn-outline-primary"), actionButton(ns("complete"), "Save my height story", class = "btn-primary"))),
    tags$aside(panel("A little context", tags$p("The original study used separate men’s and women’s reference samples, primarily young Czech adults. It provides no nonbinary-specific norms. Gender identity does not automatically select a reference."), tags$p("Choose no estimate if neither original reference fits. Raw scores are private and are never compared across genders or used to rank you."), tags$p("The English wording is a new, unvalidated translation; the original Czech wording is also available."), tags$a(href = "https://fssvm6.fss.muni.cz/vyska/", target = "_blank", rel = "noopener noreferrer", "Read about the original questionnaire ↗")), uiOutput(ns("result"))))
}
heightModuleServer <- function(id, con, user, on_saved = function() NULL) {
  moduleServer(id, function(input, output, session) {
    definition <- load_height_definition(); loaded <- reactiveVal(list()); revision <- reactiveVal(0L)
    observeEvent(user(), {
      req(user())
      row <- DBI::dbGetQuery(con, "SELECT * FROM height_responses WHERE user_id=? ORDER BY created_at DESC,id DESC LIMIT 1", params = list(user()))
      state <- if (nrow(row)) c(from_json(row$answers[1]), list(reference = row$reference_group[1], allow = as.logical(row$allow_matching[1]))) else list()
      draft <- DBI::dbGetQuery(con, "SELECT answers FROM response_drafts WHERE user_id=? AND instrument_id='brno_height11' AND version='1.0.0'", params = list(user()))
      if (nrow(draft)) state <- modifyList(state, from_json(draft$answers[1]))
      loaded(state)
    }, ignoreNULL = TRUE)
    output$form <- renderUI({
      req(user()); state <- loaded(); ns <- session$ns
      tagList(selectInput(ns("language"), "Question wording", c("English (experimental translation)" = "en", "Čeština (original)" = "cs"), "en"),
        lapply(definition$items, function(item) tags$div(class = "height-question", tags$p(class = "question-label", item$en), tags$p(class = "czech-item", lang = "cs", item$cs), radioButtons(ns(item$id), label = NULL, choices = c("Strongly disagree" = "0", "Disagree" = "1", "Agree" = "2", "Strongly agree" = "3"), selected = if (!is.null(state[[item$id]])) as.character(state[[item$id]]) else character(), inline = TRUE))),
        selectInput(ns("reference"), "Optional reference for a private estimate", c("No centimetre estimate" = "none", "Original men’s reference sample" = "men", "Original women’s reference sample" = "women"), state$reference %||% "none"),
        checkboxInput(ns("allow"), "Use and show my approximate height estimate in discovery (optional)", isTRUE(state$allow)), tags$p(class = "fine-print", "Your choice. Estimates can contribute only to soft height preferences; they never exclude someone. No estimate is used without this permission."))
    })
    observeEvent(input$language, {
      session$sendCustomMessage("heightLanguage", list(id = session$ns("form"), language = input$language))
    })
    answers <- function() setNames(lapply(paste0("p", 1:11), function(id) { value <- input[[id]]; if (is.null(value) || !nzchar(value)) NULL else as.numeric(value) }), paste0("p", 1:11))
    safely <- function(code) tryCatch(force(code), error = function(e) showNotification(conditionMessage(e), type = "error"))
    observeEvent(input$save_draft, safely({
      req(user()); values <- answers(); values <- values[!vapply(values, is.null, TRUE)]
      values$reference <- input$reference %||% "none"; values$allow <- isTRUE(input$allow)
      DBI::dbExecute(con, "INSERT INTO response_drafts VALUES(?,?,?,?,?,?) ON CONFLICT(user_id,instrument_id,version) DO UPDATE SET answers=excluded.answers,updated_at=excluded.updated_at", params = list(user(), "brno_height11", "1.0.0", to_json(values), 1L, now_utc()))
      showNotification("Your height story is saved for later.", type = "message")
    }))
    observeEvent(input$complete, safely({
      req(user()); save_height(con, user(), answers(), input$reference %||% "none", isTRUE(input$allow))
      revision(isolate(revision()) + 1L); on_saved(); showNotification("Your height story is saved.", type = "message")
    }))
    output$result <- renderUI({
      req(user()); revision()
      r <- DBI::dbGetQuery(con, "SELECT * FROM height_responses WHERE user_id=? ORDER BY created_at DESC,id DESC LIMIT 1", params = list(user()))
      if (!nrow(r)) return(panel("Just for you", tags$p("Your private result appears here when you complete the questionnaire.")))
      panel("Your private result", pill("EDUCATIONAL ESTIMATE", "lavender"), tags$p(paste("Questionnaire score:", r$raw_score[1], "of 33")),
        if (!is.na(r$estimate_cm[1])) tagList(tags$div(class = "height-estimate", paste0(round(r$estimate_cm[1]), " cm")), tags$p(sprintf("Approximate 95%% prediction interval: %.0f–%.0f cm", r$lower_cm[1], r$upper_cm[1])), tags$p(class = "fine-print", paste("Original reference:", r$reference_group[1], "·", if (r$allow_matching[1] == 1) "Enabled for soft preferences" else "Private; not used in matching"))) else tags$p("No centimetre estimate requested. Your raw score stays private and is excluded from matching."))
    })
  })
}
