save_photo <- function(con, user, upload, photo_dir) {
  assert(!is.null(upload) && nrow(upload) == 1, "Choose one image.")
  assert(upload$size <= 5 * 1024^2, "Images must be under 5 MB.")
  assert(nrow(DBI::dbGetQuery(con, "SELECT id FROM photos WHERE user_id=?", params = list(user))) < 3, "You can upload up to three photos.")
  # Decode by file signature, then re-encode. Names and MIME headers are untrusted.
  sig <- readBin(upload$datapath, "raw", n = 8)
  is_png <- identical(as.integer(sig), c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
  is_jpeg <- length(sig) >= 3 && identical(as.integer(sig[1:3]), c(255L, 216L, 255L))
  assert(is_png || is_jpeg, "Use a real PNG or JPEG image.")
  image <- tryCatch(if (is_png) png::readPNG(upload$datapath) else jpeg::readJPEG(upload$datapath), error = function(e) stop("This image cannot be decoded.", call. = FALSE))
  dims <- dim(image)
  assert(length(dims) >= 2 && prod(dims[1:2]) <= 12000000, "Use a photo with no more than 12 million pixels.")
  # Limit stored size and remove EXIF/location metadata by writing pixels only.
  stride <- max(1L, as.integer(ceiling(max(dims[1:2]) / 1600)))
  rows <- seq(1, dims[1], by = stride); cols <- seq(1, dims[2], by = stride)
  image <- if (length(dims) == 3) image[rows, cols, , drop = FALSE] else image[rows, cols, drop = FALSE]
  dir.create(photo_dir, recursive = TRUE, showWarnings = FALSE, mode = "0700")
  id <- new_id(); filename <- paste0(id, ".png"); dest <- file.path(photo_dir, filename)
  png::writePNG(image, dest)
  Sys.chmod(dest, "0600")
  tryCatch(DBI::dbExecute(con, "INSERT INTO photos VALUES(?,?,?,?)", params = list(id, user, filename, now_utc())), error = function(e) { unlink(dest); stop(e) })
  invisible(id)
}
photo_path <- function(con, viewer, owner, photo_dir, registry) {
  if (viewer != owner) {
    a <- get_profile(con, viewer); b <- get_profile(con, owner)
    allowed <- !has_block(con, viewer, owner) && (is_mutual(con, viewer, owner, "love") || is_mutual(con, viewer, owner, "friends") ||
      ((eligible_pair(con, a, b, "love") || eligible_pair(con, a, b, "friends")) && completed_required(con, viewer, registry) && completed_required(con, owner, registry)))
    assert(allowed, "This photo is unavailable.")
  }
  photo <- DBI::dbGetQuery(con, "SELECT filename FROM photos WHERE user_id=? ORDER BY created_at LIMIT 1", params = list(owner))
  if (!nrow(photo)) return(NULL)
  path <- file.path(photo_dir, basename(photo$filename[[1]]))
  if (file.exists(path)) path else NULL
}
