
###
### static map
###

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path <- args[1] # e.g. "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_trend_results_path <- args[2] # e.g. "mk_trend_analysis_results.csv"
in_id_trend_col <- args[3] # e.g. "polygon_id"
in_id_shp_col <- args[4] # e.g. "HELCOM_ID"
in_group <- args[5] # e.g. "season"
in_p_value_col <- args[6] # e.g. "P_Value"
in_p_value_threshold <- args[7] # e.g. "0.05"
#out_result_path_url <- args[8] # e.g. "map_trend_results.html" #  not used
out_result_path_png <- args[8] # e.g. "map_trend_results.png"

data <- data.table::fread(in_trend_results_path)
shapefile <- sf::st_read(in_shp_path)

library(tmap)
library(tmaptools)
library(rosm)
library(sf)

# Read the function "map_trends_static" either from current working directory,
# or read the directory from config!
if ("map_trends_static.R" %in% list.files()){
  source("map_trends_static.R")
} else {
  config_file_path <- Sys.getenv("DAUGAVA_CONFIG_FILE", "./config.json")
  print(paste0("Path to config file: ", config_file_path))
  config_data <- fromJSON(config_file_path)
  r_script_dir <- config_data["r_script_dir"]
  source(file.path(r_script_dir, 'map_trends_static.R'))
}

map_out_static <- map_trends_static(shp = shapefile, 
                                  data = data,
                                  id_trend_col = in_id_trend_col,
                                  id_shp_col = in_id_shp_col,
                                  p_value_threshold = in_p_value_threshold,
                                  p_value_col = in_p_value_col,
                                  group = in_group)


## Output: Now need to store output:
#print(paste0('Save map to html: ', out_result_path_url))
print(paste0('Save map to png: ', out_result_path_png))
tmap_save(map_out_static, out_result_path_png)

########################################.



