# Define directory and path for the data points file
in_situ_directory <- paste0(input_data_dir, "in_situ_data/")
table_file_name <- "input_data"
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

read_data <- function(table_file_path) {

  # Check file to guess format
  file_head <- readLines(table_file_path, n = 10, warn = FALSE)
  file_head <- file_head[nzchar(trimws(file_head))]  # remove empty lines
  first_line <- if (length(file_head) > 0) file_head[1] else ""

  format_guess <- if (grepl("^\\s*\\{", first_line) || grepl("^\\s*\\[", first_line)) {
    "json"
  } else if (grepl("^[^,]+(,[^,]+)+$", first_line)) {
    "csv"
  } else {
    "unknown"
  }

  message(paste("Guessed format:", format_guess))

  if (format_guess == "json") {
    data <- tryCatch({
      message("Trying GeoJSON...")
      sf::st_read(table_file_path, quiet = TRUE)
    }, error = function(e) NULL)

    if (!is.null(data)) return(data)
  }

  if (format_guess == "csv" || format_guess == "unknown") {
    data <- tryCatch({
      message("Trying CSV...")
      data.table::fread(table_file_path)
    }, error = function(e) NULL)

    if (!is.null(data)) return(data)
  }

  data <- tryCatch({
    message("Trying Excel...")
    readxl::read_excel(table_file_path)
  }, error = function(e) NULL)
  if (!is.null(data)) return(data)

  # Last resort: try reading as spatial (GeoJSON, shapefile, etc.)
  data <- tryCatch({
    message("Trying spatial format (sf)...")
    sf::st_read(table_file_path, quiet = TRUE)
  }, error = function(e) NULL)
  if (!is.null(data)) return(data)

  stop("Could not detect or read the file format.")
}
