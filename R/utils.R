.format_elapsed <- function(x) {
  secs <- as.numeric(x, units = "secs")
  if (secs < 1) paste0(round(secs * 1000), "ms")
  else if (secs < 60) paste0(round(secs, 1), "s")
  else paste0(round(secs / 60, 1), "m")
}

# Hyperlink a path for cli messages: displays `text` (the path as given by
# default), but links to the absolute path so the link resolves regardless of
# the working directory. RStudio's console only opens file:// links in the
# editor (directories fail silently), so directories become run-links there,
# opening the folder in the file explorer instead. The run-link code must be
# `pkg::fun(args)` from a loaded package -- RStudio refuses anything else,
# including `:::` -- so it goes through utils::browseURL(), which is always
# loaded and hands a local directory to the system file manager. Falls back
# to plain text in terminals without hyperlink support.
.path_link <- function(path, text = path) {
  abs <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (dir.exists(path) && Sys.getenv("RSTUDIO") == "1")
    return(cli::format_inline("{.run [{text}](utils::browseURL('{abs}'))}"))
  cli::style_hyperlink(text, paste0("file://", abs))
}
