# Define shapefile directory and path
#input_data_dir <- get("input_data_dir", ifnotfound = "./")
if (!exists("input_data_dir")) stop("input_data_dir must be defined before running this script.")
regions_directory <- paste0(input_data_dir, "shp/")
shp_file_name <- "input_data_regions.zip"
regions_path <- paste0(regions_directory, shp_file_name)

# Ensure the shapefile directory exists, create if not
if (!dir.exists(regions_directory)) {
  success <- dir.create(regions_directory, recursive = TRUE)
  if (success) {
    print(paste0("Directory ", regions_directory, " created."))
  } else {
    stop(paste0("Directory ", regions_directory, " not created (failed)."))
  }
}

# Download shapefile
tryCatch(
  {
    download.file(in_shp_url, regions_path, mode = "wb")
    print(paste0("File ", regions_path, " downloaded."))
  },
  warning = function(warn) {
    stop(paste("Download of shapefile failed, reason: ", warn[1]))
  },
  error = function(err) {
    stop(paste("Download of shapefile failed, reason: ", err[1]))
  }
)

# Unzip shapefile if not already unzipped
shp_dir_unzipped <- paste0(regions_directory, "input_data_regions")

tryCatch(
  {
    unzip(regions_path, exdir = shp_dir_unzipped)
    print(paste0("Unzipped to directory ", shp_dir_unzipped))
  },
  warning = function(warn) {
    message(paste("Error: Unzipping ", regions_path, " failed, reason: ", warn[1]))
  },
  error = function(err) {
    message(paste("Error: Unzipping ", regions_path, " failed, reason: ", warn[1]))
  }
)
