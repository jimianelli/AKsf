# Run from the AKsf repository root. Use local upstream checkouts; no downloads.
# Rscript docs/examples/survey-temperature.R /path/to/coldpool /path/to/akgfmaps [output.png]
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Supply coldpool and akgfmaps checkout directories.")
stopifnot(requireNamespace("terra", quietly = TRUE),
          requireNamespace("AKsf", quietly = TRUE))
library(ggplot2)
env <- new.env()
load(file.path(args[1], "data", "ebs_bottom_temperature.rda"), envir = env)
bt <- terra::unwrap(env$ebs_bottom_temperature)
# Use a fixed year, not the latest layer, so updates cannot silently change it.
year <- 2025L
layer <- grep(paste0("(^|[^0-9])", year, "([^0-9]|$)"), names(bt))
if (length(layer) != 1L) stop("Expected one 2025 bottom-temperature layer.")
bt <- bt[[layer]]
# Read upstream survey geometry, retaining design-year metadata.
survey <- sf::st_read(file.path(args[2], "inst/extdata/afsc_bts_strata.gpkg"),
                      layer = "survey_area", quiet = TRUE)
survey <- survey[survey$SURVEY_DEFINITION_ID == 98 &
                   survey$DESIGN_YEAR <= year, ]
survey <- survey[survey$DESIGN_YEAR == max(survey$DESIGN_YEAR), ]
stopifnot(nrow(survey) > 0L)
# Preserve the native temperature grid. Transform vector overlays to its CRS.
crs <- terra::crs(bt)
survey <- sf::st_transform(survey, crs)
fmp <- AKsf::get_fmp_areas("BSAI_GF", proj = crs)
reporting <- AKsf::get_reporting_areas(proj = crs)
reporting <- reporting[reporting$SubArea == "BS", ]
pts <- as.data.frame(bt, xy = TRUE, na.rm = TRUE)
names(pts)[3] <- "temperature"
p <- ggplot() +
  geom_tile(data = pts, aes(x, y, fill = temperature),
            width = terra::res(bt)[1], height = terra::res(bt)[2]) +
  geom_sf(data = reporting, fill = NA, colour = "grey50", linewidth = 0.2) +
  geom_sf(data = fmp, aes(colour = "BSAI groundfish FMP reference"),
          fill = NA, linewidth = 0.55) +
  geom_sf(data = survey, aes(colour = "EBS survey design"),
          fill = NA, linewidth = 0.6, linetype = 2) +
  scale_fill_viridis_c(name = "Bottom temperature (°C)") +
  scale_colour_manual(NULL, values = c("BSAI groundfish FMP reference" = "#a63603",
                                      "EBS survey design" = "#111111")) +
  coord_sf(crs = crs, default_crs = crs,
           xlim = c(terra::xmin(bt), terra::xmax(bt)),
           ylim = c(terra::ymin(bt), terra::ymax(bt)), expand = FALSE) +
  AKsf::theme_aksf() +
  theme(legend.position = "bottom", legend.box = "vertical") +
  labs(title = "Eastern Bering Sea: temperature, survey, and management",
       subtitle = paste("Temperature year", year, "• Survey design", unique(survey$DESIGN_YEAR)),
       caption = "Temperature: AFSC coldpool • Survey: akgfmaps • Boundaries: AKsf reference geometry\nSurvey coverage is not FMP coverage; unsampled water is not zero temperature.")
out <- if (length(args) >= 3L) args[3] else "survey-temperature.png"
ggsave(out, p, width = 10, height = 8, dpi = 160)
writeLines(c(paste("Raster layer:", names(bt)),
             paste("Survey design:", unique(survey$DESIGN_YEAR)),
             capture.output(sessionInfo())), paste0(out, ".session.txt"))
