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

## Imports
#library(rgdal) # Outdated! See: https://cloud.r-project.org/web/packages/rgdal/index.html
library(sf)
library(janitor)
library(dplyr)

## Read input files
## TODO: Make more format agnostic??
#shapefile <- rgdal::readOGR(in_shp_path) #"SpatialPolygonsDataFrame"
shapefile <- st_read(in_shp_path)

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

#TBC

