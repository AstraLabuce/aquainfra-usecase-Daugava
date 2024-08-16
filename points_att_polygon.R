############################################################################################.
## 1. points_att_polygon ####
# function points_att_polygon - data points merged with polygon attributes based on data point location

library(sf)
library(magrittr)
library(dplyr)
library(janitor)
library(sp)
library(data.table)

points_att_polygon <- function(shp, dpoints, long_col_name="long", lat_col_name="lat") {
  #shp - shapefile
  #dpoints - dataframe with values and numeric variables for coordinates:
  #long - longitude column name in dpoints; default "long"
  #lat - latitude column name in dpoints; default "lat"
  
  if (!requireNamespace("sp", quietly = TRUE)) {
    stop("Package \"sp\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package \"sf\" must be installed to use this function.",
         call. = FALSE)
  }
  
  if (missing(shp))
    stop("missing shp")
  if (missing(dpoints))
    stop("missing dpoints")
  if (! long_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", long_col_name))
  if (! lat_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", lat_col_name))

  # TODO: long and lat hardcoded!
  err = paste0("Error: `", long_col_name, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == long_col_name]))
  err = paste0("Error: `", lat_col_name, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == lat_col_name]))
  
  #dpoints to spatial
  print('Making input data spatial based on long, lat...')
  data_spatial <- sf::st_as_sf(dpoints, coords = c(long_col_name, lat_col_name))
  # set to WGS84 projection
  print('Setting to WGS84 CRS...')
  sf::st_crs(data_spatial) <- 4326

  shp_wgs84 <- st_transform(shp, st_crs(data_spatial))
  if (!all(st_is_valid(shp_wgs84))) {
    shp_wgs84 <- st_make_valid(shp_wgs84)
  }

  shp_wgs84 <- st_filter(shp_wgs84, data_spatial) 
  data_shp <- st_join(shp_wgs84, data_spatial)
  data_shp <- sf::st_drop_geometry(data_shp)
  res <- full_join(dpoints, data_shp)
  rm(data_spatial)
  res
}
