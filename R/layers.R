#' Add an Alaska coastline layer
#' @param proj Output CRS.
#' @param ... Arguments passed to [ggplot2::geom_sf()], including fill and colour.
#' @return A ggplot2 layer.
#' @export
#' @examples
#' ggplot2::ggplot() + plot_coast(fill = "grey90") + coord_aksf() + theme_aksf()
plot_coast <- function(proj = proj_aksf(), ...) ggplot2::geom_sf(data = get_coast(proj), ...)

#' Add a NOAA reporting-area layer
#' @inheritParams get_reporting_areas
#' @param ... Arguments passed to [ggplot2::geom_sf()].
#' @return A ggplot2 layer.
#' @export
plot_reporting_areas <- function(area = NULL, proj = proj_aksf(), include_international = FALSE, ...) {
  ggplot2::geom_sf(data = get_reporting_areas(area, proj, include_international), ...)
}

#' Add an ADF&G statistical-area layer
#' @inheritParams get_statistical_areas
#' @param ... Arguments passed to [ggplot2::geom_sf()].
#' @return A ggplot2 layer.
#' @export
plot_statistical_areas <- function(area = NULL, proj = proj_aksf(), ...) {
  ggplot2::geom_sf(data = get_statistical_areas(area, proj), ...)
}

#' Add an ADF&G registration-area layer
#' @inheritParams get_registration_areas
#' @param ... Arguments passed to [ggplot2::geom_sf()].
#' @return A ggplot2 layer.
#' @export
plot_registration_areas <- function(area = NULL, proj = proj_aksf(), ...) {
  ggplot2::geom_sf(data = get_registration_areas(area, proj), ...)
}

#' Add an NPFMC FMP reference-area layer
#' @inheritParams get_fmp_areas
#' @param ... Arguments passed to [ggplot2::geom_sf()].
#' @return A ggplot2 layer.
#' @export
plot_fmp_areas <- function(fmp = NULL, proj = proj_aksf(), ...) {
  ggplot2::geom_sf(data = get_fmp_areas(fmp, proj), ...)
}
