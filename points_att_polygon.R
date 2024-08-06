############################################################################################.
## 1. points_att_polygon ####
# function points_att_polygon - data points merged with polygon attributes based on data point location

#RUN WITH
# Rscript points_att_polygon.R "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip" "in_situ_data/in_situ_example.xlsx" "longitude" "latitude" "data_out_point_att_polygon.csv"

library(sf)
library(magrittr)
library(dplyr)
library(janitor)
library(sp)
library(data.table)

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))

in_shp_path <- args[1]
in_dpoints_path <- args[2]
in_long_col_name <- args[3]
in_lat_col_name <- args[4]
out_result_path <- args[5]

url_parts <- strsplit(in_shp_path, "/")[[1]]
file_name <- url_parts[length(url_parts)]

local_file_path <- paste0("./shp/", file_name)

# Check if the file is already downloaded
if (!file.exists(local_file_path)) {
  download.file(in_shp_path, local_file_path, mode = "wb")
} else {
  print(paste0("File ", local_file_path, " already exists. Skipping download."))
}

shp_dir <- paste0("./shp/", sub("\\.zip$", "", file_name))
# Check if the unzipped directory already exists
if (!dir.exists(shp_dir)) {
  # Unzip the downloaded file if the directory doesn't exist
  unzip(local_file_path, exdir = shp_dir)
} else {
  print(paste0("Directory ", shp_dir, " already exists. Skipping unzip."))
}

shapefile <- st_read(shp_dir)

data_raw <- readxl::read_excel(in_dpoints_path) %>%
  janitor::clean_names()

rel_columns <- c(
  "longitude",
  "latitude",
  "visit_date",
  "transparency_m",
  "color_id"
)

data_rel <- data_raw %>%
  dplyr::select(all_of(rel_columns)) %>%
  filter(
    !is.na(`transparency_m`) &
      !is.na(`color_id`) &
      !is.na(`longitude`) &
      !is.na(`latitude`)
  )

data_rel <- data_rel %>%
  mutate(
    longitude  = as.numeric(longitude),
    latitude   = as.numeric(latitude),
    transparency_m = as.numeric(transparency_m)
  )

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

out_points_att_polygon <- points_att_polygon(
  shp = shapefile, 
  dpoints = data_rel, 
  long_col_name = in_long_col_name, 
  lat_col_name = in_lat_col_name)

print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_points_att_polygon, file = out_result_path)