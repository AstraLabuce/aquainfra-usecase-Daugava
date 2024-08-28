### 6.3. trend result map ####
# plot a map of trend results
### interactive map

library(tmap)
library(tmaptools)
library(sf)

## Run:
## Rscript map_trends_interactive_wrapper.R "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp" "mk_trend_analysis_results.csv" "polygon_id" "HELCOM_ID" "season" "P_Value" "0.05" "map_trends_interactive.html"

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_url <- args[1] # e.g. "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_trend_results_path <- args[2] # e.g. "mk_trend_analysis_results.csv"
in_id_trend_col <- args[3] # e.g. "polygon_id"
in_id_shp_col <- args[4] # e.g. "HELCOM_ID"
in_group <- args[5] # e.g. "season"
in_p_value_col <- args[6] # e.g. "P_Value"
in_p_value_threshold <- args[7] # e.g. "0.05"
out_result_path <- args[8] # e.g. "map_trends_interactive.html" --> not used, not writing any output...

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
data <- data.table::fread(in_trend_results_path)
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

# Read the function "map_trends_interactive" either from current working directory,
# or read the directory from config!
if ("map_trends_interactive.R" %in% list.files()){
  source("map_trends_interactive.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'map_trends_interactive.R'))
}

# Call the function:
map_out <- map_trends_interactive(shp = shapefile, 
                                  data = data,
                                  id_trend_col = in_id_trend_col,
                                  id_shp_col = in_id_shp_col,
                                  p_value_threshold = in_p_value_threshold,
                                  p_value_col = in_p_value,
                                  group = in_group)

## TODO: I cannot find a way how to save faceted interactive maps..
## Output: Now need to store output:
print(paste0('Save map to html: ', out_result_path))
print('NOT STORING THIS RESULT. TODO.')
#saveWidget(map_out, out_result_path) # not working
#tmap_save(map_out, out_result_path) # not working
#mapview::mapshot(map_out, out_result_path) # not working
#htmltools::save_html(map_out, out_result_path) #not working
