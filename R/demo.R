seed_demo <- function(con, registry) {
  catalog <- load_interest_catalog()
  people <- list(
    list("alex", "Alex", 29, "Nonbinary", GENDERS, "Prague", "A book in my bag, a new trail on my map. Looking for kind people to share ordinary adventures with.", "25–50k", "Creative", c("Books", "Hiking", "Art")),
    list("maya", "Maya", 28, "Female", c("Male", "Nonbinary"), "Prague", "Architect, enthusiastic home cook, and collector of very niche playlists. Let's find the best little café in town.", "50–100k", "Creative", c("Cooking", "Art", "Music")),
    list("leo", "Leo", 31, "Male", c("Female", "Nonbinary"), "Prague", "I work with data and unwind with a guitar. Happiest on a long walk that ends with good food.", "50–100k", "Casual", c("Music", "Hiking", "Science")),
    list("sam", "Sam", 27, "Nonbinary", GENDERS, "Brno", "Museum afternoons, live music, and making things with my hands. Tell me about the last thing that made you curious.", "25–50k", "Alternative", c("Art", "Music", "Travel")),
    list("nora", "Nora", 34, "Female", GENDERS, "Prague", "A scientist with an optimistic approach to baking. I'd like a little steadiness, and room for spontaneity.", "50–100k", "Classic", c("Science", "Cooking", "Books")),
    list("adam", "Adam", 26, "Male", c("Female", "Nonbinary"), "Brno", "Weekend cyclist, weekday designer. I appreciate people who are thoughtful, playful, and comfortable being themselves.", "25–50k", "Sporty", c("Fitness", "Art", "Gaming")),
    list("elena", "Elena", 30, "Female", c("Male", "Nonbinary"), "Prague", "I teach languages, love old cinemas, and make a pretty good risotto. Looking for conversations that go somewhere.", "25–50k", "Casual", c("Cinema", "Travel", "Cooking")),
    list("jamie", "Jamie", 36, "Male", c("Male", "Nonbinary"), "Prague", "Gardening, science fiction, and slow Sunday breakfasts. A thoughtful connection, at our own pace.", "100k+", "Classic", c("Books", "Science", "Cooking")))
  fresh <- !nrow(DBI::dbGetQuery(con, "SELECT id FROM users LIMIT 1")); set.seed(1406); ids <- list()
  for (person in people) {
    row <- DBI::dbGetQuery(con, "SELECT id FROM users WHERE username=? AND is_demo=1", params = list(person[[1]]))
    if (fresh) {
      id <- register_user(con, person[[1]], "SoulMatchDemo!2026")
      DBI::dbExecute(con, "UPDATE users SET is_demo=1 WHERE id=?", params = list(id))
      save_profile(con, id, list(name = person[[2]], age = person[[3]], gender = person[[4]], interested = person[[5]], connection_modes = CONNECTION_MODES, city = person[[6]], bio = person[[7]], income = person[[8]], style = person[[9]], smoking = "No", goal = GOALS[1], hobbies = person[[10]], preferences = modifyList(DEFAULT_PREFS, list(age = c(26, 33))), consent = FALSE))
    } else if (nrow(row)) id <- row$id[1] else next
    if (!fresh) DBI::dbExecute(con, "UPDATE users SET password_hash=? WHERE id=? AND is_demo=1", params = list(sodium::password_store("SoulMatchDemo!2026"), id))
    ids[[person[[1]]]] <- id
    for (q in active_instruments(registry)) {
      if (nrow(DBI::dbGetQuery(con, "SELECT 1 FROM responses WHERE user_id=? AND instrument_id=? AND version=?", params = list(id, q$id, q$version)))) next
      answers <- as.list(sample(seq(q$scale_min, q$scale_max), q$item_count, replace = TRUE)); names(answers) <- q$items$id
      save_answers(con, id, q, answers)
    }
    if (is.null(read_interest_state(con, id, catalog, TRUE)$session_id)) {
      state <- empty_interest_state(); state$selected <- sample(catalog$interests$id, 6)
      # A small shared core keeps the demo readable; all answers are explicitly synthetic.
      state$selected[1:2] <- c("food_drinks_01", "books_learning_04")
      state$selected <- unique(state$selected); state$categories <- unique(catalog$interests$category_id[match(state$selected, catalog$interests$id)])
      state$details <- setNames(lapply(state$selected, function(x) list(enjoyment = sample(3:5, 1), frequency = sample(2:5, 1), importance = sample(2:5, 1))), state$selected)
      for (q in catalog$definition$lifestyle) { state$lifestyle[[q$id]] <- sample(vapply(q$options, `[[`, "", "value"), 1); state$lifestyle_importance[[q$id]] <- sample(2:5, 1) }
      state$shared <- list(shared_01 = 2L, shared_11 = 3L); state$step <- 6L
      save_interest_state(con, id, state, catalog, TRUE)
    }
  }
  if (!is.null(ids$maya) && !is.null(ids$alex)) for (mode in CONNECTION_MODES) DBI::dbExecute(con, "INSERT INTO decisions VALUES(?,?,?,?,?) ON CONFLICT(actor_id,target_id,mode) DO NOTHING", params = list(ids$maya, ids$alex, "like", now_utc(), mode))
}
