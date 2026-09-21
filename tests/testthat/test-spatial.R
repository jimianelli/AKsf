test_that("agency codes and source schemas are preserved", {
  x <- get_statistical_areas(proj = NULL)
  expect_equal(nrow(x), 1735L)
  expect_true(all(grepl("^[0-9]{6}$", x$area_code)))
  expect_equal(anyDuplicated(x$area_code), 0L)
  expect_true(all(c("REGISTRATION_AREA_CODE", "DISTRICT_CODE", "SECTION_CODE",
                    "WATERS_CODE", "FMP_AREA_CODE", "GEOMETRY_START_DATE") %in% names(x)))
  expect_setequal(unique(x$WATERS_CODE), c("FED", "STATE", "INTL"))
  expect_equal(nrow(get_statistical_areas(x$area_code[1:2])), 2L)
  expect_equal(nrow(get_registration_areas()), 8L)
  expect_equal(get_registration_areas("H")$area_name, "Cook Inlet Area")
})

test_that("international areas require explicit selection", {
  x <- get_reporting_areas()
  expect_false("550" %in% x$area_code)
  expect_equal(nrow(get_reporting_areas(include_international = TRUE)), 25L)
  expect_equal(get_reporting_areas("550", include_international = TRUE)$SubArea, "Donut")
  # Reporting area 523 has two source features; neither is silently discarded.
  expect_equal(nrow(get_reporting_areas("523")), 2L)
  expect_error(get_reporting_areas("550"), "Unknown area")
})

test_that("input errors do not silently return an empty map", {
  expect_error(get_reporting_areas(541), "character")
  expect_error(get_reporting_areas(NA_character_), "character")
  expect_error(get_reporting_areas(character()), "character")
  expect_error(get_reporting_areas(include_international = NA), "TRUE or FALSE")
  expect_error(get_fmp_areas("not_a_plan"), "Unknown fmp")
  expect_error(get_registration_areas("999"), "Unknown area")
})

test_that("projection preserves western Aleutians without a world-spanning map", {
  expect_equal(sf::st_crs(get_reporting_areas())$epsg, 3338L)
  expect_equal(sf::st_crs(get_reporting_areas(proj = NULL))$epsg, 4326L)
  bb <- sf::st_bbox(get_coast())
  expect_lt(as.numeric(bb['xmax'] - bb['xmin']), 5e6)
  coast_ll <- sf::st_coordinates(get_coast(proj = NULL))
  expect_true(any(coast_ll[, 1] > 170))
  expect_true(any(coast_ll[, 1] < -170))
  pts <- sf::st_as_sf(data.frame(lon = c(179.9, -179.9), lat = c(52, 52)), coords = c("lon", "lat"), crs = 4326)
  pts <- sf::st_transform(pts, proj_aksf())
  expect_lt(as.numeric(sf::st_distance(pts)[1, 2]), 20000)
})

test_that("bundled geometries are valid and non-empty in Alaska Albers", {
  for (getter in list(get_reporting_areas, get_statistical_areas, get_registration_areas, get_fmp_areas, get_coast)) {
    x <- getter()
    expect_true(all(sf::st_is_valid(x)))
    expect_false(any(sf::st_is_empty(x)))
  }
})

test_that("all six FMPs are covered with explicit derivation metadata", {
  fmp <- get_fmp_areas()
  expect_equal(nrow(fmp), 8L)
  expect_setequal(fmp$fmp_id, get_fmp_catalog()$fmp_id)
  expect_true(all(fmp$boundary_status == "cartographic_reference_not_regulatory"))
  expect_true(all(nzchar(fmp$geometry_basis)))
  expect_true(all(fmp$area_km2 > 0))
  expect_setequal(get_fmp_areas("SALMON")$area_code,
                  c("SALMON_EAST", "SALMON_WEST", "SALMON_COOK_INLET"))
})

test_that("FMPs retain fishery-specific coverage", {
  # A point south of Unalaska east of 170 W is GOA groundfish but BSAI crab.
  p <- sf::st_transform(sf::st_sfc(sf::st_point(c(-166, 52)), crs = 4326), 3338)
  inside <- function(plan) lengths(sf::st_intersects(p, get_fmp_areas(plan))) > 0
  expect_true(inside("GOA_GF"))
  expect_false(inside("BSAI_GF"))
  expect_true(inside("BSAI_CRAB"))
  expect_true(inside("SCALLOP"))
  expect_false(inside("ARCTIC"))
  # Donut Hole center is international and must not be a groundfish FMP polygon.
  donut <- sf::st_transform(sf::st_sfc(sf::st_point(c(-178, 56)), crs = 4326), 3338)
  expect_length(sf::st_intersects(donut, get_fmp_areas(c("BSAI_GF", "GOA_GF")))[[1]], 0L)
})

test_that("salmon separates Cook Inlet from the West Area", {
  s <- get_fmp_areas("SALMON")
  cook <- s[s$area_code == "SALMON_COOK_INLET", ]
  west <- s[s$area_code == "SALMON_WEST", ]
  overlap <- suppressWarnings(sf::st_intersection(sf::st_geometry(cook), sf::st_geometry(west)))
  expect_lt(sum(as.numeric(sf::st_area(overlap))), 1)
  coords <- sf::st_coordinates(sf::st_transform(cook, 4326))
  expect_gte(min(coords[, 2]), 59 + 46.15/60 - 1e-5)
})

test_that("mapping helpers render composable layers without network access", {
  image <- tempfile(fileext = ".pdf")
  grDevices::pdf(image)
  on.exit({ grDevices::dev.off(); unlink(image) }, add = TRUE)
  p <- ggplot2::ggplot() + plot_reporting_areas("541", fill = NA) +
    plot_coast(fill = "grey90") + coord_aksf() + theme_aksf()
  expect_s3_class(ggplot2::ggplotGrob(p), "gtable")
  p2 <- ggplot2::ggplot() + plot_fmp_areas("ARCTIC") + coord_aksf()
  expect_s3_class(ggplot2::ggplotGrob(p2), "gtable")
})

test_that("groundfish reference coverage is clipped at NOAA's offshore envelope", {
  fmp <- get_fmp_areas(c("BSAI_GF", "GOA_GF"))
  reporting <- get_reporting_areas()
  envelope <- sf::st_union(sf::st_geometry(reporting[reporting$SubArea %in% c("BS", "AI", "GOA"), ]))
  outside <- sf::st_difference(sf::st_union(sf::st_geometry(fmp)), envelope)
  expect_lt(sum(as.numeric(sf::st_area(outside))), 10)
})

test_that("Cook Inlet contains no detached Gulf of Alaska component", {
  s <- get_fmp_areas("SALMON", proj = 4326)
  cook <- s[s$area_code == "SALMON_COOK_INLET", ]
  expect_lt(unname(sf::st_bbox(cook)['xmax']), -151)
  anchor <- sf::st_sfc(sf::st_point(c(-152.4, 60)), crs = 4326)
  expect_length(sf::st_intersects(sf::st_transform(anchor, 3338), sf::st_transform(cook, 3338))[[1]], 1L)
})
