#' Alaska mapping projection
#'
#' NAD83 / Alaska Albers (EPSG:3338), with metre units. This package default
#' is a cartographic choice, not a claim that every agency source uses this CRS.
#' @return An EPSG integer.
#' @export
proj_aksf <- function() 3338L

#' Coordinate system for Alaska maps
#' @param ... Arguments passed to [ggplot2::coord_sf()].
#' @return A ggplot2 coordinate object.
#' @export
coord_aksf <- function(...) ggplot2::coord_sf(crs = proj_aksf(), ...)

#' A quiet theme for scientific maps
#' @param base_size Base font size in points.
#' @param ... Arguments passed to [ggplot2::theme_minimal()].
#' @return A ggplot2 theme.
#' @export
 theme_aksf <- function(base_size = 11, ...) {
  ggplot2::theme_minimal(base_size = base_size, ...) +
    ggplot2::theme(panel.grid.major = ggplot2::element_line(colour = "grey85", linewidth = 0.2),
                   axis.title = ggplot2::element_blank(),
                   legend.position = "bottom")
}

# Internal loading avoids depending on whether users have attached the package.
.ak_data <- function(name) {
  env <- new.env(parent = emptyenv())
  utils::data(list = name, package = "AKsf", envir = env)
  env[[name]]
}

.ak_filter <- function(x, values, column, argument) {
  if (is.null(values)) return(x)
  if (!is.character(values) || !length(values) || anyNA(values)) {
    stop(argument, " must be a non-empty character vector, or NULL.", call. = FALSE)
  }
  missing <- setdiff(values, x[[column]])
  if (length(missing)) stop("Unknown ", argument, ": ", paste(missing, collapse = ", "), call. = FALSE)
  x[x[[column]] %in% values, , drop = FALSE]
}

.ak_transform <- function(x, proj) {
  if (is.null(proj)) return(x)
  sf::st_transform(x, proj)
}

#' Get NOAA/NMFS reporting areas
#' @param area Character reporting codes, such as `c("541", "542", "543")`.
#'   NULL returns all available codes (subject to `include_international`).
#' @param proj Output CRS; NULL retains the bundled EPSG:4326 geometry.
#' @param include_international Include the international Donut Hole (550).
#'   It is not part of the U.S. EEZ or a U.S. FMP management area.
#' @return An sf object. Native agency fields are retained alongside `area_code`,
#'   `area_name`, `authority`, and `area_type`.
#' @export
#' @examples
#' get_reporting_areas(c("541", "542", "543"))
get_reporting_areas <- function(area = NULL, proj = proj_aksf(), include_international = FALSE) {
  if (!is.logical(include_international) || length(include_international) != 1L || is.na(include_international)) {
    stop("include_international must be TRUE or FALSE.", call. = FALSE)
  }
  x <- .ak_data("nmfs_reporting_areas")
  if (!include_international) x <- x[x$area_code != "550", ]
  .ak_transform(.ak_filter(x, area, "area_code", "area"), proj)
}

#' Get ADF&G groundfish statistical areas
#' @param area Character six-digit statistical area codes; NULL returns all.
#' @param proj Output CRS; NULL retains EPSG:4326 geometry.
#' @return An sf object preserving the agency fields, including the statistical
#'   code, management hierarchy, waters code, and source dates. Convenience
#'   field `area_code` is always a six-character identifier.
#' @details This is the published 2001-present groundfish GIS series, not a
#'   historical reconstruction or a universal grid for all fisheries.
#' @export
get_statistical_areas <- function(area = NULL, proj = proj_aksf()) {
  .ak_transform(.ak_filter(.ak_data("adfg_groundfish_statistical_areas"), area, "area_code", "area"), proj)
}

#' Get ADF&G groundfish registration areas
#' @param area Character registration codes; NULL returns all.
#' @param proj Output CRS; NULL retains EPSG:4326 geometry.
#' @return An sf object with agency attributes and standardized identifiers.
#' @export
get_registration_areas <- function(area = NULL, proj = proj_aksf()) {
  .ak_transform(.ak_filter(.ak_data("adfg_groundfish_registration_areas"), area, "area_code", "area"), proj)
}

#' Get NPFMC FMP reference areas
#' @param fmp Character plan IDs: BSAI_GF, GOA_GF, BSAI_CRAB, SCALLOP,
#'   SALMON, or ARCTIC. NULL returns all six plans (eight features).
#' @param proj Output CRS; NULL retains the bundled EPSG:3338 geometry.
#' @return An sf object including `fmp_id`, `area_code`, `area_name`,
#'   `geometry_basis`, and `source_url`.
#' @details Reference polygons are derived or republished for scientific maps;
#'   they are not legal boundary determinations. Plans overlap. Salmon has
#'   East, West, and Cook Inlet features. The crab boundary differs from the
#'   groundfish boundary south of the Aleutians. Consult DATA_SOURCES.md in
#'   the repository and [get_fmp_catalog()] before analysis.
#' @export
#' @examples
#' get_fmp_areas(c("BSAI_GF", "GOA_GF"))
get_fmp_areas <- function(fmp = NULL, proj = proj_aksf()) {
  .ak_transform(.ak_filter(.ak_data("fmp_areas"), fmp, "fmp_id", "fmp"), proj)
}

#' Get Alaska land polygons for a basemap
#' @param proj Output CRS; NULL retains EPSG:4326 geometry.
#' @return An sf object from Natural Earth 1:10 million admin-1 land polygons.
#' @details A generalized cartographic basemap, not a NOAA shoreline or a
#'   state/federal waters boundary. Includes the western Aleutians.
#' @export
get_coast <- function(proj = proj_aksf()) .ak_transform(.ak_data("alaska_coast"), proj)

#' NPFMC plan catalog
#' @return A data.frame with plan names, NPFMC URLs, spatial basis, and caveats.
#' @export
get_fmp_catalog <- function() {
  utils::read.csv(system.file("extdata", "fmp-catalog.csv", package = "AKsf"),
                  stringsAsFactors = FALSE, na.strings = "")
}

#' Read the data provenance manifest
#' @return A character vector containing JSON with source URLs, retrieval
#'   timestamps, feature counts, and SHA-256 hashes of the downloaded snapshots.
#' @export
get_sources <- function() {
  readLines(system.file("extdata", "source-manifest.json", package = "AKsf"), warn = FALSE)
}
