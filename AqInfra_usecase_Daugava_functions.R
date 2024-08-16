### Aquainfra project
### This project has received funding from the European Commission?s Horizon
#### Europe Research and Innovation programme under grant agreement No 101094434.

### WP5 Use case: Baltic Sea Daugava-Gulf of Riga: shapefile attributes as grouping parameter
### Latvian Institute of Aquatic Ecology

# working directory ####
# automatic setting wd to the folder where current script file is
#current_path = rstudioapi::getActiveDocumentContext()$path
#setwd(dirname(current_path))

## Args <- args use is not clear for me (Comment by Astra)
##args <- commandArgs(trailingOnly = TRUE)
##print(paste0('R Command line args: ', args))
# 1. point att polygon:
in_shp_path = "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp"
in_dpoints_path = "in_situ_data/in_situ_example.xlsx"
in_long_col_name = "longitude"
in_lat_col_name = "latitude"
result_path_point_att_polygon <- "data_out_point_att_polygon.csv"
# 2. peri_conv
in_date_col_name = "visit_date"
in_group_to_periods = c("Dec-01:Mar-01", "Mar-02:May-30", "Jun-01:Aug-30", "Sep-01:Nov-30")
#default season division; # do not put Feb-29th, if needed then choose Mar-01
in_group_labels = c("winter", "spring", "summer", "autumn")
in_year_starts_at_Dec1 = TRUE
result_path_peri_conv <- "data_out_peri_conv.csv"
# 3. mean by group / seasonal means:
result_path_seasonal_means <- "data_out_seasonal_means.csv"
# 4. ts_selection_interpolation
in_rel_cols_ts = c("group_labels", "HELCOM_ID")
in_missing_threshold_percentage = 40
in_year_colname = "Year_adj_generated"
in_value_colname = "Secchi_m_mean_annual"
in_min_data_point = 10
result_path_selected_interpolated = "data_out_selected_interpolated.csv"
# 5. mk_trend_analysis
in_rel_cols_mk = c("season", "polygon_id")
in_time_colname = "Year_adj_generated"
in_value_colname = "Secchi_m_mean_annual"
result_path_trend_analysis_mk = "mk_trend_analysis_results.csv"
# 6.1 vis: map_shapefile_points
in_long_col_name_vis = "longitude"
in_lat_col_name_vis = "latitude"
in_value_name_vis = "transparency_m"
in_region_col_name = "HELCOM_ID"
result_url_map_shapefile_points = "map_shapefile_insitu.html"
# 6.2 vis: barplot_trend_results
in_id_col = "polygon_id"
in_test_value = "Tau_Value"
in_p_value_col = "P_Value"
in_p_value_threshold = "0.05"
in_group = "season"
result_path_barplot_trend_results = "barplot_trend_results.png"
# 6.3 vis: map_trends_interactive
in_id_trend_col = "polygon_id"
in_id_shp_col = "HELCOM_ID"
result_path_map_trends_interactive = "map_trend_results.html"
# 6.4: static map
#result_path_static_map_html = "map_trend_results.html" # not used
result_path_static_map_png = "map_trend_results.png"

## Imports
#library(rgdal) # Outdated! See: https://cloud.r-project.org/web/packages/rgdal/index.html
library(sf)
library(janitor)
library(dplyr)

## Read input files
## TODO: Make more format agnostic??
#shapefile <- rgdal::readOGR(in_shp_path) #"SpatialPolygonsDataFrame"
shapefile <- sf::st_read(in_shp_path)

# locate in situ data set manually
# load in situ data and respective metadata (geolocation and date are mandatory metadata)
# example data
data_raw <- readxl::read_excel(in_dpoints_path) %>% #example data from https://latmare.lhei.lv/
  janitor::clean_names() # makes column names clean for R

#############.
# this is for our local full data set
#data_raw <-
 # readxl::read_excel("in_situ_data/Latmare_20240111_secchi_color.xlsx") %>% #datafvrom LIAE data base from https://latmare.lhei.lv/
  #janitor::clean_names() # makes column names clean for R
#############.

#list relevant columns: geolocation (lat and lon), date and values for data points are mandatory
rel_columns <- c(
  "longitude",
  "latitude",
  "visit_date",
  "transparency_m",
  "color_id" #water color hue in Furel-Ule (categories)
)

# relevant data
data_rel <- data_raw %>%
  #select only relevant columns
  dplyr::select(all_of(rel_columns)) %>%
  # remove cases when Secchi depth, water colour were not measured
  filter(
    !is.na(`transparency_m`) &
      !is.na(`color_id`) &
      !is.na(`longitude`) &
      !is.na(`latitude`)
  ) # make sure to use correct column names

# set coordinates ad numeric (in case they are read as chr variables)
data_rel <- data_rel %>%
  mutate(
    longitude  = as.numeric(longitude),
    latitude   = as.numeric(latitude),
    transparency_m = as.numeric(transparency_m)
  )
#write.csv(data_rel, file = "data_WP5_DaugavaUseCase_input.csv", row.names = FALSE) # this should be made available to DDAS

# Data shouold be available at least in the test DDAS environment!
# !! In AquaInfra DDAS data is available in geojson format. 
## Need a function to transform geojson to tabular!! Or maybe there is something availabe in Galaxy already?

############################################################################################.

# FUNCTIONS for Galaxy ####

############################################################################################.
## 1. points_att_polygon ####
# function points_att_polygon - data points merged with polygon attributes based on data point location


# Read the function "points_att_polygon" from current working directory:
if ("points_att_polygon.R" %in% list.files()){
  source("points_att_polygon.R")
} else {
  warning('Could not find file "points_att_polygon.R" in current working dir!')
}

# Call the function:
print('Running points_att_polygon')
out_points_att_polygon <- points_att_polygon(
  shp = shapefile, 
  dpoints = data_rel, 
  long_col_name = in_long_col_name, 
  lat_col_name = in_lat_col_name)

# Write the result to csv file:
print(paste0('Write result to csv file: ', result_path_point_att_polygon))
data.table::fwrite(out_points_att_polygon, file = result_path_point_att_polygon) 


##############################################################################################.
## 2. peri_conv : period converter ####
# function peri_conv - adds December to the next year (all winter months together)
                            # in the result every year starts at Dec-01. and ends Nov-30;
                            # generates num variable 'Year_adjusted' to show change;
                            # generates chr variable 'season' to allow grouping the data based on season.

data_peri_conv <- data.table::fread(result_path_point_att_polygon)

# Read the function "peri_conv" from current working directory:
if ("peri_conv.R" %in% list.files()){
  source("peri_conv.R")
} else {
  warning('Could not find file "peri_conv.R" in current working dir!')
}

# Call the function:
print('Running peri_conv...')
out_peri_conv <-
  peri_conv(
    data = data_peri_conv,
    date_col_name = in_date_col_name,
    group_to_periods = in_group_to_periods,
    group_labels = in_group_labels,
    year_starts_at_Dec1 = in_year_starts_at_Dec1
  )

# Write the result to csv file:
print(paste0('Write result to csv file: ', result_path_peri_conv))
data.table::fwrite(out_peri_conv , file = result_path_peri_conv) 

##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## Can we use Datamash function for this in Galaxy workflows? ################################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the data analysis##################.
##############################################################################################.

library(magrittr)
library(dplyr)

data_mean_by_group <- data.table::fread(result_path_peri_conv)

data_mean_by_group$transparency_m <- as.numeric(data_mean_by_group$transparency_m)

# Call the function:
print('Running mean by group...')
out_seasonal_means <- data_mean_by_group %>%
  group_by(longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean = mean(transparency_m)) %>%
  ungroup() %>% 
  group_by(Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean_annual = mean(Secchi_m_mean)) %>%
  ungroup()


# Write the result to csv file:
print(paste0('Write result to csv file: ', result_path_seasonal_means))
data.table::fwrite(out_seasonal_means , file = result_path_seasonal_means) 


##############################################################################################.
## 4. TimeSeries selection and interpolation of NAs ####
##############################################################################################.

data_list_subgroups <- data.table::fread(result_path_seasonal_means)

# split data into sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency

# Read the function "ts_selection_interpolation" from current working directory:
if ("ts_selection_interpolation.R" %in% list.files()){
  source("ts_selection_interpolation.R")
} else {
  warning('Could not find file "ts_selection_interpolation.R" in current working dir!')
}

# Call the function:
print('Running ts_selection_interpolation...')
out_ts <- ts_selection_interpolation(
  data = data_list_subgroups, 
  rel_cols = in_rel_cols_ts, 
  missing_threshold = in_missing_threshold_percentage, 
  year_col = in_year_colname,
  value_col = in_value_colname,
  min_data_point = in_min_data_point)

# Write the result to csv file:
print(paste0('Write result to csv file: ', result_path_selected_interpolated))
data.table::fwrite(out_ts , file = result_path_selected_interpolated) 


##############################################################################################.
## 5. trend_analysis Mann Kendall ####
##############################################################################################.

data_list_subgroups <- data.table::fread(result_path_selected_interpolated)


# Read the function "trend_analysis_mk" from current working directory:
if ("trend_analysis_mk.R" %in% list.files()){
  source("trend_analysis_mk.R")
} else {
  warning('Could not find file "trend_analysis_mk.R" in current working dir!')
}

# Call the function:
print('Running trend_analysis_mk...')
out_mk <- trend_analysis_mk(data = data_list_subgroups,
                  rel_cols = in_rel_cols_mk,
                  value_col = in_value_colname,
                  time_colname = in_time_colname)

# Write the result to csv file:
print(paste0('Write result to csv file: ', result_path_trend_analysis_mk))
data.table::fwrite(out_mk , file = result_path_trend_analysis_mk) 
    
################################################################################.
## 6. visualization ####
################################################################################.

print('Running visualisations...')


### 6.1. map: shp + dpoints ####

print('Running visualisation 1: map_shapefile_points ...')

dpoints <- data.table::fread(result_path_point_att_polygon)
#shapefile <- sf::st_read(in_shp_path) # not required to repeat if run in one long script.

# Read the function "map_shapefile_points" from current working directory:
if ("map_shapefile_points.R" %in% list.files()){
  source("map_shapefile_points.R")
} else {
  warning('Could not find file "map_shapefile_points.R" in current working dir!')
}

# Call the function:
print('Running map_shapefile_points...')
map_out <- map_shapefile_points(shp = shapefile, 
                                 dpoints = dpoints,
                                 long_col_name = in_long_col_name_vis,
                                 lat_col_name = in_lat_col_name_vis,
                                 value_name = in_value_name_vis, 
                                 region_col_name = in_region_col_name)


# Write the result to url file (!?):
print(paste0('Save map to html: ', result_url_map_shapefile_points))
tryCatch(
  {
    mapview::mapshot(map_out, url = result_url_map_shapefile_points)
    print(paste0("Map saved to ", result_url_map_shapefile_points))
  },
  warning = function(warn) {
    message(paste("Saving HTML failed, reason: ", warn[1]))
    print('Trying with selfcontained=FALSE:')
    mapview::mapshot(map_out, url = result_url_map_shapefile_points, selfcontained=FALSE)
    print(paste0("Map saved to ", result_url_map_shapefile_points))
  },
  error = function(err) {
    message(paste("Saving HTML failed, reason: ", err[1]))
    print('Trying with selfcontained=FALSE:')
    mapview::mapshot(map_out, url = result_url_map_shapefile_points, selfcontained=FALSE)
    print(paste0("Map saved to ", result_url_map_shapefile_points))
  }
)
#browseURL(result_url_map_shapefile_points)



### 6.2. barplot of trend analysis ####

print('Running visualisation 2: barplot_trend_results ...')

data_list_subgroups <- data.table::fread(result_path_trend_analysis_mk)
library(ggplot2)

# Read the function "barplot_trend_results" from current working directory:
if ("barplot_trend_results.R" %in% list.files()){
  source("barplot_trend_results.R")
} else {
  warning('Could not find file "barplot_trend_results.R" in current working dir!')
}

# Call the function:
#plot the result for transparency
barplot_trends <- barplot_trend_results(data = data_list_subgroups,
                      id = in_id_col,
                      test_value = in_test_value,
                      p_value = in_p_value_col,
                      p_value_threshold = in_p_value_threshold,
                      group = in_group)

# Write the result to csv file:
print(paste0('Write result to image file: ', result_path_barplot_trend_results))
ggsave(barplot_trends , file = result_path_barplot_trend_results, dpi = 300) 


### 6.3. trend result map ####

print('Running visualisation 3: map_trends_interactive ...')

# plot a map of trend results
### interactive map

data <- data.table::fread(result_path_trend_analysis_mk)
#shapefile <- sf::st_read(in_shp_path) # not required to repeat if run in one long script.

library(tmap)
library(tmaptools)

# Read the function "map_trends_interactive" from current working directory:
if ("map_trends_interactive.R" %in% list.files()){
  source("map_trends_interactive.R")
} else {
  warning('Could not find file "map_trends_interactive.R" in current working dir!')
}

# Call the function:
map_out <- map_trends_interactive(shp = shapefile, 
                                  data = data,
                                  id_trend_col = in_id_trend_col,
                                  id_shp_col = in_id_shp_col,
                                  p_value_threshold = in_p_value_threshold,
                                  p_value_col = in_p_value_col,
                                  group = in_group)

## TODO: I cannot find a way how to save faceted interactive maps..
## Output: Now need to store output:
print(paste0('Save map to html: ', result_path_map_trends_interactive))
print('NOT STORING THIS RESULT. TODO.')
#saveWidget(map_out, result_path_map_trends_interactive) # not working
#tmap_save(map_out, result_path_map_trends_interactive) # not working
#mapview::mapshot(map_out, result_path_map_trends_interactive) # not working
#htmltools::save_html(map_out, result_path_map_trends_interactive) #not working

###
### static map
###

print('Running visualisation 4: map_trends_static ...')

data <- data.table::fread(result_path_trend_analysis_mk)
#shapefile <- sf::st_read(in_shp_path) # not required to repeat if run in one long script.

library(tmap)
library(tmaptools)
library(rosm)
library(sf)

# Read the function "map_trends_static" from current working directory:
if ("map_trends_static.R" %in% list.files()){
  source("map_trends_static.R")
} else {
  warning('Could not find file "map_trends_static.R" in current working dir!')
}

map_out_static <- map_trends_static(shp = shapefile, 
                                  data = data,
                                  id_trend_col = in_id_trend_col,
                                  id_shp_col = in_id_shp_col,
                                  p_value_threshold = in_p_value_threshold,
                                  p_value_col = in_p_value_col,
                                  group = in_group)


## Output: Now need to store output:
#print(paste0('Save map to html: ', result_path_static_map_html))
print(paste0('Save map to png: ', result_path_static_map_png))
tmap_save(map_out_static, result_path_static_map_png)

print('Done!')

########################################.






