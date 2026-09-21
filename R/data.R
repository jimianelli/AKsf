#' NOAA Alaska reporting areas
#' @format An sf object in EPSG:4326. Native fields include REP_AREA (reporting
#'   code), SubArea (BS, AI, GOA, Arctic, or Donut), and OBJECTID. Added fields:
#'   area_code, area_name, authority, area_type, source_url, retrieved_utc.
#'   Code 550 is international water. Some reporting areas include state waters.
#' @source NOAA Alaska Regional Office Base_Map service; see [get_sources()].
"nmfs_reporting_areas"

#' ADF&G groundfish statistical areas
#' @format An sf object in EPSG:4326 with the complete published agency schema.
#'   STAT_AREA is the native numeric code; area_code is its six-character form.
#'   Registration, district, subdistrict, section, and sector fields retain the
#'   agency hierarchy. WATERS_CODE distinguishes FED, STATE, and INTL. Agency
#'   date fields are Unix milliseconds; missing end dates denote no stated end.
#'   Source Shape fields are retained metadata, not recomputed measurements.
#' @source ADF&G Groundfish_Statistical_Areas_2001 service; see [get_sources()].
"adfg_groundfish_statistical_areas"

#' ADF&G groundfish registration areas
#' @format An sf object in EPSG:4326. REGISTRATION_AREA_CODE and
#'   REGISTRATION_AREA_NAME are the native identifiers. Standardized area_code
#'   and area_name fields duplicate those values. Source geometry dates,
#'   fishery/region codes, attribution, and provenance are retained.
#' @source ADF&G Commercial Fisheries Groundfish Registration Areas service.
"adfg_groundfish_registration_areas"

#' NPFMC fishery management plan reference polygons
#' @format An sf object in EPSG:3338 with eight rows representing six FMPs.
#'   Salmon has three rows. Fields: fmp_id, area_code, area_name, authority,
#'   area_type, geometry_basis, source_url, plan_library_url, boundary_status,
#'   area_km2 (computed in Alaska Albers), and geometry.
#' @details Derived reference geometry is not a regulatory boundary product.
#'   Polygons overlap across fisheries. See [get_fmp_catalog()] for limitations.
#' @source NPFMC plan definitions, ADF&G federal statistical polygons, and NOAA
#'   Management Areas ATB. Full methods are in data-raw/build-data.R.
"fmp_areas"

#' Alaska generalized land polygons
#' @format An sf object in EPSG:4326 with name, admin, source_url and geometry.
#' @source Natural Earth 1:10 million admin-1 states/provinces, public domain.
#' @details Cartographic land representation, not a regulatory shoreline.
"alaska_coast"
