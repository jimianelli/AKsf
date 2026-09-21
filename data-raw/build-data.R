# Run from the repository root after: python3 data-raw/download.py
# Dependencies: sf, jsonlite. No data are downloaded by this script.
library(sf)
stopifnot(file.exists("DESCRIPTION"), read.dcf("DESCRIPTION")[1, "Package"] == "AKsf")
cache <- "data-raw/cache"
file.copy(c("DATA_SOURCES.md", "LICENSE-DATA.md"), "inst", overwrite = TRUE)
dir.create("data", showWarnings = FALSE)
manifest <- jsonlite::fromJSON("inst/extdata/source-manifest.json")

read_source <- function(name) {
  old_limit <- Sys.getenv("OGR_GEOJSON_MAX_OBJ_SIZE", unset = NA_character_)
  on.exit(if (is.na(old_limit)) Sys.unsetenv("OGR_GEOJSON_MAX_OBJ_SIZE") else
    Sys.setenv(OGR_GEOJSON_MAX_OBJ_SIZE = old_limit), add = TRUE)
  Sys.setenv(OGR_GEOJSON_MAX_OBJ_SIZE = "256")
  x <- st_read(file.path(cache, paste0(name, ".geojson")), quiet = TRUE)
  expected <- manifest$feature_count[manifest$dataset == name]
  stopifnot(nrow(x) == expected, !any(st_is_empty(x)))
  # GEOS repairs in Alaska Albers avoid planar operations across the dateline.
  x <- st_transform(x, 3338)
  x <- st_make_valid(x)
  stopifnot(all(st_is_valid(x)), !any(st_is_empty(x)))
  x <- st_transform(x, 4326)
  x$source_url <- manifest$source_url[manifest$dataset == name]
  x$retrieved_utc <- manifest$retrieved_utc[manifest$dataset == name]
  x
}
write_data <- function(name, x) {
  assign(name, x)
  save(list = name, file = file.path("data", paste0(name, ".rda")), compress = "xz", version = 2)
  message(name, ": ", nrow(x), " features")
}

nmfs_reporting_areas <- read_source("nmfs_reporting_areas")
nmfs_reporting_areas$area_code <- as.character(nmfs_reporting_areas$REP_AREA)
nmfs_reporting_areas$area_name <- paste("NMFS", nmfs_reporting_areas$area_code)
nmfs_reporting_areas$authority <- "NOAA/NMFS"
nmfs_reporting_areas$area_type <- "reporting_area"
write_data("nmfs_reporting_areas", nmfs_reporting_areas)

adfg_groundfish_statistical_areas <- read_source("adfg_groundfish_statistical_areas")
adfg_groundfish_statistical_areas$area_code <- sprintf("%06d", adfg_groundfish_statistical_areas$STAT_AREA)
adfg_groundfish_statistical_areas$area_name <- adfg_groundfish_statistical_areas$REGISTRATION_AREA_NAME
adfg_groundfish_statistical_areas$authority <- "ADF&G"
adfg_groundfish_statistical_areas$area_type <- "groundfish_statistical_area"
stopifnot(!anyDuplicated(adfg_groundfish_statistical_areas$area_code))
write_data("adfg_groundfish_statistical_areas", adfg_groundfish_statistical_areas)

adfg_groundfish_registration_areas <- read_source("adfg_groundfish_registration_areas")
adfg_groundfish_registration_areas$area_code <- adfg_groundfish_registration_areas$REGISTRATION_AREA_CODE
adfg_groundfish_registration_areas$area_name <- adfg_groundfish_registration_areas$REGISTRATION_AREA_NAME
adfg_groundfish_registration_areas$authority <- "ADF&G"
adfg_groundfish_registration_areas$area_type <- "groundfish_registration_area"
write_data("adfg_groundfish_registration_areas", adfg_groundfish_registration_areas)

# The broad FMP reference polygons are explicit analytical derivatives.
# ADF&G FED polygons exclude STATE and INTL; do not dissolve all NMFS areas
# because those include state-water reporting areas and the Donut Hole.
stat <- st_transform(adfg_groundfish_statistical_areas, 3338)
federal <- stat[stat$WATERS_CODE == "FED", ]
reporting <- st_transform(nmfs_reporting_areas, 3338)
bsai_envelope <- st_union(st_geometry(reporting[reporting$SubArea %in% c("BS", "AI"), ]))
goa_envelope <- st_union(st_geometry(reporting[reporting$SubArea == "GOA", ]))
bsai <- st_intersection(st_union(st_geometry(federal[federal$FMP_AREA_CODE == "BSAI", ])), bsai_envelope)
goa <- st_intersection(st_union(st_geometry(federal[federal$FMP_AREA_CODE == "GOA", ])), goa_envelope)

# Densify meridians/parallels to <=0.01 degree before projection. A rectangle
# here is only a clipping mask applied to agency marine polygons, never a
# substitute for a shoreline or the EEZ boundary.
mask <- function(xmin, ymin, xmax, ymax) {
  sx <- seq(xmin, xmax, length.out = ceiling((xmax - xmin)/0.01) + 1)
  sy <- seq(ymin, ymax, length.out = ceiling((ymax - ymin)/0.01) + 1)
  xy <- rbind(cbind(sx, ymin), cbind(xmax, sy[-1]),
              cbind(rev(sx)[-1], ymax), cbind(xmin, rev(sy)[-1]))
  st_transform(st_sfc(st_polygon(list(xy)), crs = 4326), 3338)
}
# Crab FMP section 3.1.2 uses Scotch Cap Light, not the groundfish 170 W line.
scotch_cap <- -(164 + 44/60 + 36/3600)
crab <- st_union(bsai, st_intersection(goa, mask(-180, 40, scotch_cap, 70)))
scallop <- st_union(bsai, goa)
arctic <- st_union(st_geometry(st_transform(read_source("arctic_management_area"), 3338)))

# Salmon FMP (October 2024), section 2.2. The NOAA ATB West polygon retains
# its source vintage and its PWS/Alaska Peninsula exclusions. It is not an
# independently redigitized legal boundary. Remove Cook Inlet explicitly.
cape_suckling <- -(143 + 53.6/60)
salmon_east <- st_intersection(goa, mask(cape_suckling, 40, -125, 65))
cook <- st_union(st_geometry(federal[federal$REGISTRATION_AREA_CODE == "H", ]))
cook <- st_intersection(cook, mask(-155, 59 + 46.15/60, -149, 64))
# Groundfish registration H also contains waters outside Cook Inlet. Select the
# connected federal-water polygon containing this interior Cook Inlet anchor.
cook_parts <- st_cast(cook, "POLYGON")
cook_anchor <- st_transform(st_sfc(st_point(c(-152.4, 60)), crs = 4326), 3338)
cook <- st_union(cook_parts[lengths(st_intersects(cook_parts, cook_anchor)) > 0])
stopifnot(length(cook) == 1, !st_is_empty(cook))
salmon_west <- st_union(st_geometry(st_transform(read_source("salmon_west_source"), 3338)))
salmon_west <- st_difference(salmon_west, cook)

geometries <- list(bsai, goa, crab, scallop, salmon_east, salmon_west, cook, arctic)
fmp_areas <- st_sf(
  fmp_id = c("BSAI_GF", "GOA_GF", "BSAI_CRAB", "SCALLOP", rep("SALMON", 3), "ARCTIC"),
  area_code = c("BSAI_GF", "GOA_GF", "BSAI_CRAB", "SCALLOP", "SALMON_EAST", "SALMON_WEST", "SALMON_COOK_INLET", "ARCTIC"),
  area_name = c("Bering Sea and Aleutian Islands groundfish", "Gulf of Alaska groundfish",
    "Bering Sea and Aleutian Islands king and Tanner crab", "Scallop federal management area",
    "Salmon East Area", "Salmon West Area", "Salmon Cook Inlet EEZ Area", "Arctic Management Area"),
  authority = "NPFMC / NOAA",
  area_type = "fmp_reference_area",
  geometry_basis = c(rep("adfg_federal_areas_clipped_to_noaa_reporting_envelope", 5),
    "noaa_atb_west_source_minus_cook_inlet", "adfg_federal_areas_clipped_to_noaa_reporting_envelope", "noaa_atb_arctic_closure"),
  source_url = c(rep(manifest$source_url[manifest$dataset == "adfg_groundfish_statistical_areas"], 5),
    manifest$source_url[manifest$dataset == "salmon_west_source"],
    manifest$source_url[manifest$dataset == "adfg_groundfish_statistical_areas"],
    manifest$source_url[manifest$dataset == "arctic_management_area"]),
  plan_library_url = "https://www.npfmc.org/library/fmps-feps/",
  boundary_status = "cartographic_reference_not_regulatory",
  geometry = st_sfc(lapply(geometries, function(x) st_cast(st_make_valid(x), "MULTIPOLYGON")[[1]]), crs = 3338)
)
stopifnot(all(st_is_valid(fmp_areas)), !any(st_is_empty(fmp_areas)))
fmp_areas$area_km2 <- as.numeric(st_area(fmp_areas))/1e6
write_data("fmp_areas", fmp_areas)

coast_path <- file.path(cache, "ne_10m_admin_1_states_provinces.zip")
coast_dir <- file.path(cache, "naturalearth")
unzip(coast_path, exdir = coast_dir)
land <- st_read(file.path(coast_dir, "ne_10m_admin_1_states_provinces.shp"), quiet = TRUE)
alaska_coast <- land[land$name == "Alaska" & land$admin == "United States of America", c("name", "admin")]
stopifnot(nrow(alaska_coast) == 1L)
alaska_coast <- st_transform(st_make_valid(st_transform(alaska_coast, 3338)), 4326)
alaska_coast$source_url <- manifest$source_url[manifest$dataset == "alaska_coast"]
write_data("alaska_coast", alaska_coast)

qa <- data.frame(dataset = c("nmfs_reporting_areas", "adfg_groundfish_statistical_areas",
  "adfg_groundfish_registration_areas", "fmp_areas", "alaska_coast"))
qa$features <- vapply(qa$dataset, function(n) nrow(get(n)), integer(1))
qa$all_valid_albers <- vapply(qa$dataset, function(n) all(st_is_valid(st_transform(get(n), 3338))), logical(1))
qa$empty_features <- vapply(qa$dataset, function(n) sum(st_is_empty(get(n))), integer(1))
write.csv(qa, "inst/extdata/geometry-qa.csv", row.names = FALSE)
writeLines(trimws(capture.output(sessionInfo()), which = "right"), "inst/extdata/build-session.txt")
