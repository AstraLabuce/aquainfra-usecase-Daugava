### 6.2. barplot of trend analysis ####

library(ggplot2)

## Run:
## Rscript barplot_trend_results_wrapper.R "mk_trend_analysis_results.csv" "polygon_id" "Tau_Value" "P_Value" "0.05" "season" "barplot_trend_results.png"

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path <- args[1] # e.g. "mk_trend_analysis_results.csv"
in_id_col <- args[2] # e.g. "polygon_id"
in_test_value <- args[3] # e.g. "Tau_Value"
in_p_value <- args[4] # e.g. "P_Value"
in_p_value_threshold <- args[5] # e.g. "0.05"
in_group <- args[6] # e.g. "season"
out_result_path <- args[7] # e.g. "barplot_trend_results.png"

data_list_subgroups <- data.table::fread(in_data_path)

# Read the function "barplot_trend_results" either from current working directory,
# or read the directory from config!
if ("barplot_trend_results.R" %in% list.files()){
  source("barplot_trend_results.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'barplot_trend_results.R'))
}

# Call the function:
#plot the result for transparency
barplot_trends <- barplot_trend_results(data = data_list_subgroups,
                      id = in_id_col,
                      test_value = in_test_value,
                      p_value = in_p_value,
                      p_value_threshold = in_p_value_threshold,
                      group = in_group)

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
ggsave(barplot_trends , file = out_result_path, dpi = 300) 