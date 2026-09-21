#' Export spatial features for Generic Mapping Tools
#'
#' Write GDAL's GMT/OGR ASCII vector format, retaining polygon holes,
#' feature attributes, and CRS metadata. GMT itself is not needed to export.
#' @param x A non-empty sf object with a known CRS and polygon geometry.
#' @param file A local output filename ending in `.gmt`.
#' @param overwrite Replace an existing file? Defaults to FALSE.
#' @return The output path, invisibly.
#' @details Output coordinates are WGS84 longitude/latitude (EPSG:4326).
#'   Multipart features are split into polygon records with repeated attributes;
#'   interior rings remain holes. Dateline crossings are split before export.
#'   Use GMT 6 `gmt plot file.gmt -R... -J...` to draw the result. This is a
#'   vector exchange helper, not a wrapper for GMT's plotting or grid modules.
#' @export
#' @examples
#' path <- tempfile(fileext = ".gmt")
#' write_gmt(get_reporting_areas("541"), path)
#' unlink(path)
write_gmt <- function(x, file, overwrite = FALSE) {
  if (!inherits(x, "sf") || !nrow(x) || is.na(sf::st_crs(x))) {
    stop("x must be a non-empty sf object with a known CRS.", call. = FALSE)
  }
  if (any(sf::st_is_empty(x)) ||
      !all(sf::st_geometry_type(x) %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("x must contain non-empty POLYGON or MULTIPOLYGON features.", call. = FALSE)
  }
  if (!is.character(file) || length(file) != 1L || is.na(file) ||
      !grepl("[.]gmt$", file, ignore.case = TRUE) || startsWith(file, "/vsi")) {
    stop("file must be a local filename ending in .gmt.", call. = FALSE)
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    stop("overwrite must be TRUE or FALSE.", call. = FALSE)
  }
  if (file.exists(file) && !overwrite) stop("File exists; use overwrite = TRUE.", call. = FALSE)
  drivers <- sf::st_drivers()
  driver <- intersect(c("OGR_GMT", "GMT"), drivers$name[drivers$write])
  if (!length(driver)) stop("Your GDAL installation lacks a writable GMT driver.", call. = FALSE)
  x <- sf::st_transform(x, 4326)
  x <- sf::st_wrap_dateline(x, options = c("WRAPDATELINE=YES", "DATELINEOFFSET=180"))
  x <- suppressWarnings(sf::st_cast(x, "POLYGON"))
  sf::st_write(x, dsn = file, driver = driver[1], delete_dsn = overwrite,
               quiet = TRUE)
  invisible(file)
}
