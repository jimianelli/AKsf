pkgdown::build_site(new_process = FALSE)
# Preserve repository-linked examples and images without using docs/ as the
# generated site destination (docs/ contains maintained source documents).
file.copy("docs", "_site", recursive = TRUE)
for (path in c("DATA_SOURCES.md", "LICENSE-DATA.md")) file.copy(path, "_site", overwrite = TRUE)
# pkgdown copies article images; retain the linked figure provenance record too.
file.copy("vignettes/pollock-maps/figure-manifest.csv",
          "_site/articles/pollock-maps/figure-manifest.csv", overwrite = TRUE)
