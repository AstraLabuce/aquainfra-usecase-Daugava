###
### static map
###

library(tmap)
library(tmaptools)
library(rosm)
library(sf)
library(jsonlite)

map_trends_static <- function(shp, data, 
                                   id_trend_col = "id",
                                   id_shp_col = "id",
                                   p_value_threshold = 0.05,
                                   p_value_col = "p_value",
                                   group = "group") {
  
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package \"sf\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("tmap", quietly = TRUE)) {
    stop("Package \"tmap\" must be installed to use this function.",
         call. = FALSE)
  }
  if (missing(shp))
    stop("missing shp")
  if (missing(data))
    stop("missing data")
  
  shp_subset <- 
    shp[subset(shp, select = names(shp) == id_shp_col)[[1]] %in% subset(data, select = names(data) == id_trend_col)[[1]],]
  
  names(shp_subset)[which(names(shp_subset) == id_shp_col)] <- "polygon_id"
  names(data)[which(names(data) == id_trend_col)] <- "polygon_id"
  
  shp_trend <- merge(shp_subset, data)
  shp_trend$significant <- shp_trend$P_Value <= p_value_threshold
  shp_trend$decreasing_trend <- shp_trend$Tau_Value <= 0
  shp_trend$trend_res <- "insig.trend"
  
  for (each in seq(nrow(shp_trend))){
    if (shp_trend[each,]$significant == TRUE & shp_trend[each,]$Tau_Value <= 0) {
      shp_trend[each,]$trend_res <- "sig.decrease"
    }else if(shp_trend[each,]$significant == TRUE & shp_trend[each,]$Tau_Value > 0){
      shp_trend[each,]$trend_res <- "sig.increase"} 
  }
  
  shp_trend <- sf::st_transform(shp_trend, 4326)
  
  bg = rosm::osm.raster(shp_trend, zoomin = -1, crop = TRUE)
  tmap_mode("plot")
  tm_shape(bg) +
    tm_rgb() +
    tm_shape(shp_trend)+
    tm_polygons("trend_res", 
                alpha = 0.85, 
                title = "result of trend analysis",
                colorNA = NULL, 
                colorNULL = NULL, 
                textNA = "not tested") +
    tm_facets(by = group, sync = TRUE)+
    tm_tiles("Stamen.TonerLabels")
}

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_url <- args[1]      # e.g. "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip"
in_trend_results_path_or_url <- args[2] # e.g. "https://..../mk_trend_analysis_results.csv"
in_id_trend_col <- args[3] # e.g. "polygon_id"
in_id_shp_col <- args[4] # e.g. "HELCOM_ID"
in_group <- args[5] # e.g. "season"
in_p_value_col <- args[6] # e.g. "P_Value"
in_p_value_threshold <- args[7] # e.g. "0.05"
#out_result_path_url <- args[8] # e.g. "map_trend_results.html" #  not used
out_result_path_png <- args[8] # e.g. "map_trend_results.png"

# Read the input data from file - this can take a URL!
data <- data.table::fread(in_trend_results_path_or_url)

source("points_att_polygon_data_download_shp.R")

shapefile <- st_read(shp_dir_unzipped)

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