app_server <- function(input, output, session, db_path, photo_dir, questionnaires, algorithms, demo_mode) {
  con <- open_db(db_path)
  registered_algorithms(con, algorithms)
  session$onSessionEnded(function() DBI::dbDisconnect(con))
  user <- reactiveVal(NULL); revision <- reactiveVal(0L); candidate <- reactiveVal(NULL); impression <- reactiveVal(NULL)
  page <- reactiveVal(1L); drafts <- reactiveVal(list()); last_auth <- reactiveVal(as.POSIXct("2000-01-01", tz = "UTC"))
  connection_cache <- reactiveVal(character()); message_cache <- reactiveVal(data.frame()); preferred_chat <- reactiveVal(NULL); new_connection <- reactiveVal(NULL)
  bump <- function() revision(isolate(revision()) + 1L)
  attempt <- function(code) tryCatch(force(code), error = function(e) showNotification(conditionMessage(e), type = "error", duration = 7))
  pulse <- reactive({ invalidateLater(2000, session); Sys.time() })
  profile <- reactive({ req(user()); revision(); get_profile(con, user()) })
  current_mode <- reactive({ p <- profile(); req(!is.null(p)); if (input$discovery_mode %in% p$connection_modes && length(input$discovery_mode) == 1) input$discovery_mode else p$connection_modes[[1]] })
  mod_intentions_server("intentions",con,user,bump)
  mod_insights_server("insights",con,user,questionnaires,revision)
  mod_post_date_server("postdate",con,user,revision,bump)
  mod_admin_server("admin",con,user,questionnaires,algorithms,revision,bump)
  catalog <- load_interest_catalog()
  modules <- discovery_module_definitions(questionnaires)
  active_module <- reactiveVal("")
  selected_instrument <- reactiveVal(names(active_instruments(questionnaires))[[1]])
  world_cache <- reactiveVal(list())
  interest_module <- interestsModuleServer("interests", con, user, catalog, bump, function() active_module(""))
  heightModuleServer("height", con, user, function() { bump(); active_module("") })
  output$active_module_state <- renderText(active_module())
  outputOptions(output, "active_module_state", suspendWhenHidden = FALSE)
  open_module <- function(module) {
    if (module$kind == "reflection") selected_instrument(module$instrument)
    active_module(module$kind)
    updateTabsetPanel(session, "main_nav", selected = "questions")
    session$sendCustomMessage("moduleFocus", list())
  }
  for (module in modules) local({
    entry <- module
    observeEvent(input[[paste0("module_", entry$key)]], { req(user()); open_module(entry) })
  })
  output$discovery_modules <- renderUI({
    req(user()); revision()
    complete <- vapply(modules, function(m) module_completion(con, user(), m, questionnaires, catalog), TRUE)
    tagList(tags$div(class = "module-overview", tags$div(tags$h2("Your self-discovery collection"), tags$p("One introduction, five optional explorations. Start wherever you feel curious.")), tags$div(class = "collection-count", tags$b(sum(complete)), tags$span(paste("of", length(modules), "complete")))),
      tags$div(class = "module-grid", lapply(seq_along(modules), function(i) {
        m <- modules[[i]]; done <- complete[[i]]
        actionButton(paste0("module_", m$key), label = tagList(
          tags$div(class = "module-tile-top", tags$span(class = "module-symbol", sm_icon(m$icon)), tags$span(class = if (done) "module-check" else "module-number", if (done) "✓" else sprintf("%02d", i))),
          tags$h3(m$title), tags$p(m$description), tags$div(class = "module-tile-bottom", tags$span(m$meta), tags$b(if (done) "Completed · revisit ↗" else "Explore →"))),
          class = paste("module-tile", if (done) "is-complete" else ""), `aria-label` = paste(m$title, if (done) "completed, revisit" else "open module"))
      })))
  })
  output$active_module_title <- renderUI({
    req(active_module() != "")
    matches <- Filter(function(m) m$kind == active_module() && (m$kind != "reflection" || m$instrument == selected_instrument()), modules)
    tags$span(class = "module-current-label", if (length(matches)) matches[[1]]$title else "Your module")
  })
  observeEvent(input$back_to_modules, {
    req(user())
    if (active_module() == "reflection") attempt({ capture_page(FALSE); persist_q_draft() })
    if (active_module() == "interests") attempt(interest_module$persist())
    active_module("")
  })
  # Instrument input remains supported for existing integrations; the visible
  # interface selects instruments through module tiles.
  observeEvent(input$instrument, {
    if (input$instrument %in% names(active_instruments(questionnaires))) selected_instrument(input$instrument)
  })
  output$session_controls <- renderUI({
    if (is.null(user())) return(tags$span(class = "header-note", "For every kind of beginning."))
    tagList(tags$span(class = "header-note", "Your own pace. Your own choice."), actionButton("open_guide", "Our approach", class = "btn-sm btn-link"), actionButton("logout", "Sign out", class = "btn-sm btn-outline-primary"))
  })
  output$screen <- renderUI({
    if (is.null(user())) return(auth_ui(demo_mode))
    initial_tab <- if (is.null(get_profile(con, user()))) "profile" else if (!completed_required(con, user(), questionnaires)) "questions" else "discover"
    member_ui(algorithms, questionnaires, initial_tab)
  })
  check_auth_rate <- function() {
    assert(as.numeric(difftime(Sys.time(), isolate(last_auth()), units = "secs")) >= 2, "Please wait a moment before trying again.")
    rate_limit(con,tolower(input$username %||% ""),"authentication",10L,300L)
    last_auth(Sys.time())
  }
  observeEvent(input$login, attempt({
    check_auth_rate(); id <- authenticate(con, input$username %||% "", input$password %||% "")
    assert(!is.null(id), "Username or password is incorrect."); user(id)
  }))
  observeEvent(input$register, attempt({
    check_auth_rate(); assert(isTRUE(input$adult), "You must confirm that you are at least 18.")
    user(register_user(con, input$username %||% "", input$password %||% ""))
  }))
  observeEvent(input$logout, { user(NULL); active_module(""); world_cache(list()); candidate(NULL); impression(NULL); drafts(list()); page(1L); connection_cache(character()); message_cache(data.frame()); preferred_chat(NULL); new_connection(NULL); removeModal() })
  observeEvent(user(), {
    connection_cache(character()); message_cache(data.frame()); active_module(""); world_cache(list())
    req(user()); p <- get_profile(con, user())
    if (is.null(p)) updateTabsetPanel(session, "main_nav", selected = "profile")
    else if (!completed_required(con, user(), questionnaires)) updateTabsetPanel(session, "main_nav", selected = "questions")
  }, ignoreNULL = FALSE)
  for (event in c("open_interests", "profile_interests", "open_privacy", "open_guide", "start_profile", "start_questions")) local({
    id <- event; tab <- switch(id, open_interests = "questions", profile_interests = "questions", open_privacy = "privacy", open_guide = "methods", start_profile = "profile", start_questions = "questions")
    observeEvent(input[[id]], { req(user()); if (tab == "questions") active_module(""); updateTabsetPanel(session, "main_nav", selected = tab) })
  })
  observeEvent(input$open_height, { req(user()); open_module(Filter(function(m) m$kind == "height", modules)[[1]]) })
  output$welcome <- renderUI({
    p <- profile()
    tags$div(class = "welcome-line", tags$div(class = "welcome-greeting", brand_mark(), tags$span(class = "welcome-avatar", if (is.null(p)) "S" else substr(p$name, 1, 1)), tags$span(if (is.null(p)) "Welcome to your next beginning." else paste0("A little space for you, ", p$name, "."))), pill("THOUGHTFUL CONNECTIONS, EVERY DAY", "lavender"))
  })
  output$mode_picker <- renderUI({
    p <- profile(); req(!is.null(p)); prior <- isolate(input$discovery_mode)
    tags$div(class = "mode-picker", radioButtons("discovery_mode", "Your connection space", choices = setNames(p$connection_modes, ifelse(p$connection_modes == "love", "Love", "Friends")), selected = if (length(prior) == 1 && prior %in% p$connection_modes) prior else p$connection_modes[1], inline = TRUE))
  })
  output$mode_note <- renderUI({ if (current_mode() == "friends") tags$p("Friends · discover shared interests and everyday possibilities. Romantic preferences stay in Love.") else tags$p("Love · mutual romantic interest, your preferences, and room for the unexpected.") })
  output$journey_summary <- renderUI({
    req(user()); revision(); p <- get_profile(con, user()); interests <- read_interest_state(con, user(), catalog, TRUE)
    flags <- c("My introduction" = !is.null(p), "My personality" = completed_required(con, user(), questionnaires), "My interests & lifestyle" = !is.null(interests$session_id))
    lapply(names(flags), function(name) tags$div(class = "journey-row", tags$span(name), tags$span(class = if (flags[[name]]) "done" else "pending", if (flags[[name]]) "✓" else "Explore →")))
  })
  output$profile_editor <- renderUI(profile_editor_ui(profile()))
  observeEvent(input$save_profile, attempt({
    req(user()); prefs <- list(age = input$pref_age %||% DEFAULT_PREFS$age, height = input$pref_height %||% DEFAULT_PREFS$height, income = input$pref_income %||% character(), styles = input$pref_styles %||% character(), smoking = input$pref_smoking %||% "Any", goal = input$pref_goal %||% "Any")
    for (key in c("age", "income", "styles", "smoking", "goal")) prefs[[paste0("hard_", key)]] <- isTRUE(input[[paste0("hard_", key)]])
    save_profile(con, user(), list(name = input$p_name, age = input$p_age, gender = input$p_gender, interested = input$p_interested %||% character(), connection_modes = input$p_modes %||% character(), city = input$p_city, bio = input$p_bio, income = input$p_income %||% INCOMES[1], style = input$p_style, smoking = input$p_smoking, goal = input$p_goal, hobbies = input$p_hobbies %||% character(), preferences = prefs, consent = isTRUE(input$p_consent)))
    bump(); showNotification("Your story is saved.", type = "message")
    if (!completed_required(con, user(), questionnaires)) updateTabsetPanel(session, "main_nav", selected = "questions")
  }))
  output$my_photos <- renderUI({
    req(user()); revision(); photos <- DBI::dbGetQuery(con, "SELECT id,filename FROM photos WHERE user_id=? ORDER BY created_at", params = list(user()))
    if (!nrow(photos)) return(tags$p(class = "fine-print", "No photos yet. Add one whenever you feel ready."))
    previews <- lapply(seq_len(nrow(photos)), function(i) local({
      photo <- photos[i, ]; owner <- user(); output_id <- paste0("myphoto_", photo$id)
      output[[output_id]] <- renderImage({
        req(user()); assert(identical(user(), owner), "Sign in again.")
        row <- DBI::dbGetQuery(con, "SELECT filename FROM photos WHERE id=? AND user_id=?", params = list(photo$id, user()))
        req(nrow(row)); path <- file.path(photo_dir, basename(row$filename[1])); req(file.exists(path))
        list(src = path, contentType = "image/png", alt = paste("My photo", i))
      }, deleteFile = FALSE)
      tags$div(class = "my-photo", imageOutput(output_id, height = "110px"), pill(if (i == 1) "Main photo" else paste("Photo", i)))
    }))
    tagList(previews, selectInput("delete_photo_id", "Photo to remove", setNames(photos$id, paste("Photo", seq_len(nrow(photos))))), actionButton("delete_photo", "Remove photo", class = "btn-outline-secondary"))
  })
  observeEvent(input$upload_photo, attempt({ req(user()); assert(!is.null(get_profile(con, user())), "Save your profile first."); save_photo(con, user(), input$photo_upload, photo_dir); bump(); showNotification("Your photo is added.", type = "message") }))
  observeEvent(input$delete_photo, attempt({
    req(user(), input$delete_photo_id); row <- DBI::dbGetQuery(con, "SELECT filename FROM photos WHERE id=? AND user_id=?", params = list(input$delete_photo_id, user()))
    assert(nrow(row) == 1, "Photo unavailable."); DBI::dbExecute(con, "DELETE FROM photos WHERE id=? AND user_id=?", params = list(input$delete_photo_id, user()))
    unlink(file.path(photo_dir, basename(row$filename[1]))); bump()
  }))
  current_q <- reactive({ req(selected_instrument()); q <- questionnaires[[selected_instrument()]]; req(isTRUE(q$enabled)); q })
  q_page_size <- function(q) as.integer(q$page_size %||% 5L)
  load_q_answers <- function(q) {
    saved <- DBI::dbGetQuery(con, "SELECT answers FROM responses WHERE user_id=? AND instrument_id=? AND version=?", params = list(user(), q$id, q$version))
    answers <- if (nrow(saved)) from_json(saved$answers[1]) else list()
    saved_draft <- DBI::dbGetQuery(con, "SELECT answers FROM response_drafts WHERE user_id=? AND instrument_id=? AND version=?", params = list(user(), q$id, q$version))
    if (nrow(saved_draft)) answers <- modifyList(answers, from_json(saved_draft$answers[1]))
    modifyList(answers, isolate(drafts())[[paste(q$id, q$version, sep = "@")]] %||% list())
  }
  observeEvent(list(user(), selected_instrument()), {
    req(user()); q <- current_q(); row <- DBI::dbGetQuery(con, "SELECT page FROM response_drafts WHERE user_id=? AND instrument_id=? AND version=?", params = list(user(), q$id, q$version))
    page(if (nrow(row)) max(1L, min(row$page[1], ceiling(q$item_count / q_page_size(q)))) else 1L)
  })
  output$question_form <- renderUI({
    req(user()); q <- current_q(); size <- q_page_size(q); answers <- load_q_answers(q)
    start <- (page() - 1L) * size + 1L; end <- min(page() * size, q$item_count)
    tagList(tags$h2(class = "reflection-title", q$label), pill(q$badge %||% "A MOMENT FOR YOU", "lavender"), tags$p(q$instructions),
      tags$div(class = "journey-progress", tags$div(class = "progress-caption", tags$span(if (isTRUE(q$required)) "Your short introduction" else "Optional reflection"), tags$span(paste("Page", page(), "of", ceiling(q$item_count / size)))), tags$div(class = "progress-track", tags$div(style = paste0("width:", round(end / q$item_count * 100), "%")))),
      lapply(seq(start, end), function(i) { item <- q$items[i, ]; tags$div(class = "question-item", radioButtons(paste0("answer_", item$id), paste0(i, ". ", item$text), choices = setNames(as.character(seq(q$scale_min, q$scale_max)), unlist(q$scale_labels)), selected = if (!is.null(answers[[item$id]])) as.character(answers[[item$id]]) else character(), inline = TRUE)) }))
  })
  capture_page <- function(require_all = TRUE) {
    q <- current_q(); size <- q_page_size(q); ids <- q$items$id[seq((page() - 1L) * size + 1L, min(page() * size, q$item_count))]
    answers <- lapply(ids, function(id) input[[paste0("answer_", id)]])
    valid <- vapply(answers, function(a) length(a) == 1 && !is.na(suppressWarnings(as.numeric(a))), TRUE)
    if (require_all) assert(all(valid), "Take a moment to answer each question on this page.")
    answers <- lapply(answers[valid], as.numeric); names(answers) <- ids[valid]
    d <- drafts(); d[[selected_instrument()]] <- modifyList(load_q_answers(q), answers); drafts(d)
  }
  persist_q_draft <- function() {
    q <- current_q()
    DBI::dbExecute(con, "INSERT INTO response_drafts VALUES(?,?,?,?,?,?) ON CONFLICT(user_id,instrument_id,version) DO UPDATE SET answers=excluded.answers,page=excluded.page,updated_at=excluded.updated_at", params = list(user(), q$id, q$version, to_json(drafts()[[selected_instrument()]] %||% list()), as.integer(page()), now_utc()))
  }
  observeEvent(input$save_question_draft, attempt({ req(user()); capture_page(FALSE); persist_q_draft(); showNotification("Saved for later. Come back at your own pace.", type = "message") }))
  observeEvent(input$save_question_page, attempt({
    req(user()); assert(!is.null(get_profile(con, user())), "Save your introduction in My profile first.")
    capture_page(); q <- current_q()
    if (page() < ceiling(q$item_count / q_page_size(q))) { page(page() + 1L); persist_q_draft() }
    else {
      save_answers(con, user(), q, load_q_answers(q)); bump(); showNotification("Your reflection is saved.", type = "message")
      active_module("")
    }
  }))
  observeEvent(input$previous_question_page, {
    req(user())
    attempt(capture_page(FALSE))
    if (page() > 1L) { page(page() - 1L); attempt(persist_q_draft()) }
    else { attempt(persist_q_draft()); active_module("") }
  })
  output$onboarding_notice <- renderUI({
    req(user()); revision()
    if (is.null(profile())) return(tags$div(class = "notice", "First, give us a little introduction.", actionButton("start_profile", "Create my profile →", class = "btn-primary")))
    if (!completed_required(con, user(), questionnaires)) return(tags$div(class = "notice", "Your 10-question personality introduction unlocks discovery. Everything else is optional.", actionButton("start_questions", "Get to know myself →", class = "btn-primary")))
    NULL
  })
  observe({pulse();if(!is.null(user()) && !user_active(con,user())) {user(NULL);candidate(NULL);message_cache(data.frame());showNotification("This account is unavailable. Contact the operator.",type="warning")}})
  output$algorithm_note <- renderUI({ req(input$algorithm); tags$p(algorithms[[input$algorithm]]$description) })
  observe({
    req(user()); mode <- current_mode()
    revision()
    enabled <- DBI::dbGetQuery(con,"SELECT id FROM matching_algorithms WHERE enabled=1")$id
    available <- Filter(function(a) a$id %in% enabled && (!isTRUE(a$learned) || mode %in% a$supported_modes), algorithms)
    selected <- isolate(input$algorithm)
    updateSelectInput(session, "algorithm", choices = setNames(names(available), vapply(available, `[[`, "", "label")), selected = if (length(selected) == 1 && selected %in% names(available)) selected else names(available)[[1]])
  })
  refresh_card <- function() {
    if (is.null(user()) || is.null(input$algorithm) || is.null(algorithms[[input$algorithm]])) { candidate(NULL); return(invisible(NULL)) }
    a <- get_profile(con, user()); if (is.null(a) || !completed_required(con, user(), questionnaires)) { candidate(NULL); return(invisible(NULL)) }
    mode <- current_mode(); algorithm <- algorithms[[input$algorithm]]
    if (isTRUE(algorithm$learned) && !(mode %in% algorithm$supported_modes)) { candidate(NULL); return(invisible(NULL)) }
    card <- daily_connection(con,user(),questionnaires,algorithms,algorithm,mode,isTRUE(input$explore),record_view=FALSE)
    if(is.null(card)){candidate(NULL);impression(NULL);return(invisible(NULL))}
    impression(card$impression_id);candidate(card)
  }
  observeEvent(list(user(), input$algorithm, input$explore, input$discovery_mode, revision()), refresh_card())
  observeEvent(input$refresh,attempt(refresh_card()))
  observeEvent(input$more_connections,attempt({req(user(),input$algorithm);rate_limit(con,user(),"additional_batch",10L,3600L)
    daily_connection(con,user(),questionnaires,algorithms,algorithms[[input$algorithm]],current_mode(),isTRUE(input$explore),more=TRUE,record_view=FALSE);bump()
  }))
  output$daily_status<-renderUI({req(user());revision();mode<-current_mode();day<-format(Sys.time(),"%Y-%m-%d",tz="Europe/Prague")
    n<-DBI::dbGetQuery(con,"SELECT COUNT(*) AS n FROM daily_connections d JOIN recommendation_batches b ON b.id=d.batch_id WHERE b.actor_id=? AND b.mode=? AND b.day_key=?",params=list(user(),mode,day))$n[[1]]
    tags$p(class="daily-status",paste("Your collection:",n,"introductions today. Save someone or explore more at your own pace."))
  })
  output$saved_picker<-renderUI({req(user());revision();mode<-current_mode();r<-DBI::dbGetQuery(con,"SELECT target_id FROM saved_connections WHERE actor_id=? AND mode=? ORDER BY created_at",params=list(user(),mode));choices<-character()
    for(id in r$target_id){p<-get_profile(con,id);if(eligible_pair(con,get_profile(con,user()),p,mode))choices[p$name]<-id}
    if(!length(choices))return(NULL)
    tags$div(class="saved-discovery",selectInput("saved_person","Saved for later",choices),actionButton("resume_saved","Revisit saved profile",class="btn-outline-primary full-width"))
  })
  observeEvent(input$save_candidate,attempt({req(user(),candidate());save_for_later(con,user(),candidate()$profile$user_id,current_mode());bump();showNotification("Saved for later. No interest request was sent.",type="message")}))
  observeEvent(input$resume_saved,attempt({req(user(),input$saved_person);mode<-current_mode();id<-input$saved_person
    saved<-DBI::dbGetQuery(con,"SELECT 1 FROM saved_connections WHERE actor_id=? AND target_id=? AND mode=?",params=list(user(),id,mode));assert(nrow(saved)==1,"Choose your own saved profile.")
    a<-get_profile(con,user());p<-get_profile(con,id);assert(eligible_pair(con,a,p,mode),"This profile is unavailable.")
    alg<-algorithms[[input$algorithm]];req(alg);x<-pair_features(con,a,p,questionnaires,mode=mode);imp<-log_impression(con,user(),id,alg,questionnaires,x,mode)
    candidate(list(profile=p,features=x,score=as.numeric(alg$score(x)),mode=mode,outside_preferences=preference_fit(a,p,mode)$score<1,explanations=match_explanations(con,a,p,mode),algorithm_id=alg$id));impression(imp)
  }))
  observeEvent(input$view_full_profile,attempt({req(user(),candidate());p<-get_profile(con,candidate()$profile$user_id);assert(eligible_pair(con,get_profile(con,user()),p,current_mode()),"Profile unavailable.");x<-member_context(con,p$user_id)
    showModal(modalDialog(title=paste0(p$name,", ",p$age),tags$p(paste(p$gender,p$city,sep=" · ")),tags$p(p$bio),tags$h4("Beyond the photo"),lapply(names(BEYOND_PROMPTS),function(key)if(nzchar(x$beyond[[key]]%||%""))tagList(tags$b(BEYOND_PROMPTS[[key]]),tags$p(x$beyond[[key]]))),tags$p(class="fine-print","These are shared profile prompts. Questionnaire answers are private."),easyClose=TRUE,footer=modalButton("Back to introduction")))
  }))
  output$candidate_card <- renderUI({
    req(user()); card <- candidate()
    if (is.null(profile()) || !completed_required(con, user(), questionnaires)) return(empty_state("Your story comes first.", "A short introduction and ten thoughtful questions. Then, a world of possibilities."))
    if(member_context(con,user())$availability=="paused") return(empty_state("You're taking a break.","Your profile is hidden from new discovery. Your existing mutual conversations remain available; return to My profile when you want new introductions."))
    if (is.null(card)) return(empty_state("A little room for what's next.", "You're all caught up in this space. New people and new possibilities will appear as the community grows."))
    mode <- card$mode %||% current_mode(); p <- get_profile(con, card$profile$user_id)
    if (is.null(p) || mode != current_mode() || !eligible_pair(con, get_profile(con, user()), p, mode)) return(empty_state("A new perspective is waiting.", "Refresh your suggestions to continue."))
    photo <- photo_path(con, user(), p$user_id, photo_dir, questionnaires); algorithm <- algorithms[[card$algorithm_id %||% input$algorithm]]
    if(!is.null(card$daily_id)) {
      imp <- serve_daily_card(con,user(),card,algorithm,questionnaires)
      if(!identical(isolate(impression()),imp)) impression(imp)
    }
    demo <- if (isTRUE(as.logical(p$is_demo))) switch(p$name, Maya = "female", Leo = "male", Alex = "nonbinary", NULL) else NULL
    interests <- read_interest_state(con, p$user_id, catalog, TRUE); labels <- interest_labels(interests$selected, catalog)
    if (!length(labels)) labels <- p$hobbies
    mini <- function(label, value) tags$div(class = "fit-mini", label, tags$b(paste0(round(value * 100), "/100")), tags$div(class = "mini-track", tags$i(style = paste0("width:", round(value * 100), "%"))))
    tags$article(class = "candidate-card", tags$div(class = "candidate-visual",
      if (!is.null(photo)) imageOutput("candidate_image", height = "345px") else if (!is.null(demo)) demo_portrait(demo, label = paste("AI-created fictional demo portrait for", p$name)) else tags$div(class = "portrait-placeholder", tags$span(toupper(substr(p$name, 1, 1))), tags$p("A PERSON WORTH GETTING TO KNOW")),
      tags$span(class = "visual-mode", if (mode == "love") "Open to love" else "Open to friendship"), if (!is.null(demo) && is.null(photo)) tags$span(class = "demo-photo-note", "FICTIONAL DEMO PORTRAIT"),
      tags$div(class = "visual-pill", if (card$outside_preferences) "A LITTLE OUTSIDE YOUR USUAL TYPE" else if (mode == "friends") "A LITTLE SOMETHING IN COMMON" else "A THOUGHTFUL INTRODUCTION")),
      tags$div(class = "candidate-body", tags$div(class="recommendation-reasons",lapply(card$explanations %||% character(),tags$p)), tags$div(class = "name-line", tags$h2(paste0(p$name, ", ", p$age)), tags$div(class = "points", tags$b(round(card$score * 100)), tags$small("fit / 100"))),
        tags$p(class = "muted", paste(p$gender, p$city, sep = " · ")), tags$p(p$bio), tags$div(class = "tag-row", lapply(head(labels, 6), pill)),
        if (mode == "love") tags$p(class = "fine-print", paste(c(p$goal, p$style, if (!is.na(p$height)) paste0("Approx. ", round(p$height), " cm · questionnaire estimate")), collapse = " · ")),
        tags$div(class = "fit-breakdown", tags$p(tags$b("A few reasons to be curious")), tags$div(class = "fit-bars", if (mode == "love") mini("Your preferences", card$features[["own_preferences"]]) else mini("Interests", card$features[["interest_overlap"]]), mini("Everyday life", card$features[["lifestyle_compatibility"]]), mini("Things to share", card$features[["shared_activity_potential"]])), tags$p(class = "fine-print", "Experimental fit points. Unanswered optional features use neutral placeholders; no score promises a connection.")),
        tags$div(class = "chance-note", tags$b(if (mode == "friends") "Friendship starts with mutual choice." else "The feeling has to be mutual."),
          tags$p("A fit score describes common ground. Attraction and chemistry are something you discover together.")),
        tags$div(class = "decision-row", actionButton("pass", "Maybe another time", class = "btn-outline-secondary"), actionButton("like", if (mode == "love") "I'd like to connect ↗" else "Let's be friends ↗", class = "btn-primary")), tags$div(class="secondary-decisions", actionButton("save_candidate","Save for later",class="btn-outline-primary"),actionButton("view_full_profile","View full profile",class="btn-outline-primary")),
        tags$details(tags$summary("Safety & control"), textInput("candidate_report_reason", "Reason for reporting"), actionButton("block_candidate", "Block", class = "btn-outline-secondary"), actionButton("report_candidate", "Report & block", class = "btn-outline-secondary"))))
  })
  output$candidate_image <- renderImage({ req(user(), candidate()); pulse(); path <- photo_path(con, user(), candidate()$profile$user_id, photo_dir, questionnaires); req(!is.null(path)); list(src = path, contentType = "image/png", alt = "Profile photo") }, deleteFile = FALSE)
  decide <- function(choice) {
    req(user(), candidate(), impression()); card <- candidate(); target <- card$profile$user_id; mode <- card$mode %||% current_mode()
    assert(mode == current_mode(), "Refresh before making this choice."); save_decision(con, user(), target, choice, impression(), questionnaires, mode)
    if (is_mutual(con, user(), target, mode)) {
      new_connection(list(target = target, mode = mode)); person <- get_profile(con, target); me <- get_profile(con, user())
      showModal(modalDialog(title = NULL, easyClose = TRUE, footer = NULL,
        tags$div(class = "match-celebration", pill(if (mode == "love") "A MUTUAL BEGINNING" else "A NEW FRIENDSHIP", if (mode == "love") "coral" else "lavender"), tags$div(class = "mutual-art", tags$span(substr(me$name, 1, 1)), tags$i("↔"), tags$span(substr(person$name, 1, 1))), tags$h2("It's mutual."), tags$p(paste("You and", person$name, "chose to connect. A little hello could be the start of something good.")), actionButton("open_new_chat", "Say a little hello →", class = "btn-primary full-width"), modalButton("Keep exploring"))))
    }
    bump()
  }
  observeEvent(input$like, attempt(decide("like"))); observeEvent(input$pass, attempt(decide("pass")))
  observeEvent(input$open_new_chat, { req(new_connection()); preferred_chat(paste(new_connection()$mode, new_connection()$target, sep = ":")); removeModal(); updateTabsetPanel(session, "main_nav", selected = "chat") })
  observe({
    pulse(); revision(); req(user())
    rows <- DBI::dbGetQuery(con, "SELECT target_id,mode FROM decisions WHERE actor_id=? AND decision='like'", params = list(user()))
    choices <- character()
    for (i in seq_len(nrow(rows))) if (is_mutual(con, user(), rows$target_id[i], rows$mode[i])) {
      label <- paste0(get_profile(con, rows$target_id[i])$name, " · ", if (rows$mode[i] == "love") "Love" else "Friends")
      choices[label] <- paste(rows$mode[i], rows$target_id[i], sep = ":")
    }
    if (!identical(choices, isolate(connection_cache()))) connection_cache(choices)
  })
  observe({
    pulse(); revision(); req(user())
    cards <- connection_summaries(con, user(), questionnaires, algorithms, catalog)
    if (!identical(cards, isolate(world_cache()))) world_cache(cards)
  })
  output$world_summary <- renderUI({
    req(user()); cards <- world_cache()
    n_mutual <- sum(vapply(cards, function(c) c$status == "mutual", TRUE))
    tags$div(class = "world-summary", tags$div(tags$b(length(cards)), tags$span("in your world")), tags$div(tags$b(n_mutual), tags$span("mutual connections")), tags$div(tags$b(length(cards) - n_mutual), tags$span("requests sent")))
  })
  output$world_cards <- renderUI({
    req(user()); cards <- world_cache()
    filter <- input$world_filter %||% "all"; mode_filter <- input$world_mode %||% "all"
    cards <- Filter(function(c) (filter == "all" || c$status == filter) && (mode_filter == "all" || c$mode == mode_filter), cards)
    if (!length(cards)) return(tags$div(class = "world-empty", empty_state("Make space for someone new.", "People you choose in Discover appear here. When they choose you too, a mutual badge and a conversation open."), actionButton("world_discover", "Discover people →", class = "btn-primary")))
    tags$div(class = "world-grid", lapply(cards, function(card) local({
      c <- card; key <- paste(c$mode, c$id, sep = ":"); photo_id <- paste0("world_photo_", c$mode, "_", gsub("[^A-Za-z0-9]", "", c$id))
      photo <- tryCatch(photo_path(con, user(), c$id, photo_dir, questionnaires), error = function(e) NULL)
      if (!is.null(photo)) output[[photo_id]] <- renderImage({
        req(user()); pulse()
        allowed <- connection_summaries(con, user(), questionnaires, algorithms, catalog)
        req(any(vapply(allowed, function(x) x$id == c$id && x$mode == c$mode, TRUE)))
        path <- photo_path(con, user(), c$id, photo_dir, questionnaires); req(!is.null(path))
        list(src = path, contentType = "image/png", alt = paste("Profile photo of", c$name))
      }, deleteFile = FALSE)
      tags$article(class = paste("world-card", c$status),
        tags$div(class = "world-card-head", tags$div(class = "world-photo", if (!is.null(photo)) imageOutput(photo_id, height = "112px") else if (!is.null(c$portrait)) demo_portrait(c$portrait) else tags$div(class = "world-initials", `aria-label` = "No profile photo yet", substr(c$name, 1, 1))),
          tags$div(class = "world-person", pill(if (c$mode == "love") "LOVE" else "FRIENDS", if (c$mode == "love") "coral" else "lavender"), tags$h2(paste0(c$name, ", ", c$age)), tags$p(paste(c$gender, c$city, sep = " · ")), tags$span(class = paste("connection-status", c$status), if (c$status == "mutual") "✓ Mutual interest" else "↗ Request sent"))),
        tags$div(class = "world-metrics", lapply(names(c$metrics), function(label) {
          value <- c$metrics[[label]]; available <- is.finite(value)
          tags$div(class = "world-metric", tags$div(tags$span(label), tags$b(if (available) paste0(round(value * 100), "/100") else if (c$mode == "friends" && grepl("preference", label)) "Not applied" else "Unavailable")),
            tags$div(class = paste("metric-track", if (!available) "is-missing"), if (available) tags$i(style = paste0("width:", round(value * 100), "%"))))
        })),
        tags$div(class = "world-card-footer", tags$span(if (c$status == "mutual") "You both chose this connection." else "Chat opens when interest is mutual."),
          if (c$status == "mutual") tags$button(type = "button", class = "btn btn-primary world-message", `data-world-chat` = key, paste("Message", c$name), sm_icon("arrow"))))
    })))
  })
  observeEvent(input$world_discover, updateTabsetPanel(session, "main_nav", selected = "discover"))
  observeEvent(input$world_chat, attempt({
    req(user()); key <- input$world_chat
    assert(length(key) == 1 && key %in% unname(connection_cache()), "Choose an active mutual connection.")
    preferred_chat(key); updateTabsetPanel(session, "main_nav", selected = "chat")
  }))
  connections <- reactive({ req(user()); connection_cache() })
  selected_chat <- reactive({
    req(user(), input$chat_person); value <- input$chat_person
    if (!grepl(":", value, fixed = TRUE)) value <- paste("love", value, sep = ":")
    assert(value %in% unname(connections()), "Choose an active connection.")
    parts <- strsplit(value, ":", fixed = TRUE)[[1]]; list(mode = parts[1], target = parts[2])
  })
  output$connection_picker <- renderUI({
    choices <- connections(); if (!length(choices)) return(tags$p("Your mutual connections will appear here. Love and Friends each have their own conversations."))
    previous <- isolate(input$chat_person); preferred <- preferred_chat()
    if (length(previous) == 1 && !grepl(":", previous, fixed = TRUE)) previous <- paste("love", previous, sep = ":")
    selected <- if (length(preferred) == 1 && preferred %in% choices) preferred else if (length(previous) == 1 && previous %in% choices) previous else choices[[1]]
    selectInput("chat_person", "Choose a connection", choices, selected)
  })
  output$chat_header <- renderUI({
    req(user()); choices <- connections()
    if (is.null(input$chat_person) || !length(choices)) return(tags$p("A thoughtful conversation is worth waiting for."))
    chat <- tryCatch(selected_chat(), error = function(e) NULL); if (is.null(chat)) return(NULL)
    tags$div(class = "chat-profile", tags$h3(get_profile(con, chat$target)$name), pill(if (chat$mode == "love") "MUTUAL · LOVE" else "MUTUAL · FRIENDS", if (chat$mode == "love") "coral" else "lavender"))
  })
  observe({
    pulse(); revision(); req(user()); choices <- connections()
    chat <- tryCatch(selected_chat(), error = function(e) NULL)
    messages <- if (!is.null(chat) && is_mutual(con, user(), chat$target, chat$mode)) read_messages(con, user(), chat$target, chat$mode) else data.frame()
    if (!identical(messages, isolate(message_cache()))) message_cache(messages)
  })
  output$messages <- renderUI({
    req(user()); messages <- message_cache(); chat <- tryCatch(selected_chat(), error = function(e) NULL)
    if (is.null(chat)) return(empty_state("A little hello goes a long way.", "Chat opens when you both choose a connection in the same space."))
    if (!nrow(messages)) return(tags$div(class = "message-list", tags$p(class = "muted", "Your conversation starts here. Ask about something you're both curious about.")))
    tags$div(class = "message-list", role = "log", `aria-label` = "Conversation messages", lapply(seq_len(nrow(messages)), function(i) {
      m <- messages[i, ]; tags$div(class = if (m$sender_id == user()) "message mine" else "message theirs", tags$p(m$body), tags$small(format(as.POSIXct(substr(m$created_at, 1, 19), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"), "%d %b · %H:%M UTC")))
    }))
  })
  output$conversation_tools<-renderUI({req(user());revision();chat<-tryCatch(selected_chat(),error=function(e)NULL);if(is.null(chat))return(NULL)
    tags$div(class="conversation-tools",tags$p(conversation_starter(con,user(),chat$target)),actionButton("use_starter","Use this conversation starter",class="btn-outline-primary"),actionButton("draft_closure","Draft a respectful goodbye",class="btn-link"),tags$p(class="fine-print","These actions only fill the composer. You choose whether to send."))
  })
  observeEvent(input$use_starter,attempt({chat<-selected_chat();updateTextAreaInput(session,"message",value=conversation_starter(con,user(),chat$target))}))
  observeEvent(input$draft_closure,attempt({selected_chat();updateTextAreaInput(session,"message",value="Thank you for chatting. I don't feel the connection I'm looking for, but I wish you well.")}))
  observeEvent(input$unmatch_chat,attempt({chat<-selected_chat();unmatch(con,user(),chat$target,chat$mode);bump();showNotification("Connection closed in this space.",type="message")}))
  output$export_my_data<-downloadHandler(filename=function()paste0("soulmatch-my-data-",format(Sys.Date(),"%Y-%m-%d"),".json"),contentType="application/json",content=function(file){req(user());rate_limit(con,user(),"export",5L,3600L);writeLines(jsonlite::toJSON(export_own_data(con,user()),auto_unbox=TRUE,pretty=TRUE,null="null",na="null"),file,useBytes=TRUE)})
  observeEvent(input$send, attempt({ req(user()); chat <- selected_chat(); send_message(con, user(), chat$target, input$message, chat$mode); updateTextAreaInput(session, "message", value = ""); bump() }))
  block_person <- function(target, reason = NULL) {
    req(user()); assert(!is.null(target) && target != user() && !is.null(get_profile(con, target)), "Choose an available profile.")
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, "INSERT OR IGNORE INTO blocks VALUES(?,?,?)", params = list(user(), target, now_utc()))
      if (!is.null(reason)) { reason <- clean_text(reason, 1000); assert(nzchar(reason), "Add a reason for the report."); DBI::dbExecute(con, "INSERT INTO reports VALUES(?,?,?,?,?)", params = list(new_id(), user(), target, reason, now_utc())) }
    })
    showNotification(if (is.null(reason)) "Blocked across Love and Friends." else "Report saved for the local operator; person blocked across both spaces.", type = "message"); bump()
  }
  observeEvent(input$block_candidate, attempt({ req(candidate()); block_person(candidate()$profile$user_id) }))
  observeEvent(input$report_candidate, attempt({ req(candidate()); block_person(candidate()$profile$user_id, input$candidate_report_reason %||% "") }))
  observeEvent(input$block_chat, attempt({ chat <- selected_chat(); block_person(chat$target) }))
  observeEvent(input$report_chat, attempt({ chat <- selected_chat(); block_person(chat$target, input$report_reason %||% "") }))
  observeEvent(input$delete_account, attempt({
    req(user()); assert(isTRUE(input$delete_ack), "Confirm permanent deletion first.")
    hash <- DBI::dbGetQuery(con, "SELECT password_hash FROM users WHERE id=?", params = list(user()))$password_hash[1]
    assert(sodium::password_verify(hash, input$delete_password %||% ""), "Password is incorrect.")
    delete_account(con, user(), photo_dir); user(NULL); candidate(NULL); drafts(list()); page(1L); connection_cache(character()); message_cache(data.frame()); showNotification("Your account and associated records have been deleted.", type = "message")
  }))
  invisible(list(user = user, profile = profile, candidate = candidate, impression = impression, con = con, current_mode = current_mode, interest_module = interest_module, active_module = active_module, page = page, world_cache = world_cache))
}
