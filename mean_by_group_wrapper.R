##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## Can we use Datamash function for this in Galaxy workflows? ################################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the data analysis##################.
##############################################################################################.
## RUN WITH
## Rscript mean_by_group_wrapper.R "data_out_peri_conv.csv" "data_out_seasonal_means.csv"

library(jsonlite)

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
input_data_path = args[1]
in_cols_to_group_by = args[2] # e.g. "Year_adj_generated, group_labels, HELCOM_ID"
in_value = args[3] # e.g. "mean"
output_data_path = args[4]

# Read the input data from file - this can take a URL!
data_mean_by_group <- data.table::fread(input_data_path)

# Remove spaces and split:
in_cols_to_group_by = gsub(" ", "", in_cols_to_group_by, fixed = TRUE)
in_cols_to_group_by = strsplit(in_cols_to_group_by, ",")[[1]] # e.g. "season, polygon_id"


# Read the function "mean_by_group" either from current working directory,
# or read the directory from config!
if ("mean_by_group.R" %in% list.files()){
  source("mean_by_group.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'mean_by_group.R'))
}

# Run the function "mean_by_group"
out_means <- mean_by_group(data_mean_by_group,
    cols_to_group_by = in_cols_to_group_by, value = in_value)


# Write the result to csv file:
print(paste0('Write result to csv file: ', output_data_path))
data.table::fwrite(out_means , file = output_data_path) 