################################################################################.
## 6. visualization ####
################################################################################.

## Run:
## Rscript map_shapefile_points_wrapper.R "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp" "data_out_point_att_polygon.csv" "longitude" "latitude" "transparency_m" "HELCOM_ID" "map_shapefile_insitu.html"
## Rscript map_shapefile_points_wrapper.R "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp" "data_out_point_att_polygon.csv" "longitude" "latitude" "transparency_m" "HELCOM_ID" "map_shapefile_insitu.html"

### 6.1. map: shp + dpoints ####

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path <- args[1]      # e.g. "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_dpoints_path <- args[2]  # e.g. "data_out_point_att_polygon.csv"
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

# Read input data
dpoints <- data.table::fread(in_dpoints_path)
in_shp_path <- paste0(input_data_dir, in_shp_path)
shapefile <- sf::st_read(in_shp_path)

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
