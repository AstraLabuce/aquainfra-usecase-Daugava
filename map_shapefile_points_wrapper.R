################################################################################.
## 6. visualization ####
################################################################################.

## Run:
## Rscript map_shapefile_points_wrapper.R "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp" "data_out_point_att_polygon.csv" "longitude" "latitude" "transparency_m" "HELCOM_ID" "map_shapefile_insitu.html"
## Rscript map_shapefile_points_wrapper.R "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp" "data_out_point_att_polygon.csv" "longitude" "latitude" "transparency_m" "HELCOM_ID" "map_shapefile_insitu.html"

### 6.1. map: shp + dpoints ####

library(sp)
library(sf)
library(mapview)
library(webshot)
library(jsonlite)

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


## Where to find inputs?
# TODO: Make data access consistent. In pygeoapi processes we pass a URL, here it is a local path...
config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
print(paste0("Path to config file: ", config_file_path))

# Get input data directory:
# If config json exists, read from there, otherwise input data dir set to ./
if (file.exists(config_file_path)) {
  config_data <- jsonlite::fromJSON(config_file_path)
  print("Config file loaded successfully.")
  input_data_dir <- config_data["input_data_dir"]
  print(paste("The value of 'input_data_dir' is:", input_data_dir))
} else {
  print("Config file not found. Input directory set to directory ./")
  input_data_dir <- "./"
}

# Read the input data from file - this can take a URL!
dpoints <- data.table::fread(in_dpoints_path_or_url)

# Define the directory and local file path for the shape file
url_parts_shp <- strsplit(in_shp_url, "/")[[1]]
shp_file_name <- url_parts_shp[length(url_parts_shp)]
shp_dir_zipped <- paste0(input_data_dir, "shp/")
shp_file_path <- paste0(shp_dir_zipped, shp_file_name)

# Ensure the shapefile directory exists, create if not
print(paste0('Checking whether this file exists: ', shp_file_path))
if (!dir.exists(shp_dir_zipped)) {
  success <- dir.create(shp_dir_zipped, recursive = TRUE)
  if (success) {
    print(paste0("Directory ", shp_dir_zipped, " created."))
  } else {
    stop(paste0("Directory ", shp_dir_zipped, " not created (failed)."))
  }
}

# Download shapefile if it doesn't exist:
# TODO: Problem: If someone wants to use a shapefile that happens to have the same name! Should use PIDs.
if (file.exists(shp_file_path)) {
  print(paste0("File ", shp_file_path, " already exists. Skipping download."))
} else {
  tryCatch(
    {
      download.file(in_shp_url, shp_file_path, mode = "wb")
      print(paste0("File ", shp_file_path, " downloaded."))
    },
    warning = function(warn) {
      stop(paste("Download of shapefile failed, reason: ", warn[1]))
    },
    error = function(err) {
      stop(paste("Download of shapefile failed, reason: ", err[1]))
    }
  )
}

# Unzip shapefile if it is not unzipped yet:
shp_dir_unzipped <- paste0(shp_dir_zipped, sub("\\.zip$", "", shp_file_name))
if (dir.exists(shp_dir_unzipped)) {
    print(paste0("Directory ", shp_dir_unzipped, " already exists. Skipping unzip."))
} else {
  tryCatch(
    {
      unzip(shp_file_path, exdir = shp_dir_unzipped)
      print(paste0("Unzipped to directory ", shp_dir_unzipped))
    },
    warning = function(warn) {
      message(paste("Unzipping ", shp_file_path, " failed, reason: ", warn[1]))
    },
    error = function(err) {
      message(paste("Unzipping ", shp_file_path, " failed, reason: ", warn[1]))
    }
  )
}

# Read shapefile
## TODO: Make more format agnostic??
shapefile <- st_read(shp_dir_unzipped)

# Read the function "map_shapefile_points" either from current working directory,
# or read the directory from config!
if ("map_shapefile_points.R" %in% list.files()){
  source("map_shapefile_points.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'map_shapefile_points.R'))
}


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
