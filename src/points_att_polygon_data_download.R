# data_download.R
input_data_dir <- "/in/"

# Define shapefile directory and path
url_parts_shp <- strsplit(in_shp_url, "/")[[1]]
shp_file_name <- url_parts_shp[length(url_parts_shp)]
shp_dir_zipped <- paste0(input_data_dir, "shp/")
shp_file_path <- paste0(shp_dir_zipped, shp_file_name)

# Ensure the shapefile directory exists, create if not
if (!dir.exists(shp_dir_zipped)) {
  success <- dir.create(shp_dir_zipped, recursive = TRUE)
  if (success) {
    print(paste0("Directory ", shp_dir_zipped, " created."))
  } else {
    stop(paste0("Directory ", shp_dir_zipped, " not created (failed)."))
  }
}

# Download shapefile if it doesn't exist
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

# Unzip shapefile if not already unzipped
shp_dir_unzipped <- paste0(shp_dir_zipped, sub("\\.zip$", "", shp_file_name))
if (!dir.exists(shp_dir_unzipped)) {
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
} else {
  print(paste0("Directory ", shp_dir_unzipped, " already exists. Skipping unzip."))
}

# Define directory and path for the data points file
in_situ_directory <- paste0(input_data_dir, "in_situ_data/")
url_parts_table <- strsplit(in_dpoints_url, "/")[[1]]
table_file_name <- url_parts_table[length(url_parts_table)]
table_file_path <- paste0(in_situ_directory, table_file_name)

# Ensure the in_situ_data directory exists, create if not
if (!dir.exists(in_situ_directory)) {
  success <- dir.create(in_situ_directory, recursive = TRUE)
  if (success) {
    print(paste0("Directory ", in_situ_directory, " created."))
  } else {
    print(paste0("Directory ", in_situ_directory, " not created."))
  }
}

# Download data file if it doesn't exist
if (!file.exists(table_file_path)) {
  tryCatch(
    {
      download.file(in_dpoints_url, table_file_path, mode = "wb")
      print(paste0("File ", table_file_path, " downloaded."))
    },
    warning = function(warn) {
      message(paste("Download of input table failed, reason: ", warn[1]))
    },
    error = function(err) {
      message(paste("Download of input table failed, reason: ", err[1]))
    }
  )
} else {
  print(paste0("File ", table_file_path, " already exists. Skipping download."))
}

# Define the data reading function
read_data <- function(table_file_path) {
  data_raw <- tryCatch(
    {
      data_raw <- NULL

      if (grepl("f=csv", table_file_path) | grepl("\\.csv$", table_file_path)) {
        data_raw <- read.csv(table_file_path) %>%
          janitor::clean_names()
        print(paste0("CSV file ", table_file_path, " read"))
      } else if (grepl("f=json", table_file_path) | grepl("\\.json$", table_file_path)) {
        data_raw <- st_read(table_file_path) %>%
          janitor::clean_names()
        print(paste0("GeoJSON file ", table_file_path, " read"))
      } else if (grepl("\\.xlsx$", table_file_path)) {
        data_raw <- readxl::read_excel(table_file_path) %>%
          janitor::clean_names()
        print(paste0("Excel file ", table_file_path, " read"))
      } else {
        stop("Unsupported file format: only CSV, JSON, or Excel accepted.")
      }

      if (!is.null(data_raw)) {
        if ("transparen" %in% colnames(data_raw)) {
          colnames(data_raw)[colnames(data_raw) == "transparen"] <- "transparency_m"
        }
        return(data_raw)
      } else {
        stop("data_raw is NULL: No data read.")
      }
    },
    error = function(err) {
      print(paste("Error:", err$message))
      return(NULL)
    }
  )
  return(data_raw)
}
