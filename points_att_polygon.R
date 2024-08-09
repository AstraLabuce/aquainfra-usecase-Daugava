############################################################################################.
## 1. points_att_polygon ####
# function points_att_polygon - data points merged with polygon attributes based on data point location

#RUN WITH
# Rscript points_att_polygon.R "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip" "https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx" "longitude" "latitude" "data_out_point_att_polygon.csv"

library(sf)
library(magrittr)
library(dplyr)
library(janitor)
library(sp)
library(data.table)
library(jsonlite)

config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
print(paste0("Path to config file: ", config_file_path))

# Get input data directory:
# If config json exists, read from there, otherwise ./
if (file.exists(config_file_path)) {
  config_data <- fromJSON(config_file_path)
  print("Config file loaded successfully.")
  input_data_dir <- config_data["input_data_dir"]
  print(paste("The value of 'input_data_dir' is:", input_data_dir))
} else {
  print("Config file not found. Input directory set to directory ./")
  input_data_dir <- "./"
}

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_url <- args[1]
in_dpoints_url <- args[2]
in_long_col_name <- args[3]
in_lat_col_name <- args[4]
out_result_path <- args[5]

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
    print(paste0("Directory ", shp_dir_zipped, " not created."))
  }
}

# Download shapefile if it doesn't exist:
if (!file.exists(shp_file_path)) {
  tryCatch(
    {
      download.file(in_shp_url, shp_file_path, mode = "wb")
      print(paste0("File ", shp_file_path, " downloaded."))
    },
    warning = function(warn) {
      message(paste("Download of shapefile failed, reason: ", warn[1]))
    },
    error = function(err) {
      message(paste("Download of shapefile failed, reason: ", err[1]))
    }
  )
} else {
  print(paste0("File ", shp_file_path, " already exists. Skipping download."))
}

# Unzip shapefile if it is not unzipped yet:
shp_dir_unzipped <- paste0(shp_dir_zipped, sub("\\.zip$", "", shp_file_name))
if (!dir.exists(shp_dir_unzipped)) {
  unzip(shp_file_path, exdir = shp_dir_unzipped)
  print(paste0("Unzipped to directory ", shp_dir_unzipped))
} else {
  print(paste0("Directory ", shp_dir_unzipped, " already exists. Skipping unzip."))
}

# Read shapefile
shapefile <- st_read(shp_dir_unzipped)

# Define the directory and local file path for the Excel file
in_situ_directory <- paste0(input_data_dir, "in_situ_data/")
url_parts_excel <- strsplit(in_dpoints_url, "/")[[1]]
excel_file_name <- url_parts_excel[length(url_parts_excel)]
excel_file_path <- paste0(in_situ_directory, excel_file_name)

# Ensure the in_situ_data directory exists, create if not
if (!dir.exists(in_situ_directory)) {
  success <- dir.create(in_situ_directory, recursive = TRUE)
  if (success) {
    print(paste0("Directory ", in_situ_directory, " created."))
  } else {
    print(paste0("Directory ", in_situ_directory, " not created."))
  }
}

# Download excel if it doesn't exist:
print(paste0('Checking if excel file exists: ', excel_file_path))
if (!file.exists(excel_file_path)) {
  tryCatch(
    {
      download.file(in_dpoints_url, excel_file_path, mode = "wb")
      print(paste0("File ", excel_file_path, " downloaded."))
    },
    warning = function(warn) {
      message(paste("Download of excel failed, reason: ", warn[1]))
    },
    error = function(err) {
      message(paste("Download of excel failed, reason: ", err[1]))
    }
  )
} else {
  print(paste0("File ", excel_file_path, " already exists. Skipping download."))
}

# Read excel file
data_raw <- readxl::read_excel(excel_file_path) %>%
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