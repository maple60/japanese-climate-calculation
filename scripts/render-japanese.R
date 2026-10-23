# Build Japanese pages after the English profile and preserve its navigation
# index. Both profiles deliberately share the same QMD paths.
local({
  qmd <- c("index.qmd", list.files("notebooks", pattern = "\\.qmd$", full.names = TRUE))
  pages <- file.path("docs/ja", sub("\\.qmd$", ".html", qmd))
  inputs <- c(qmd, Sys.glob("_quarto*.yml"), "language-switch.html",
    "language-switch.css", list.files(c("R", "scripts", "filters"),
      recursive = TRUE, full.names = TRUE))
  fresh <- all(file.exists(pages)) &&
    max(file.info(inputs)$mtime) <= min(file.info(pages)$mtime)
  if (!fresh || Sys.getenv("QUARTO_PROJECT_RENDER_ALL") == "1") {
    index_files <- list.files(".quarto/idx", recursive = TRUE, full.names = TRUE)
    english_index <- lapply(index_files, function(file) {
      readBin(file, what = "raw", n = file.info(file)$size)
    })
    on.exit({
      for (i in seq_along(index_files)) writeBin(english_index[[i]], index_files[i])
    }, add = TRUE)
    status <- system2("quarto", c("render", "--profile", "ja"))
    if (status != 0L) stop("Japanese render failed.")
  } else {
    message("Japanese pages are up to date.")
  }

  # Keep previously published Japanese URLs usable without duplicate QMDs.
  legacy <- c("index.qmd", paste0("notebooks/", c("prepare_climate_data",
    "calculate_PET", "calculate_aridity_index", "get_nearest_climate_value",
    "plot_japan_climate_map"), ".qmd"))
  for (file in intersect(qmd, legacy)) {
    old <- sub("\\.qmd$", "_ja.html", file)
    target <- paste0(if (dirname(file) == ".") "" else "../",
      "ja/", sub("\\.qmd$", ".html", file))
    html <- paste0('<!doctype html>\n<html lang="ja"><meta charset="utf-8">\n',
      '<title>Page moved</title>\n',
      '<link rel="canonical" href="', target, '">\n',
      '<meta http-equiv="refresh" content="0;url=', target, '">\n',
      '<script>location.replace("', target,
      '" + location.search + location.hash);</script>\n',
      '<p><a href="', target, '">Continue to the Japanese page</a></p></html>')
    writeLines(enc2utf8(html), file.path("docs", old), useBytes = TRUE)
  }
  file.create("docs/.nojekyll")
})
