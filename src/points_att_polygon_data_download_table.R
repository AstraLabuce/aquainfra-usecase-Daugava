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
