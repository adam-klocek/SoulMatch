IMPORTANCE_LABELS <- c("Not important at all", "Slightly important", "Moderately important", "Very important", "Essential")
optional_choices <- function(labels) c("Leave unanswered" = "", setNames(as.character(seq_along(labels)), labels))
interestCategoryUI <- function(id) uiOutput(NS(id)("form"))
interestCategoryServer <- function(id, catalog, loaded) moduleServer(id, function(input, output, session) {
  output$form <- renderUI({
    state <- loaded()
    tags$div(class = "category-chips", checkboxGroupInput(session$ns("categories"), "Which parts of life light you up?", setNames(catalog$categories$id, catalog$categories$label), state$categories), tags$p(class = "fine-print", "Choose a few broad areas, or skip this step. You can always come back."))
  })
  outputOptions(output, "form", suspendWhenHidden = FALSE)
  reactive(input$categories %||% character())
})
interestChipUI <- function(id) uiOutput(NS(id)("form"))
interestChipServer <- function(id, catalog, categories, loaded) moduleServer(id, function(input, output, session) {
  output$form <- renderUI({
    state <- loaded(); ns <- session$ns
    tagList(tags$div(class = "interest-search", `data-search-target` = ns("grid"), textInput(ns("search"), "Find an interest", placeholder = "Try hiking, jazz, or coffee…")),
      tags$p(class = "fine-print", "Around 5–10 is a nice starting point. More or fewer is equally welcome."),
      tags$div(id = ns("grid"), lapply(seq_len(nrow(catalog$categories)), function(i) {
        cat <- catalog$categories[i, ]; options <- catalog$interests[catalog$interests$category_id == cat$id, ]
        tags$details(class = "interest-category", open = TRUE, `data-category-id` = cat$id, tags$summary(cat$label),
          tags$div(class = "interest-chips", checkboxGroupInput(ns(paste0("chips_", cat$id)), NULL, setNames(options$id, options$label), intersect(state$selected, options$id))))
      })), textInput(ns("custom"), "Something missing? Suggest an interest (optional)", state$custom, placeholder = "Up to 300 characters; suggestions aren't automatically added to matching."))
  })
  observe({
    session$sendCustomMessage("interestCategories", list(id = session$ns("grid"), selected = as.list(categories())))
  })
  outputOptions(output, "form", suspendWhenHidden = FALSE)
  list(selected = reactive({
    cats <- categories(); valid <- catalog$interests$id[catalog$interests$category_id %in% cats]
    values <- unlist(lapply(catalog$categories$id, function(id) input[[paste0("chips_", id)]]), use.names = FALSE)
    intersect(values, valid)
  }), custom = reactive(input$custom %||% loaded()$custom))
})
interestDetailsUI <- function(id) uiOutput(NS(id)("form"))
interestDetailsServer <- function(id, catalog, selected, loaded) moduleServer(id, function(input, output, session) {
  output$form <- renderUI({
    ids <- selected(); saved <- loaded()$details; ns <- session$ns
    if (!length(ids)) return(empty_state("Make it yours, at your own pace", "No interests selected. Go back to choose some, or continue without these optional details."))
    tagList(tags$p(class = "fine-print", "Enjoyment, frequency, and wanting to share are different things. Every follow-up is optional."),
      lapply(ids, function(id) {
        current <- function(key) isolate(input[[paste0(key, "_", id)]]) %||% saved[[id]][[key]] %||% ""
        tags$div(class = "interest-detail-card", tags$h4(interest_labels(id, catalog)), tags$div(class = "three-responses",
          selectInput(ns(paste0("enjoyment_", id)), "How much do you enjoy it?", optional_choices(c("Not very much", "A little", "Moderately", "Quite a lot", "Extremely")), current("enjoyment")),
          selectInput(ns(paste0("frequency_", id)), "How often do you do it?", optional_choices(c("Rarely or never", "A few times per year", "Monthly", "Weekly", "Several times per week")), current("frequency")),
          selectInput(ns(paste0("importance_", id)), "How important is sharing it?", optional_choices(IMPORTANCE_LABELS), current("importance"))))
      }))
  })
  outputOptions(output, "form", suspendWhenHidden = FALSE)
  reactive({
    ids <- selected(); saved <- loaded()$details
    setNames(lapply(ids, function(id) setNames(lapply(c("enjoyment", "frequency", "importance"), function(key) optional_rating(input[[paste0(key, "_", id)]] %||% saved[[id]][[key]])), c("enjoyment", "frequency", "importance"))), ids)
  })
})
lifestyleUI <- function(id) uiOutput(NS(id)("form"))
lifestyleServer <- function(id, catalog, loaded) moduleServer(id, function(input, output, session) {
  output$form <- renderUI({
    state <- loaded(); ns <- session$ns
    lapply(catalog$definition$lifestyle, function(q) tags$div(class = "lifestyle-card", tags$div(
      selectInput(ns(q$id), q$prompt, c("Leave unanswered" = "", setNames(vapply(q$options, `[[`, "", "value"), vapply(q$options, `[[`, "", "label"))), state$lifestyle[[q$id]] %||% "")),
      selectInput(ns(paste0("importance_", q$id)), "How important is matching this with someone?", optional_choices(IMPORTANCE_LABELS), state$lifestyle_importance[[q$id]] %||% "")))
  })
  outputOptions(output, "form", suspendWhenHidden = FALSE)
  list(values = reactive(setNames(lapply(catalog$definition$lifestyle, function(q) input[[q$id]] %||% loaded()$lifestyle[[q$id]] %||% ""), vapply(catalog$definition$lifestyle, `[[`, "", "id"))),
    importance = reactive(setNames(lapply(catalog$definition$lifestyle, function(q) optional_rating(input[[paste0("importance_", q$id)]] %||% loaded()$lifestyle_importance[[q$id]])), vapply(catalog$definition$lifestyle, `[[`, "", "id"))))
})
sharedActivitiesUI <- function(id) uiOutput(NS(id)("form"))
sharedActivitiesServer <- function(id, catalog, selected, loaded) moduleServer(id, function(input, output, session) {
  chosen <- reactiveVal(NULL)
  observeEvent(loaded(), chosen(NULL))
  observeEvent(input$activities, chosen(input$activities %||% character()), ignoreInit = TRUE, ignoreNULL = FALSE)
  choices <- reactive(c(setNames(vapply(catalog$definition$shared_activities, `[[`, "", "id"), vapply(catalog$definition$shared_activities, `[[`, "", "label")), setNames(paste0("interest:", selected()), interest_labels(selected(), catalog))))
  output$form <- renderUI({
    saved <- loaded(); ns <- session$ns
    prior <- isolate(chosen()); if (is.null(prior)) prior <- names(saved$shared)
    tagList(tags$div(class = "interest-chips", checkboxGroupInput(ns("activities"), "What would you love to do together?", choices(), intersect(prior, unname(choices())))), tags$p(class = "fine-print", "Think about a romantic partner or a new friend. Shared activities help either kind of connection."), uiOutput(ns("importance")))
  })
  output$importance <- renderUI({
    ids <- input$activities %||% character(); ids <- intersect(ids, unname(choices()))
    lapply(ids, function(activity) selectInput(session$ns(paste0("shared_", gsub(":", "_", activity))), names(choices())[match(activity, choices())], optional_choices(c("Nice to have", "Important", "Essential")), isolate(input[[paste0("shared_", gsub(":", "_", activity))]]) %||% loaded()$shared[[activity]] %||% ""))
  })
  outputOptions(output, "form", suspendWhenHidden = FALSE)
  outputOptions(output, "importance", suspendWhenHidden = FALSE)
  reactive({
    ids <- input$activities %||% character(); ids <- intersect(ids, unname(choices()))
    setNames(lapply(ids, function(activity) optional_rating(input[[paste0("shared_", gsub(":", "_", activity))]] %||% loaded()$shared[[activity]], 3)), ids)
  })
})
interestsModuleUI <- function(id) {
  ns <- NS(id)
  panel("A life someone could step into", tags$div(class = "wizard-top", pill("INTERESTS & LIFESTYLE", "lavender"), tags$span("Optional · save and return any time")), uiOutput(ns("progress")),
    tags$div(style = "display:none", textOutput(ns("step_value"))),
    conditionalPanel(sprintf("output['%s'] === '1'", ns("step_value")), interestCategoryUI(ns("categories"))),
    conditionalPanel(sprintf("output['%s'] === '2'", ns("step_value")), interestChipUI(ns("chips"))),
    conditionalPanel(sprintf("output['%s'] === '3'", ns("step_value")), interestDetailsUI(ns("details"))),
    conditionalPanel(sprintf("output['%s'] === '4'", ns("step_value")), lifestyleUI(ns("lifestyle"))),
    conditionalPanel(sprintf("output['%s'] === '5'", ns("step_value")), sharedActivitiesUI(ns("shared"))),
    conditionalPanel(sprintf("output['%s'] === '6'", ns("step_value")), uiOutput(ns("review"))),
    tags$div(class = "wizard-actions", actionButton(ns("back"), "← Back", class = "btn-outline-primary"), actionButton(ns("save_later"), "Save for later", class = "btn-outline-primary"), actionButton(ns("next_step"), "Save & continue →", class = "btn-primary")), uiOutput(ns("saved_note")))
}
interestsModuleServer <- function(id, con, user, catalog, on_saved = function() NULL, on_exit = function() NULL) {
  moduleServer(id, function(input, output, session) {
    loaded <- reactiveVal(empty_interest_state()); step <- reactiveVal(1L); active_session <- reactiveVal(NULL); saved_at <- reactiveVal(NULL)
    categories <- interestCategoryServer("categories", catalog, loaded)
    chips <- interestChipServer("chips", catalog, categories, loaded)
    details <- interestDetailsServer("details", catalog, chips$selected, loaded)
    lifestyle <- lifestyleServer("lifestyle", catalog, loaded)
    shared <- sharedActivitiesServer("shared", catalog, chips$selected, loaded)
    observeEvent(user(), {
      req(user()); state <- read_interest_state(con, user(), catalog)
      loaded(state); step(state$step); active_session(state$session_id)

    }, ignoreNULL = TRUE)
    state <- reactive(list(categories = categories(), selected = chips$selected(), details = details(), lifestyle = lifestyle$values(), lifestyle_importance = lifestyle$importance(), shared = shared(), custom = chips$custom(), step = step(), session_id = active_session()))
    persist <- function(complete = FALSE, next_page = step()) {
      req(user()); assert(!is.null(get_profile(con, user())), "Save your profile first.")
      snapshot <- state(); snapshot$step <- next_page
      saved <- save_interest_state(con, user(), snapshot, catalog, complete)
      active_session(saved$session_id); saved_at(format(Sys.time(), "%H:%M")); on_saved()
      invisible(saved)
    }
    output$step_value <- renderText(as.character(step()))
    outputOptions(output, "step_value", suspendWhenHidden = FALSE)
    safely <- function(code) tryCatch(force(code), error = function(e) showNotification(conditionMessage(e), type = "error"))
    observeEvent(input$next_step, safely({
      if (step() < 6) { next_page <- step() + 1L; persist(next_page = next_page); step(next_page) }
      else { persist(TRUE); on_exit(); showNotification("Your interests and lifestyle are saved. Make room for a connection.", type = "message") }
    }))
    go_back <- function() {
      next_page <- max(1L, step() - 1L)
      # Draft saving must not turn Back into a dead end. Completion validation
      # belongs to Continue; all visited controls stay mounted while navigating.
      safely(persist(next_page = next_page))
      if (step() == 1L) on_exit() else step(next_page)
    }
    observeEvent(input$back, go_back())
    observeEvent(input$save_later, safely({ persist(); showNotification("Progress saved. You can return whenever you like.", type = "message") }))
    output$progress <- renderUI({
      labels <- c("Your worlds", "Your interests", "A little deeper", "Everyday life", "Together", "Your story")
      tags$div(class = "journey-progress", tags$div(class = "progress-caption", tags$b(labels[step()]), tags$span(paste("Step", step(), "of 6"))),
        tags$div(class = "progress-track", role = "progressbar", `aria-valuenow` = step(), `aria-valuemin` = "1", `aria-valuemax` = "6", `aria-label` = "Interest questionnaire progress", tags$div(style = paste0("width:", round(step() / 6 * 100), "%"))))
    })
    output$review <- renderUI({
      current <- state(); labels <- interest_labels(current$selected, catalog)
      tagList(tags$h3("A few things that make you, you."), tags$div(class = "tag-row", lapply(labels, pill, class = "coral")),
        tags$p(paste(length(labels), "interests ·", sum(vapply(current$lifestyle, function(x) length(x) == 1 && nzchar(x), TRUE)), "lifestyle reflections ·", length(current$shared), "things to share")),
        tags$p("You can enjoy an interest without needing someone else to share it. Your answers keep those two things separate."),
        tags$p(class = "fine-print", "Unanswered follow-ups remain missing. These optional features inform experimental suggestions; they do not establish relationship success."))
    })
    output$saved_note <- renderUI(if (!is.null(saved_at())) tags$p(class = "saved-note", role = "status", paste("✓ Saved at", saved_at())))
    list(state = state, step = step, persist = persist, go_back = go_back)
  })
}
