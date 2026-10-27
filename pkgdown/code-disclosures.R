# Build-time disclosures cover pkgdown articles, home pages, and reference pages.
# Native details/summary keeps the controls usable without JavaScript.

code_node_classes <- function(node) {
  value <- xml2::xml_attr(node, "class")
  if (is.na(value) || !nzchar(value)) {
    return(character())
  }
  strsplit(tolower(value), "[[:space:]]+")[[1]]
}

code_node_is_output <- function(node) {
  if (xml2::xml_type(node) != "element") {
    return(FALSE)
  }
  # pkgdown can embed figures directly inside reference example pre/code.
  # Rendered output elements must remain visible when their input is closed.
  if (
    xml2::xml_name(node) %in%
      c(
        "img",
        "figure",
        "svg",
        "table",
        "iframe",
        "canvas",
        "video",
        "audio",
        "object",
        "embed",
        "script"
      )
  ) {
    return(TRUE)
  }
  any(
    code_node_classes(node) %in%
      c(
        "r-output",
        "r-plt",
        "img",
        "r-msg",
        "r-warning",
        "r-error",
        "code-output",
        "cell-output",
        "cell-output-stdout",
        "html-widget",
        "html-widget-output",
        "knitr-figure",
        "output",
        "stdout"
      )
  )
}

code_has_output <- function(node) {
  nodes <- c(list(node), as.list(xml2::xml_find_all(node, ".//*")))
  any(vapply(nodes, code_node_is_output, logical(1)))
}

code_language <- function(pre) {
  nodes <- c(list(pre), as.list(xml2::xml_find_all(pre, "./code")))
  classes <- unique(unlist(lapply(nodes, code_node_classes)))
  classes <- sub("^language-", "", classes)
  languages <- c(
    r = "R",
    bash = "shell",
    sh = "shell",
    shell = "shell",
    python = "Python",
    py = "Python",
    javascript = "JavaScript",
    js = "JavaScript",
    typescript = "TypeScript",
    ts = "TypeScript",
    yaml = "YAML",
    yml = "YAML",
    json = "JSON",
    sql = "SQL",
    html = "HTML",
    css = "CSS",
    xml = "XML",
    tex = "LaTeX",
    latex = "LaTeX",
    c = "C",
    cpp = "C++",
    usage = "R"
  )
  found <- classes[classes %in% names(languages)]
  if (length(found)) {
    return(unname(languages[[found[[1]]]]))
  }
  ""
}

code_pre_is_source <- function(pre) {
  classes <- code_node_classes(pre)
  parents <- xml2::xml_find_all(pre, "ancestor::*")
  if (any(vapply(as.list(parents), code_node_is_output, logical(1)))) {
    return(FALSE)
  }
  if (code_node_is_output(pre)) {
    return(FALSE)
  }
  explicit <- "sourcecode" %in% classes || nzchar(code_language(pre))
  code <- xml2::xml_find_all(pre, "./code")
  if (!explicit && !length(code)) {
    return(FALSE)
  }
  if (!explicit) {
    lines <- trimws(strsplit(xml2::xml_text(pre), "\n", fixed = TRUE)[[1]])
    lines <- lines[nzchar(lines)]
    if (
      length(lines) &&
        all(grepl(
          "^(##([[:space:]]|$)|#>|\\[[[:digit:]]+\\]|Warning:|Error:)",
          lines
        ))
    ) {
      return(FALSE)
    }
  }
  nzchar(trimws(xml2::xml_text(pre)))
}

# Partition mixed reference examples while retaining their inline markup. Each
# original ID is kept on its first fragment, so links remain unique and valid.
split_code_output <- function(node) {
  if (code_node_is_output(node)) {
    return(list(list(output = TRUE, node = node)))
  }
  if (!code_has_output(node)) {
    return(list(list(output = FALSE, node = node)))
  }
  contents <- xml2::xml_contents(node)
  parts <- list()
  for (i in seq_along(contents)) {
    parts <- c(parts, split_code_output(contents[[i]]))
  }
  groups <- list()
  for (part in parts) {
    last <- length(groups)
    if (last && identical(groups[[last]]$output, part$output)) {
      groups[[last]]$nodes <- c(groups[[last]]$nodes, list(part$node))
    } else {
      groups[[last + 1L]] <- list(
        output = part$output,
        nodes = list(part$node)
      )
    }
  }
  result <- vector("list", length(groups))
  for (i in seq_along(groups)) {
    shell <- xml2::xml_root(xml2::xml_new_root(xml2::xml_name(node)))
    attrs <- xml2::xml_attrs(node)
    if (i > 1L) {
      attrs <- attrs[names(attrs) != "id"]
    }
    xml2::xml_set_attrs(shell, attrs)
    for (child in groups[[i]]$nodes) {
      xml2::xml_add_child(shell, child, .copy = TRUE)
    }
    result[[i]] <- list(output = groups[[i]]$output, node = shell)
  }
  result
}

wrap_code_pre <- function(pre, wrap_container = TRUE) {
  target <- pre
  parent <- xml2::xml_parent(pre)
  if (
    wrap_container &&
      xml2::xml_name(parent) == "div" &&
      "sourcecode" %in% code_node_classes(parent) &&
      length(xml2::xml_find_all(parent, ".//pre")) == 1L &&
      !code_has_output(parent)
  ) {
    # Keep a source block's anchor and existing copy control together, without
    # pulling plots, widgets, prose, or separate output into the disclosure.
    children <- xml2::xml_children(parent)
    safe <- vapply(
      as.list(children),
      function(child) {
        xml2::xml_name(child) %in%
          c("pre", "button") ||
          any(code_node_classes(child) %in% c("copy-button", "btn-copy"))
      },
      logical(1)
    )
    if (all(safe)) {
      target <- parent
    }
  }
  language <- code_language(pre)
  label <- paste("Show/hide", language, "code")
  label <- gsub("  ", " ", label, fixed = TRUE)
  xml2::xml_add_parent(
    target,
    "details",
    class = "code-disclosure"
  )
  details <- xml2::xml_parent(target)
  xml2::xml_add_child(details, "summary", label, .where = 0L)
  invisible(details)
}

fold_code_html <- function(doc) {
  pres <- xml2::xml_find_all(doc, "//pre")
  for (i in seq_along(pres)) {
    pre <- pres[[i]]
    if (
      length(xml2::xml_find_all(pre, "ancestor::details")) ||
        !code_pre_is_source(pre)
    ) {
      next
    }
    if (!code_has_output(pre)) {
      wrap_code_pre(pre)
      next
    }
    # Output can share a code element with input. Split runs rather than hiding
    # the whole sourceCode container, leaving every output span visible.
    parts <- split_code_output(pre)
    for (part in parts) {
      inserted <- xml2::xml_add_sibling(
        pre,
        part$node,
        .where = "before",
        .copy = TRUE
      )
      if (part$output) {
        classes <- xml2::xml_attr(inserted, "class")
        if (is.na(classes)) {
          classes <- ""
        }
        xml2::xml_set_attr(
          inserted,
          "class",
          trimws(paste(classes, "code-output"))
        )
      } else if (nzchar(trimws(xml2::xml_text(inserted)))) {
        wrap_code_pre(inserted, wrap_container = FALSE)
      }
    }
    xml2::xml_remove(pre)
  }
  doc
}

add_code_disclosures <- function(site_dir) {
  if (!dir.exists(site_dir)) {
    stop("Site directory does not exist: ", site_dir, call. = FALSE)
  }
  files <- list.files(
    site_dir,
    pattern = "\\.html$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  changed <- character()
  for (path in files) {
    doc <- xml2::read_html(
      path,
      options = c("RECOVER", "NOERROR", "NOWARNING", "NONET")
    )
    before <- as.character(doc)
    doc <- fold_code_html(doc)
    if (!identical(before, as.character(doc))) {
      xml2::write_html(doc, path)
      changed <- c(changed, path)
    }
  }
  invisible(changed)
}
