# Reference outlines for GIS inspection, not navigational or regulatory guidance.
# Run after installing navmaps; choose a new output filename.
library(AKsf)
library(sf)
# One-metre display simplification removes near-duplicate vertices that can
# collapse when the exporter serializes coordinates. Keep original polygons for analysis.
x <- st_transform(st_simplify(get_fmp_areas("GOA_GF"),
                              dTolerance = 1, preserveTopology = TRUE), 4326)
x <- st_wrap_dateline(x, options = c("WRAPDATELINE=YES", "DATELINEOFFSET=180"))
# Export rings explicitly as separate lines: do not turn holes into filled areas.
x <- st_cast(st_boundary(x), "LINESTRING")
x$name <- paste0("AKsf reference: ", x$area_code)
x$description <- "Cartographic reference only; not for navigation or legal boundary decisions."
x$color <- "ff0000ff" # KML uses alpha-blue-green-red.
navmaps::sf_to_kml_linestring(x, file = "aksf-goa-reference.kml",
                            name_col = "name", description_col = "description",
                            color_col = "color")

# Verify the file actually preserves every ring as a valid geographic line.
y <- st_read("aksf-goa-reference.kml", quiet = TRUE)
stopifnot(nrow(y) == nrow(x), all(st_is_valid(y)),
          all(st_geometry_type(y) == "LINESTRING"), st_crs(y)$epsg == 4326)
