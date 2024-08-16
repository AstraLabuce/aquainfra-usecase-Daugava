##############################################################################################.
## 2. peri_conv : period converter ####
# function peri_conv - adds December to the next year (all winter months together)
                            # in the result every year starts at Dec-01. and ends Nov-30;
                            # generates num variable 'Year_adjusted' to show change;
                            # generates chr variable 'season' to allow grouping the data based on season.

#RUN WITH
#Rscript peri_conv_wrapper.R "data_out_point_att_polygon.csv" "visit_date" "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30" "winter,spring,summer,autumn" TRUE "data_out_peri_conv.csv"

library(lubridate)
library(dplyr)
library(jsonlite)


## Args
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = args[1] # e.g. "data_out_point_att_polygon.csv"
in_date_col_name = args[2] # e.g. "visit_date"
#in_group_to_periods = strsplit(args[3], ",")[[1]] # e.g. "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30"
in_group_to_periods = args[3] # e.g. "Dec-01:Mar-01, Mar-02:May-30, Jun-01:Aug-30, Sep-01:Nov-30"
#in_group_labels = strsplit(args[4], ",")[[1]] # e.g. "winter,spring,summer,autumn"
in_group_labels = args[4] # e.g. "winter, spring, summer, autumn"
in_year_starts_at_Dec1 = args[5] # e.g. "True" or "TRUE" or "true", will be parsed to Boolean
out_result_path = args[6]

# Remove spaces and split:
in_group_to_periods = gsub(" ", "", in_group_to_periods, fixed = TRUE) # e.g. "Dec-01:Mar-01, Mar-02:May-30, Jun-01:Aug-30, Sep-01:Nov-30"
in_group_to_periods = strsplit(in_group_to_periods, ",")[[1]]
in_group_labels = gsub(" ", "", in_group_labels, fixed = TRUE) # e.g. "winter, spring, summer, autumn"
in_group_labels = strsplit(in_group_labels, ",")[[1]]

# Read the input data from file:
data_peri_conv <- data.table::fread(in_data_path)

# Parse string to boolean:
if (tolower(in_year_starts_at_Dec1) == 'true') {
  in_year_starts_at_Dec1 <- TRUE
} else if (tolower(in_year_starts_at_Dec1) == 'false') {
  in_year_starts_at_Dec1 <- FALSE
} else {
  stop('Could not understand the value for "year_starts_at_Dec1" ("',
    in_year_starts_at_Dec1, '"), please provide "true" or "false".')
}

# Read the function "peri_conv" either from current working directory,
# or read the directory from config!
if ("peri_conv.R" %in% list.files()){
  source("peri_conv.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'peri_conv.R'))
}

# Run the function "peri_conv"
out_peri_conv <-
  peri_conv(
    data = data_peri_conv,
    date_col_name = in_date_col_name,
    group_to_periods = in_group_to_periods,
    group_labels = in_group_labels,
    year_starts_at_Dec1 = in_year_starts_at_Dec1
  )

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_peri_conv , file = out_result_path) 