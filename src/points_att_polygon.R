############################################################################################.
## 1. points_att_polygon ####
# function points_att_polygon - data points merged with polygon attributes based on data point location

library(sf)
library(magrittr)
library(dplyr)
library(janitor)
library(sp)
library(data.table)

sessionInfo()

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

  #dpoints to spatial
  print('Making input data spatial based on long, lat...')
  data_spatial <- sf::st_as_sf(dpoints, coords = c(long_col_name, lat_col_name))
  # set to WGS84 projection
  print('Setting to WGS84 CRS...')
  sf::st_crs(data_spatial) <- 4326
  print('It may take a while...')
  
  shp_wgs84 <- st_transform(shp, st_crs(data_spatial))
  if (!all(st_is_valid(shp_wgs84))) {
    shp_wgs84 <- st_make_valid(shp_wgs84)
  }

  shp_wgs84 <- st_filter(shp_wgs84, data_spatial) 
  data_shp <- st_join(shp_wgs84, data_spatial)
  data_shp <- sf::st_drop_geometry(data_shp)
  res <- full_join(dpoints, data_shp)
  rm(data_spatial)
  print('Done!')
  res
}

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_url <- args[1]
in_dpoints_url <- args[2]
in_long_col_name <- args[3]
in_lat_col_name <- args[4]
out_result_path <- args[5]

# Debug output to check if URLs are received correctly
cat("Regions URL:", in_shp_url, "\n")
cat("Data points URL:", in_dpoints_url, "\n")
cat("Longitude column:", in_long_col_name, "\n")
cat("Latitude column:", in_lat_col_name, "\n")
cat("Output file:", out_result_path, "\n")

source("points_att_polygon_data_download.R")
# Read the shapefile
shapefile <- st_read(shp_dir_unzipped)
# Load the data
data_raw <- read_data(table_file_path)

if (is.null(data_raw)) {
  print("Data reading failed or no valid data.")
} else {
  print("Data read successfully.")
}

source("points_att_polygon_preprocessing.R")
data_rel <- get_relevant_data(data_raw)

# Run the function "points_att_polygon"
out_points_att_polygon <- points_att_polygon(shp = shapefile,
                                             dpoints = data_rel,
                                             long_col_name = in_long_col_name,
                                             lat_col_name = in_lat_col_name)

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_points_att_polygon, file = out_result_path)