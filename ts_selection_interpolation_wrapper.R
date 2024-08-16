##############################################################################################.
## 4. TimeSeries selection and interpolation of NAs ####
##############################################################################################.
## RUN WITH
## Rscript ts_selection_interpolation_wrapper.R "data_out_seasonal_means.csv" "group_labels,HELCOM_ID" 40 "Year_adj_generated" "Secchi_m_mean_annual" 10 "data_out_selected_interpolated.csv"

library(jsonlite)

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = args[1]
in_rel_cols = args[2] # e.g. "season, polygon_id"
in_missing_threshold_percentage = as.numeric(args[3])
in_year_colname = args[4]
in_value_colname = args[5]
in_min_data_point = as.numeric(args[6])
out_result_path = args[7]

# Remove spaces and split:
in_rel_cols = gsub(" ", "", in_rel_cols, fixed = TRUE) # e.g. "season, polygon_id"
in_rel_cols = strsplit(in_rel_cols, ",")[[1]]

# Read the input data from file:
data_list_subgroups <- data.table::fread(in_data_path)

# Read the function "ts_selection_interpolation" either from current working directory,
# or read the directory from config!
if ("ts_selection_interpolation.R" %in% list.files()){
  source("ts_selection_interpolation.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'ts_selection_interpolation.R'))
}

# Run the function "ts_selection_interpolation"
out_ts <- ts_selection_interpolation(
  data = data_list_subgroups, 
  rel_cols = in_rel_cols, 
  missing_threshold = in_missing_threshold_percentage, 
  year_col = in_year_colname,
  value_col = in_value_colname,
  min_data_point = in_min_data_point)

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_ts , file = out_result_path) 