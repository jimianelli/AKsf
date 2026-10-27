disclosure_functions <- function() {
  env <- new.env(parent = baseenv())
  sys.source(testthat::test_path("code-disclosures.R"), envir = env)
  env
}

testthat::test_that("mixed source and output retain visible output and anchors", {
  f <- disclosure_functions()
  doc <- xml2::read_html(paste0(
    '<main><div class="sourceCode" id="chunk">',
    '<button class="copy-button" aria-label="Copy code">Copy</button>',
    '<pre class="sourceCode r" id="pre"><code id="code">',
    '<span id="line-1">x &lt;- 1</span>',
    '<span class="r-output co" data-value="literal">#&gt; &lt;a&gt; &amp; 1</span>',
    '<span id="line-2">x + 1</span>',
    '</code></pre></div></main>'
  ))
  output <- as.character(xml2::xml_find_first(
    doc,
    "//span[contains(@class, 'r-output')]"
  ))
  text <- xml2::xml_text(xml2::xml_find_first(doc, "//main"))
  doc <- f$fold_code_html(doc)
  testthat::expect_length(xml2::xml_find_all(doc, "//details"), 2L)
  testthat::expect_length(xml2::xml_find_all(doc, "//details/summary"), 2L)
  testthat::expect_equal(
    xml2::xml_name(xml2::xml_find_all(doc, "//details/*[1]")),
    rep("summary", 2)
  )
  testthat::expect_equal(
    xml2::xml_text(xml2::xml_find_all(doc, "//summary")),
    rep("Show/hide R code", 2)
  )
  testthat::expect_length(xml2::xml_find_all(doc, "//details[@open]"), 0L)
  testthat::expect_identical(
    as.character(xml2::xml_find_first(
      doc,
      "//span[contains(@class, 'r-output')]"
    )),
    output
  )
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//span[contains(@class, 'r-output')]/ancestor::details"
    ),
    0L
  )
  testthat::expect_identical(
    gsub(
      "Show/hide R code",
      "",
      xml2::xml_text(
        xml2::xml_find_first(doc, "//main")
      ),
      fixed = TRUE
    ),
    text
  )
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  testthat::expect_setequal(ids, c("chunk", "pre", "code", "line-1", "line-2"))
  testthat::expect_equal(anyDuplicated(ids), 0L)
  testthat::expect_length(xml2::xml_find_all(doc, "//summary//button"), 0L)
  testthat::expect_length(xml2::xml_find_all(doc, "//button"), 1L)
})

testthat::test_that("separate printed output and plots remain outside code", {
  f <- disclosure_functions()
  doc <- xml2::read_html(paste0(
    '<div class="sourceCode"><pre class="r"><code>plot(1)</code></pre>',
    '<pre class="r-output">[1] 1</pre><img src="plot.png" alt="Plot"></div>',
    '<pre><code>## [1] 2\n## printed output</code></pre>',
    '<div class="cell-output"><pre class="r"><code>printed</code></pre></div>'
  ))
  before <- as.character(xml2::xml_find_all(
    doc,
    "//pre[contains(@class, 'r-output')] | //img"
  ))
  doc <- f$fold_code_html(doc)
  testthat::expect_length(xml2::xml_find_all(doc, "//details"), 1L)
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//details//img | //details//pre[contains(@class, 'r-output')]"
    ),
    0L
  )
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//div[@class='cell-output']//details"
    ),
    0L
  )
  testthat::expect_identical(
    as.character(xml2::xml_find_all(
      doc,
      "//pre[contains(@class, 'r-output')] | //img"
    )),
    before
  )
})

testthat::test_that("pkgdown reference plots remain visible in source order", {
  f <- disclosure_functions()
  doc <- xml2::read_html(paste0(
    '<main><div class="sourceCode">',
    '<pre class="sourceCode r"><code>',
    '<span id="source-before">plot_coast()</span>',
    '<span class="r-plt img"><img id="plot" src="plot_coast-1.png" ',
    'alt="Alaska coastline" width="700" height="400"></span>',
    '<span class="r-output co" id="printed">#&gt; printed output</span>',
    '<span id="source-after">next_plot()</span>',
    '</code></pre></div></main>'
  ))
  ordered_nodes <- "//*[@id='source-before' or @id='plot' or
    @id='printed' or @id='source-after']"
  before <- as.character(xml2::xml_find_all(doc, ordered_nodes))
  image <- as.character(xml2::xml_find_first(doc, "//span[@class='r-plt img']"))
  doc <- f$fold_code_html(doc)
  testthat::expect_identical(
    as.character(xml2::xml_find_all(doc, ordered_nodes)),
    before
  )
  testthat::expect_identical(
    as.character(xml2::xml_find_first(doc, "//span[@class='r-plt img']")),
    image
  )
  testthat::expect_length(xml2::xml_find_all(doc, "//details//img"), 0L)
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//*[@id='printed']/ancestor::details"
    ),
    0L
  )
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//details//*[@id='source-before' or @id='source-after']"
    ),
    2L
  )
  once <- as.character(doc)
  testthat::expect_identical(as.character(f$fold_code_html(doc)), once)
})

testthat::test_that("embedded figures, tables, and widgets stay outside code", {
  f <- disclosure_functions()
  doc <- xml2::read_xml(paste0(
    '<html><body><pre class="sourceCode r"><code>',
    '<span id="before">make_outputs()</span>',
    '<figure id="figure"><img src="figure.png" alt="Figure"/></figure>',
    '<svg id="svg"><path d="M 0 0 L 1 1"/></svg>',
    '<table id="table"><tbody><tr><td>result</td></tr></tbody></table>',
    '<div id="widget" class="html-widget"><canvas id="canvas"/></div>',
    '<script id="widget-data" type="application/json" data-for="widget">',
    '{"value":1}</script>',
    '<span id="after">next_step()</span>',
    '</code></pre></body></html>'
  ))
  ordered_nodes <- "//*[@id='before' or @id='figure' or @id='svg' or
    @id='table' or @id='widget' or @id='widget-data' or @id='after']"
  before <- as.character(xml2::xml_find_all(doc, ordered_nodes))
  doc <- f$fold_code_html(doc)
  testthat::expect_identical(
    as.character(xml2::xml_find_all(doc, ordered_nodes)),
    before
  )
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//details//img | //details//svg | //details//table |
      //details//canvas | //details//script"
    ),
    0L
  )
  testthat::expect_length(xml2::xml_find_all(doc, "//details"), 2L)
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  testthat::expect_equal(anyDuplicated(ids), 0L)
})

testthat::test_that("nested output markup and existing disclosures are safe", {
  f <- disclosure_functions()
  doc <- xml2::read_html(paste0(
    '<details open id="existing"><summary>Existing</summary>',
    '<pre class="r"><code>kept()</code></pre></details>',
    '<pre class="r" id="mixed"><code><span id="outer">source()',
    '<span class="r-output">#&gt; output</span>next()</span></code></pre>'
  ))
  original <- as.character(xml2::xml_find_first(doc, "//details"))
  output <- as.character(xml2::xml_find_first(
    doc,
    "//span[@class='r-output']"
  ))
  doc <- f$fold_code_html(doc)
  testthat::expect_identical(
    as.character(xml2::xml_find_first(doc, "//details[@id='existing']")),
    original
  )
  testthat::expect_length(xml2::xml_find_all(doc, "//details//details"), 0L)
  testthat::expect_identical(
    as.character(xml2::xml_find_first(doc, "//span[@class='r-output']")),
    output
  )
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//span[@class='r-output']/ancestor::details"
    ),
    0L
  )
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  testthat::expect_equal(anyDuplicated(ids), 0L)
  once <- as.character(doc)
  testthat::expect_identical(as.character(f$fold_code_html(doc)), once)
})

testthat::test_that("languages, escaped text, usage, and copy controls survive", {
  f <- disclosure_functions()
  doc <- xml2::read_html(paste0(
    '<main><div class="sourceCode" id="shell">',
    '<button class="btn-copy">Copy</button>',
    '<pre class="sourceCode bash"><code>echo "&lt;x&gt; &amp; y"</code></pre>',
    '</div><pre><code class="language-python">x = "&lt;value&gt;"</code></pre>',
    '<pre class="usage"><code>function_name(x = NULL)</code></pre>',
    '<pre><code>plain &lt;value&gt; &amp; text</code></pre></main>'
  ))
  code <- xml2::xml_text(xml2::xml_find_all(doc, "//pre"))
  doc <- f$fold_code_html(doc)
  testthat::expect_length(xml2::xml_find_all(doc, "//details/summary"), 4L)
  testthat::expect_equal(
    xml2::xml_name(xml2::xml_find_all(doc, "//details/*[1]")),
    rep("summary", 4)
  )
  testthat::expect_equal(
    xml2::xml_text(xml2::xml_find_all(doc, "//summary")),
    c(
      "Show/hide shell code",
      "Show/hide Python code",
      "Show/hide R code",
      "Show/hide code"
    )
  )
  testthat::expect_identical(
    xml2::xml_text(xml2::xml_find_all(doc, "//pre")),
    code
  )
  testthat::expect_length(
    xml2::xml_find_all(
      doc,
      "//details/div[@id='shell']/button"
    ),
    1L
  )
  testthat::expect_length(xml2::xml_find_all(doc, "//summary//button"), 0L)
})

testthat::test_that("recursive site processing is idempotent and HTML only", {
  f <- disclosure_functions()
  site <- withr::local_tempdir()
  dir.create(file.path(site, "articles"))
  html <- '<!doctype html><html><body><pre class="r">x &lt;- 1</pre></body></html>'
  paths <- c(
    file.path(site, "index.html"),
    file.path(site, "articles", "a.HTML")
  )
  for (path in paths) {
    writeLines(html, path, useBytes = TRUE)
  }
  raw <- file.path(site, "source.txt")
  writeLines(html, raw, useBytes = TRUE)
  testthat::expect_setequal(f$add_code_disclosures(site), paths)
  once <- lapply(c(paths, raw), readBin, what = "raw", n = 100000L)
  testthat::expect_identical(f$add_code_disclosures(site), character())
  testthat::expect_identical(
    lapply(c(paths, raw), readBin, what = "raw", n = 100000L),
    once
  )
  testthat::expect_length(
    xml2::xml_find_all(
      xml2::read_html(paths[[1]]),
      "//details[@class='code-disclosure']"
    ),
    1L
  )
  testthat::expect_identical(readLines(raw), html)
})
