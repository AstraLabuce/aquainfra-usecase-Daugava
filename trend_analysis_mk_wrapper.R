##############################################################################################.
## 5. trend_analysis Mann Kendall ####
##############################################################################################.
#RUN WITH
#Rscript trend_analysis_mk_wrapper.R "data_out_selected_interpolated.csv" "season, polygon_id" "Year_adj_generated" "Secchi_m_mean_annual" "mk_trend_analysis_results.csv"

library(jsonlite)


args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = args[1]
in_rel_cols = args[2] # e.g. "season, polygon_id"
in_time_colname = args[3]  # e.g. "Year_adj_generated"
in_value_colname = args[4] # e.g. "Secchi_m_mean_annual"
out_result_path = args[5]  # e.g. "mk_trend_analysis_results.csv"

# Remove spaces and split:
in_rel_cols = gsub(" ", "", in_rel_cols, fixed = TRUE)
in_rel_cols = strsplit(in_rel_cols, ",")[[1]] # e.g. "season, polygon_id"

# Read the input data from file:
data_list_subgroups <- data.table::fread(in_data_path)

# Read the function "trend_analysis_mk" either from current working directory,
# or read the directory from config!
if ("trend_analysis_mk.R" %in% list.files()){
  source("trend_analysis_mk.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'trend_analysis_mk.R'))
}

# Run the function "peri_conv"
out_mk <- trend_analysis_mk(data = data_list_subgroups,
                  rel_cols = in_rel_cols,
                  value_col = in_value_colname,
                  time_colname = in_time_colname)

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_mk , file = out_result_path) 