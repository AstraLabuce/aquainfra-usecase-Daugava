
install.packages("mapview")
library(sp)
library(sf)
library(mapview)
library(webshot)
library(jsonlite)

map_shapefile_points <- function(shp, dpoints, 
                                 long_col_name="long", 
                                 lat_col_name="lat",
                                 value_name = NULL,
                                 region_col_name = NULL) {

  if (!requireNamespace("sp", quietly = TRUE)) {
    stop("Package \"sp\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package \"sf\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("mapview", quietly = TRUE)) {
    stop("Package \"mapview\" must be installed to use this function.",
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
  
  ## First, convert from WGS84-Pseudo-Mercator to pure WGS84
  print('Setting geometry data to same CRS...')
  shp_wgs84 <- sf::st_transform(shp, sf::st_crs(data_spatial))
  
  ## Check and fix geometry validity
  print('Check if geometries are valid...')# TODO: Check actually needed? Maybe just make valid!
  if (!all(sf::st_is_valid(shp_wgs84))) { # many are not (in the example data)!
    print('They are not! Making valid...')
    shp_wgs84 <- sf::st_make_valid(shp_wgs84)  # slowish...
    print('Making valid done.')
  }
  ## Overlay shapefile and in situ locations
  print(paste0('Drawing map...'))
  shp_wgs84 <- sf::st_filter(shp_wgs84, data_spatial) 

  mapview::mapview(shp_wgs84, 
                   alpha.region = 0.3, 
                   legend = FALSE,
                   zcol = region_col_name) + 
    mapview::mapview(data_spatial, 
                     zcol = value_name,
                     legend = TRUE, 
                     alpha = 0.8)
  
}

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_url <- args[1]      # e.g. "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip"
in_dpoints_path_or_url <- args[2]  # e.g. "https://..../data_out_point_att_polygon.csv"
in_long_col_name <- args[3] # e.g. "longitude"
in_lat_col_name <- args[4]  # e.g. "latitude"
in_value_name <- args[5]    # e.g. "transparency_m"
in_region_col_name <- args[6] # e.g. "HELCOM_ID"
#result_path_map_shapefile_points <- args[7] # e.g. "map_shapefile_insitu.html" # not being used!
out_result_path_url <- args[7] # e.g. "map_shapefile_insitu.html"

# Read the input data from file - this can take a URL!
dpoints <- data.table::fread(in_dpoints_path_or_url)

source("points_att_polygon_data_download_shp.R")

# Read shapefile
## TODO: Make more format agnostic??
shapefile <- st_read(shp_dir_unzipped)

# Call the function:
print('Running map_shapefile_points...')
map_out <- map_shapefile_points(shp = shapefile, 
                                 dpoints = dpoints,
                                 long_col_name = in_long_col_name,
                                 lat_col_name = in_lat_col_name,
                                 value_name = in_value_name, 
                                 region_col_name = in_region_col_name)

# Write the result to url file (!?):
print(paste0('Save map to html: ', out_result_path_url))
tryCatch(
  {
    mapview::mapshot(map_out, url = out_result_path_url)
    print(paste0("Map saved to ", out_result_path_url))
  },
  warning = function(warn) {
    message(paste("Saving HTML failed, reason: ", warn[1]))
    print('Trying with selfcontained=FALSE:')
    mapview::mapshot(map_out, url = out_result_path_url, selfcontained=FALSE)
    print(paste0("Map saved to ", out_result_path_url))
  },
  error = function(err) {
    message(paste("Saving HTML failed, reason: ", err[1]))
    print('Trying with selfcontained=FALSE:')
    mapview::mapshot(map_out, url = out_result_path_url, selfcontained=FALSE)
    print(paste0("Map saved to ", out_result_path_url))
  }
)
