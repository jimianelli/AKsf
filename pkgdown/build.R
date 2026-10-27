# Run from a Git checkout after installing the package and website dependencies.
build_aksf_site <- function() {
  image_path <- "man/figures/afsc-survey-temperature.png"
  staged <- c(
    "AFSC-INTEGRATION.md",
    "GITHUB-PAGES.md",
    "SOURCE-CODE.md",
    image_path
  )
  existing <- staged[file.exists(staged)]
  if (length(existing)) {
    stop(
      "Refusing to replace existing website staging files: ",
      paste(existing, collapse = ", ")
    )
  }
  created <- character()
  on.exit(unlink(created), add = TRUE)

  stage <- function(path, lines) {
    created <<- c(created, path)
    writeLines(lines, path, useBytes = TRUE)
  }

  created <- c(created, image_path)
  if (!file.copy("docs/survey-temperature.png", image_path)) {
    stop("Could not stage the AFSC guide image.")
  }
  integration <- readLines("docs/AFSC-INTEGRATION.md", warn = FALSE)
  integration <- gsub(
    "(examples/",
    "(docs/examples/",
    integration,
    fixed = TRUE
  )
  integration <- gsub(
    "](survey-temperature.png)",
    "](man/figures/afsc-survey-temperature.png)",
    integration,
    fixed = TRUE
  )
  stage("AFSC-INTEGRATION.md", integration)
  stage("GITHUB-PAGES.md", readLines("docs/GITHUB-PAGES.md", warn = FALSE))

  source_files <- system2(
    "git",
    c(
      "ls-files",
      "--",
      "R",
      "data-raw",
      "docs/examples",
      "pkgdown",
      "tests",
      ".github/workflows",
      "_pkgdown.yml",
      "vignettes/code-folding.html"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(source_files, "status")
  if (!is.null(status) && status != 0L) {
    stop(
      "Could not list tracked website source files: ",
      paste(source_files, collapse = "\n")
    )
  }
  source_files <- source_files[
    (grepl("\\.(r|py|yaml|yml|css|js)$", source_files, ignore.case = TRUE) |
      source_files == "vignettes/code-folding.html") &
      !grepl("^data-raw/cache(/|$)", source_files)
  ]
  source_files <- sort(unique(source_files))
  if (!length(source_files) || !all(file.exists(source_files))) {
    stop(
      "Tracked source files are missing; build the website from a complete Git checkout."
    )
  }
  languages <- c(
    r = "r",
    py = "python",
    yaml = "yaml",
    yml = "yaml",
    css = "css",
    js = "javascript",
    html = "html"
  )
  source_blocks <- lapply(source_files, function(path) {
    lines <- readLines(path, warn = FALSE)
    ticks <- regmatches(
      paste(lines, collapse = "\n"),
      gregexpr("`+", paste(lines, collapse = "\n"))
    )[[1]]
    fence <- strrep("`", max(c(3L, nchar(ticks) + 1L)))
    language <- languages[[tolower(tools::file_ext(path))]]
    c(paste0("## ", path), "", paste0(fence, language), lines, fence, "")
  })
  stage(
    "SOURCE-CODE.md",
    c(
      "# AKsf source code",
      "",
      "Read the package functions, data preparation, examples, tests, website build,",
      "and workflow code used by this checkout. Open a code panel to read or copy it.",
      "The listings are displayed without running them. See the guides for optional",
      "dependencies and instructions for running the examples.",
      "",
      unlist(source_blocks, use.names = FALSE)
    )
  )

  # Validate and initialise the destination before staging any site assets.
  pkgdown::init_site()
  # Home-page image checks run before reference assets are copied by pkgdown.
  dir.create("_site/reference/figures", recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(image_path, "_site/reference/figures", overwrite = TRUE)) {
    stop("Could not copy the AFSC guide image into the site.")
  }
  source("pkgdown/code-disclosures.R", local = TRUE)
  pkgdown::build_site(new_process = FALSE)
  # Keep maintained source guides, downloadable examples, and existing map assets.
  file.copy("docs", "_site", recursive = TRUE, overwrite = TRUE)
  file.copy(c("DATA_SOURCES.md", "LICENSE-DATA.md"), "_site", overwrite = TRUE)
  # Retain the linked figure provenance record alongside the article images.
  file.copy(
    "vignettes/pollock-maps/figure-manifest.csv",
    "_site/articles/pollock-maps/figure-manifest.csv",
    overwrite = TRUE
  )
  add_code_disclosures("_site")
}

build_aksf_site()
