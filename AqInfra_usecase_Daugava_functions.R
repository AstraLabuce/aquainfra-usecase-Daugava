### Aquainfra project
### This project has received funding from the European Commission?s Horizon
#### Europe Research and Innovation programme under grant agreement No 101094434.

### WP5 Use case: Baltic Sea Daugava-Gulf of Riga: shapefile attributes as grouping parameter
### Latvian Institute of Aquatic Ecology

# working directory ####
# automatic setting wd to the folder where current script file is
current_path = rstudioapi::getActiveDocumentContext()$path
setwd(dirname(current_path))

## Args <- args use is not clear for me (Comment by Astra)
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path = "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_dpoints_path = "in_situ_data/in_situ_example.xlsx"
in_long_col_name = "longitude"
in_lat_col_name = "latitude"
out_result_path = "data_out_point_att_polygon.csv"

## How to call this from command line:
#PATH_SHP="/home/.../test_inputs/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp"
#PATH_XLSX="/home/.../test_inputs/in_situ_example.xlsx"
#PATH_OUT="/home/.../test_outputs/mytestoutput.csv"
#/usr/bin/Rscript --vanilla /home/.../points_att_polygon.R ${PATH_SHP} ${PATH_XLSX} "longitude" "latitude" ${PATH_OUT}

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


points_att_polygon <- function(shp, dpoints, long_col_name="long", lat_col_name="lat") {
  #shp - shapefile
  #dpoints - dataframe with values and numeric variables for coordinates:
  #long - longitude column name in dpoints; default "long"
  #lat - latitude column name in dpoints; default "lat"
  
  if (!requireNamespace("sp", quietly = TRUE)) {
    stop("Package \"sp\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package \"sf\" must be installed to use this function.",
         call. = FALSE)
  }
  
  if (missing(shp))
    stop("missing shp")
  if (missing(dpoints))
    stop("missing dpoints")
  if (! long_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", long_col_name))
  if (! lat_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", lat_col_name))
  
  err = paste0("Error: `", long_col_name, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == long_col_name]))
  err = paste0("Error: `", lat_col_name, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == lat_col_name]))
  
  #dpoints to spatial
  print('Making input data spatial based on long, lat...')
  data_spatial <- sf::st_as_sf(dpoints, coords = c(long_col_name, lat_col_name))
  # set to WGS84 projection
  print('Setting to WGS84 CRS...')
  sf::st_crs(data_spatial) <- 4326

  ## First, convert from WGS84-Pseudo-Mercator to pure WGS84
  print('Setting geometry data to same CRS...')
  shp_wgs84 <- st_transform(shp, st_crs(data_spatial))
  
  ## Check and fix geometry validity
  print('Check if geometries are valid...')# TODO: Check actually needed? Maybe just make valid!
  if (!all(st_is_valid(shp_wgs84))) { # many are not (in the example data)!
    print('They are not! Making valid...')
    shp_wgs84 <- st_make_valid(shp_wgs84)  # slowish...
    print('Making valid done.')
  }
  
  ## Overlay shapefile and in situ locations
  print(paste0('Computing the intersection... This will take a while. ',
               'Starting at ', Sys.time()))
  shp_wgs84 <- st_filter(shp_wgs84, data_spatial) 
  data_shp <- st_join(shp_wgs84, data_spatial)
  #drop geometry to faster use of the object
  data_shp <- sf::st_drop_geometry(data_shp)
  print(paste0('Done computing the intersection... Finished at ', Sys.time()))
  
  # merge shapefile attributes to in situ data.frame - as geometry dropped, coordinates are lacking
  res <- full_join(dpoints, data_shp)
  rm(data_spatial)
  res

}

#test the function points_att_polygon
## Call the function:
out_points_att_polygon <- points_att_polygon(
  shp = shapefile, 
  dpoints = data_rel, 
  long_col_name = in_long_col_name, 
  lat_col_name = in_lat_col_name)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_points_att_polygon, file = out_result_path) 


##############################################################################################.
## 2. peri_conv : period converter ####
# function peri_conv - adds December to the next year (all winter months together)
                            # in the result every year starts at Dec-01. and ends Nov-30;
                            # generates num variable 'Year_adjusted' to show change;
                            # generates chr variable 'season' to allow grouping the data based on season.

## Args <- Args use is not clear for me (comment by Astra)
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = "data_out_point_att_polygon.csv"
in_date_col_name = "visit_date"
in_group_to_periods = #default season division; # do not put Feb-29th, if needed then choose Mar-01
  c("Dec-01:Mar-01", "Mar-02:May-30", "Jun-01:Aug-30", "Sep-01:Nov-30")
in_group_labels = c("winter", "spring", "summer", "autumn")
in_year_starts_at_Dec1 = TRUE
out_result_path = "data_out_peri_conv.csv"


data_peri_conv <- data.table::fread(in_data_path)


peri_conv <-
  function(data,
           date_col_name,
           group_to_periods = #default season division; # do not put Feb-29th, if needed then choose Mar-01
             c("Dec-01:Mar-01", "Mar-02:May-30", "Jun-01:Aug-30", "Sep-01:Nov-30"),
           group_labels = #default = group_to_periods
             group_to_periods, #if defined, should be the same length as group_to_periods
           year_starts_at_Dec1 = TRUE #default
           ) {
    #data - dataset with columns for Year and Month (all the rest variables stays the same)
    #Date - column name to Date in format YYYY-MM-DD; Year, Month, Day, Year_adj - will be generated
    #group_to_periods <- group into periods: define the periods, e.g., mmm-DD:mmm-DD, Mar-15:Jun-01.
    if (!requireNamespace("lubridate", quietly = TRUE)) {
      stop("Package \"lubridate\" must be installed to use this function.",
           call. = FALSE)
    }
  
    if (missing(data))
      stop("missing data")
    suppressWarnings(if (!unique(!is.na(as.Date(
      get(date_col_name, data), "%Y-%m-%d"
    ))))
      stop("Error: Date is not in format YYYY-MM-DD"))
    
    print(paste0('Generating required date format'))
    
    data$Day_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%d"))
    data$Month_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%m"))
    data$Year_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%Y"))
    data$Year_adj_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%Y"))
    
    if(year_starts_at_Dec1 == TRUE ){
    data[data$Month_generated == 12,]$Year_adj_generated <-
      data[data$Month_generated == 12,]$Year_generated + 1}
    
    print(paste0('Generating defined period labels'))
    
    data$period_label <- "NA" #making period_label column as 'character'
    data$dayoy <-
      as.numeric(format(as.Date(data$visit_date, format = "%Y-%m-%d"), "%j"))
    data$leap_year <- lubridate::leap_year(data$visit_date)
    
    period <-
      expand.grid(periods = group_to_periods,
                  Year_generated = unique(data$Year_adj_generated))
    
    period$group_date_from <- NA
    period$group_date_to <- NA
    period$group_month_from <- NA
    period$group_month_to <- NA
    period$group_day_from <- NA
    period$group_day_to <- NA
    
    for (row in 1:length(period$periods)) {
      period[row, ]$group_date_from <-
        strsplit(as.character(period[row, ]$periods), "[:]")[[1]][1]
      period[row, ]$group_date_to <-
        strsplit(as.character(period[row, ]$periods), "[:]")[[1]][2]
      
      period[row, ]$group_month_from <-
        strsplit(as.character(period[row, ]$group_date_from), "[-]")[[1]][1]
      period[row, ]$group_day_from <-
        strsplit(as.character(period[row, ]$group_date_from), "[-]")[[1]][2]
      
      period[row, ]$group_month_to <-
        strsplit(as.character(period[row, ]$group_date_to), "[-]")[[1]][1]
      period[row, ]$group_day_to <-
        strsplit(as.character(period[row, ]$group_date_to), "[-]")[[1]][2]
    }
    period$group_month_from <-
      match(period$group_month_from, month.abb)
    period$group_month_to <- match(period$group_month_to, month.abb)
    
    period$group_date_from_fin <-
      paste0(period$Year_generated,
             "-",
             period$group_month_from,
             "-",
             period$group_day_from)
    period$group_date_to_fin <-
      paste0(period$Year_generated,
             "-",
             period$group_month_to,
             "-",
             period$group_day_to)
    
    period$group_date_from_dayoy <-
      as.numeric(format(as.Date(period$group_date_from_fin, format = "%Y-%m-%d"), "%j"))
    period$leap_year <-
      lubridate::leap_year(period$group_date_from_fin)
    
    period$group_date_to_dayoy <-
      as.numeric(format(as.Date(period$group_date_to_fin, format = "%Y-%m-%d"), "%j"))
    
    period_fin <-
      unique(period[c(
        "periods",
        "group_date_from",
        "group_date_to",
        "group_month_from",
        "group_month_to",
        "group_day_from",
        "group_day_to",
        "group_date_from_dayoy",
        "group_date_to_dayoy",
        "leap_year"
      )])
    
    print(paste0('Considering leap years'))
    
    period_leap <- subset(period_fin, leap_year == TRUE)
    period_leap[period_leap$group_month_from == 12,]$group_date_from_dayoy <-
      period_leap[period_leap$group_month_from == 12,]$group_date_from_dayoy - 366
    
    data_leap <- subset(data, leap_year == TRUE)
    data_leap[data_leap$Month_generated == 12,]$dayoy <-
      data_leap[data_leap$Month_generated == 12,]$dayoy - 366
    
    for (each in seq(data_leap$dayoy)) {
      for (row in 1:length(period_leap$periods)) {
        if (data_leap[each,]$dayoy >= period_leap[row, ]$group_date_from_dayoy &
            data_leap[each,]$dayoy <= period_leap[row, ]$group_date_to_dayoy) {
          data_leap[each,]$period_label <-
            as.character(period_leap[row, ]$periods)
        }
      }
    }
    
    print(paste0('Finalizing results'))
    
    period_regular <- subset(period_fin, leap_year == FALSE)
    period_regular[period_regular$group_month_from == 12,]$group_date_from_dayoy <-
      period_regular[period_regular$group_month_from == 12,]$group_date_from_dayoy - 365
    
    data_regular <- subset(data, leap_year == FALSE)
    data_regular[data_regular$Month_generated == 12,]$dayoy <-
      data_regular[data_regular$Month_generated == 12,]$dayoy - 365
    
    for (each in seq(data_regular$dayoy)) {
      for (row in 1:length(period_regular$periods)) {
        if (data_regular[each,]$dayoy >= period_regular[row, ]$group_date_from_dayoy &
            data_regular[each,]$dayoy <= period_regular[row, ]$group_date_to_dayoy) {
          data_regular[each,]$period_label <-
            as.character(period_regular[row, ]$periods)
        }
      }
    }
    res <- rbind(data_leap, data_regular)
    labels <-
      data.frame(period_label = group_to_periods, group_labels)
    res <- dplyr::full_join(res, labels, by = "period_label")
    
    rm(
      data,
      period,
      period_fin,
      period_leap,
      period_regular,
      data_leap,
      data_regular,
      labels
    )
    res[, -"dayoy"]
  }

#test the function peri_conv
out_peri_conv <-
  peri_conv(
    data = data_peri_conv,
    date_col_name = in_date_col_name,
    group_to_periods = in_group_to_periods,
    group_labels = in_group_labels,
    year_starts_at_Dec1 = in_year_starts_at_Dec1
  )

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_peri_conv , file = out_result_path) 

##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## Can we use Datamash function for this in Galaxy workflows? ################################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the data analysis##################.
##############################################################################################.
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = "data_out_peri_conv.csv"
out_result_path = "data_out_seasonal_means.csv"

library(magrittr)
library(dplyr)

data_mean_by_group <- data.table::fread(in_data_path)


data_mean_by_group$transparency_m <- as.numeric(data_mean_by_group$transparency_m)

out_seasonal_means <- data_mean_by_group %>%
  group_by(longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean = mean(transparency_m)) %>%
  ungroup() %>% 
  group_by(Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean_annual = mean(Secchi_m_mean)) %>%
  ungroup()


## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_seasonal_means , file = out_result_path) 


##############################################################################################.
## 4. TimeSeries selection and interpolation of NAs ####
##############################################################################################.

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = "data_out_seasonal_means.csv"
in_rel_cols = c("group_labels", "HELCOM_ID")
in_missing_threshold_percentage = 40
in_year_colname = "Year_adj_generated"
in_value_colname = "Secchi_m_mean_annual"
in_min_data_point = 10
out_result_path = "data_out_selected_interpolated.csv"

data_list_subgroups <- data.table::fread(in_data_path)

# split data into sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency
ts_selection_interpolation <- function(
    data,
    rel_cols,
    missing_threshold = 30,
    year_col = "Year",
    value_col = "value",
    min_data_point = 10){
  
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package \"tidyr\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("zoo", quietly = TRUE)) {
    stop("Package \"zoo\" must be installed to use this function.",
         call. = FALSE)
  }

  list_groups <-  vector("list", length(rel_cols))
  
  for (each in seq(rel_cols)){
    list_groups[[each]] <- as.factor(subset(data, select = names(data) == rel_cols[each])[[1]])
  }
  sub_tables <- split(data, list_groups, sep = ";")
  
  # Some tables have too many missing years, therefore it is necessary to remove them from the analysis. 
  # In the example, the treshold for the removal is 40% of timeseries years missing.
  
  sub_tables_subset <- lapply(sub_tables, function(table) {
    
    #create a function for which will calculate a percentage of missing years
    calculate_missing_percentage <- function(table) {
      # Extract the years from the table
      years <- as.numeric(as.character(table$Year_adj_generated))
      # Remove missing values
      years <- years[!is.na(years)]
      # Calculate the total number of years
      total_years <- length(years)
      # Check if there are enough years for calculation
      if (total_years < 2) {
        return(100)  # Return 100% missing if there are not enough years
      }
      
      # Calculate the difference between consecutive years
      year_diff <- diff(years)
      # Calculate the number of consecutive years
      consecutive_years <- sum(year_diff == 1) + 1
      # Calculate the expected number of rows
      expected_rows <- max(years, na.rm = TRUE) - min(years, na.rm = TRUE) + 1
      # Calculate the percentage of missing rows
      missing_percentage <- ((expected_rows - consecutive_years) / expected_rows) * 100
      
      return(missing_percentage)
    }
    
    missing_percentage <- calculate_missing_percentage(table)
    
    if (missing_percentage <= missing_threshold) {
      return(table)
    } else {
      return(NULL)
    }
  })
  
  # Remove NULL elements from the list
  sub_tables_subset <- Filter(Negate(is.null), sub_tables_subset)
  
  # Loop through each table in sub_tables_subset a function for extending 
  # the dataframes by missing years
  # object for results
  sub_tables_subset_out <- list()
  
  for (table_name in names(sub_tables_subset)) {
    
    # Extract the table
    table_data <-
      as.data.frame(sub_tables_subset[[table_name]])
    
    # Convert Year_corrected to numeric
    table_data$Year_d <-
      as.numeric(as.character(table_data[, which(names(table_data) == year_col)]))
    
    # Assign the extended table back to the list
    processed_table <- 
      as.data.frame(tidyr::complete(table_data, Year_d = min(table_data$Year_d):max(table_data$Year_d)))
    
  ## interpolate NAs
  # Loop through each table in sub_tables_subset_out
  
  #for (table_name in names(sub_tables_subset_out)) {
    #processed_table <- sub_tables_subset_out[[table_name]]
    processed_table <- 
      subset(processed_table, select = names(processed_table) %in% c(year_col, value_col), drop = FALSE)

    # Apply zoo::na.approx() to fill gaps if there are at least two non-NA values
    if (sum(!is.na(subset(processed_table, select = names(processed_table) == value_col)[[1]])) >= 2) {
      filled_table <- as.data.frame(zoo::na.approx(processed_table))
      filled_table$ID <- rep(table_name, dim(filled_table)[1])
      sub_tables_subset_out[[table_name]] <- as.data.frame(filled_table)
    } else {
      sub_tables_subset_out[[table_name]] <-
        paste("Insufficient non-NA values to interpolate")
    }
  }
  
  #Remove datasets that has less than set threshold time-period points (default 10)
  short_datasets <- lapply(sub_tables_subset_out, dim)
  sub_tables_subset_out <- 
    sub_tables_subset_out[unname(unlist(sapply(short_datasets, function(i) lapply(i, "[[", 1))[1,]) > min_data_point)]
  # transform list to data.frame
  res <- data.frame(Reduce(rbind, sub_tables_subset_out))
  res <- tidyr::separate(res, ID, c("season", "polygon_id"), sep = ";")
  
  return(res)
}

out_ts <- ts_selection_interpolation(
  data = data_list_subgroups, 
  rel_cols = in_rel_cols, 
  missing_threshold = in_missing_threshold_percentage, 
  year_col = in_year_colname,
  value_col = in_value_colname,
  min_data_point = in_min_data_point)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_ts , file = out_result_path) 


##############################################################################################.
## 5. trend_analysis Mann Kendall ####
##############################################################################################.

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = "data_out_selected_interpolated.csv"
in_rel_cols = c("season", "polygon_id")
in_time_colname = "Year_adj_generated"
in_value_colname = "Secchi_m_mean_annual"
out_result_path = "mk_trend_analysis_results.csv"

data_list_subgroups <- data.table::fread(in_data_path)


trend_analysis_mk <- function(
    data,
    rel_cols,
    time_colname = "year",
    value_colname = "value"){
  
  if (!requireNamespace("Kendall", quietly = TRUE)) {
    stop("Package \"Kendall\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package \"tidyr\" must be installed to use this function.",
         call. = FALSE)
  }
  
  err = paste0("Error: `", value_colname, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(data)[, names(data) == value_colname]))
  err = paste0("Error: `", in_time_colname, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(data)[, names(data) == time_colname]))
  
  # Create empty vectors to store data
  table_names <- c()
  tau_values <- c()
  p_values <- c()
  period <- c()
  
  list_groups <-  vector("list", length(rel_cols))
  
  for (each in seq(rel_cols)){
    list_groups[[each]] <- 
      as.factor(subset(data, select = names(data) == rel_cols[each])[[1]])
  }
  data <- split(data, list_groups, sep = ";")
  # Remove elements with 0 rows from the list
  data <- data[sapply(data, function(x) dim(x)[1]) > 0]
  
    # Loop through each table in sub_tables_subset
    for (table_name in names(data)) {
      # Extract the current table
      current_table <- data[[table_name]]
      time <- subset(current_table, select = names(current_table) == time_colname)
      values <- subset(current_table, select = names(current_table) == value_colname)
      # Create time series object
      time_series_object <- ts(values, frequency = 1, start = c(min(time), 1))
      
      # Perform Mann-Kendall test
      mann_kendall_test_results <- Kendall::MannKendall(time_series_object)
      
      # Extract tau-value and p-value
      tau <- mann_kendall_test_results$tau
      p_value <- mann_kendall_test_results$sl
      
      # Append data to vectors
      table_names <- c(table_names, table_name)
      tau_values <- c(tau_values, tau)
      p_values <- c(p_values, p_value)
      period <- c(period, paste0(min(time), ":", max(time)))
    }
    
    # Combine data into a data frame
    results_table <- data.frame(ID = table_names, period = period, Tau_Value = tau_values, P_Value = p_values)
    results_table <- tidyr::separate(results_table, ID, c("season", "polygon_id"), sep = ";")
    
    # Print the results table
    return(results_table)
}   
    
out_mk <- trend_analysis_mk(data = data_list_subgroups,
                  rel_cols = in_rel_cols,
                  value_col = in_value_colname,
                  time_colname = in_time_colname)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_mk , file = out_result_path) 
    
################################################################################.
## 6. visualization ####
################################################################################.
### 6.1. map: shp + dpoints ####
in_shp_path = "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_dpoints_path = "data_out_point_att_polygon.csv"
in_long_col_name = "longitude"
in_lat_col_name = "latitude"
in_value_name = "transparency_m"
in_region_col_name = "HELCOM_ID"
out_result_path_url = "map_shapefile_insitu.html"

dpoints <- data.table::fread(in_dpoints_path)
shapefile <- sf::st_read(in_shp_path)


map_shapefile_points <- function(shp, dpoints, 
                                 long_col_name="long", 
                                 lat_col_name="lat",
                                 value_name = NULL,
                                 region_col_name = NULL) {

  if (!requireNamespace("sp", quietly = TRUE)) {
    stop("Package \"sp\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package \"sf\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("mapview", quietly = TRUE)) {
    stop("Package \"mapview\" must be installed to use this function.",
         call. = FALSE)
  }
  if (missing(shp))
    stop("missing shp")
  if (missing(dpoints))
    stop("missing dpoints")
  if (! long_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", long_col_name))
  if (! lat_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", lat_col_name))
  
  err = paste0("Error: `", long_col_name, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == long_col_name]))
  err = paste0("Error: `", lat_col_name, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == lat_col_name]))
  
  #dpoints to spatial
  print('Making input data spatial based on long, lat...')
  data_spatial <- sf::st_as_sf(dpoints, coords = c(long_col_name, lat_col_name))
  # set to WGS84 projection
  print('Setting to WGS84 CRS...')
  sf::st_crs(data_spatial) <- 4326
  
  ## First, convert from WGS84-Pseudo-Mercator to pure WGS84
  print('Setting geometry data to same CRS...')
  shp_wgs84 <- sf::st_transform(shp, sf::st_crs(data_spatial))
  
  ## Check and fix geometry validity
  print('Check if geometries are valid...')# TODO: Check actually needed? Maybe just make valid!
  if (!all(sf::st_is_valid(shp_wgs84))) { # many are not (in the example data)!
    print('They are not! Making valid...')
    shp_wgs84 <- sf::st_make_valid(shp_wgs84)  # slowish...
    print('Making valid done.')
  }
  ## Overlay shapefile and in situ locations
  print(paste0('Drawing map...'))
  shp_wgs84 <- sf::st_filter(shp_wgs84, data_spatial) 

  mapview::mapview(shp_wgs84, 
                   alpha.region = 0.3, 
                   legend = FALSE, 
                   zcol = region_col_name) + 
    mapview::mapview(data_spatial, 
                     zcol = value_name,
                     legend = TRUE, 
                     alpha = 0.8)
  
}


map_out <- map_shapefile_points(shp = shapefile, 
                                 dpoints = dpoints,
                                 long_col_name = in_long_col_name,
                                 lat_col_name = in_lat_col_name,
                                 value_name = in_value_name, 
                                 region_col_name = in_region_col_name)


## Output: Now need to store output:
print(paste0('Save map to html: ', out_result_path_url))
mapview::mapshot(map_out, 
                 url = out_result_path_url)
#browseURL(out_result_path_url)



### 6.2. barplot of trend analysis ####
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = "mk_trend_analysis_results.csv"
in_id_col = "polygon_id"
in_test_value = "Tau_Value"
in_p_value = "P_Value"
in_p_value_threshold = "0.05"
in_group = "season"
out_result_path = "barplot_trend_results.png"

data_list_subgroups <- data.table::fread(in_data_path)
library(ggplot2)

#plot the result for transparency
barplot_trend_results <- function(data, 
                            id = "polygon_id", 
                            test_value = "value",
                            p_value = "p_value",
                            p_value_threshold = 0.05,
                            group = "group"){
  
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package \"ggplot2\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("viridis", quietly = TRUE)) {
    stop("Package \"viridis\" must be installed to use this function.",
         call. = FALSE)
  }
  # ggplot(aes(x=data[,which(names(data) == id)], #why which is not working properly??
  #            y=data[,which(names(data) == test_value)]), 
  #        data=data)+
  #   geom_bar(aes(fill = data[,which(names(data) == group)], 
  #                alpha = data[,which(names(data) == p_value)] > p_value_threshold),
  #            width=0.6,
  #            position = position_dodge(width=0.6),
  #            stat = "identity")+
    
  ggplot(aes(
    x = subset(data, select = names(data) == id)[[1]],
    y = subset(data, select = names(data) == test_value)[[1]]
  ), data = data) +
    geom_bar(
      aes(
        fill = subset(data, select = names(data) == group)[[1]],
        alpha = subset(data, select = names(data) == p_value)[[1]] > p_value_threshold
      ),
      width = 0.6,
      position = position_dodge(width = 0.6),
      stat = "identity"
    ) +
    scale_alpha_manual(values = c(1, 0.35), guide = "none") +
    viridis::scale_fill_viridis(discrete = TRUE) +
    theme_minimal() +
    labs(
      x = paste(id),
      y = paste(test_value),
      fill = paste(group),
      caption = "*Translucent bars indicate statistically insignificant results"
    ) +
    theme_bw(base_size = 12) +
    theme(legend.position = "top")
}

barplot_trends <- barplot_trend_results(data = data_list_subgroups,
                      id = "polygon_id",
                      test_value = "Tau_Value",
                      p_value = "P_Value",
                      p_value_threshold = "0.05",
                      group = "season")

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
ggsave(barplot_trends , file = out_result_path, dpi = 300) 


### 6.3. trend result map ####
# plot a map of trend results
### interactive map
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path = "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_trend_results_path = "mk_trend_analysis_results.csv"
in_id_trend_col = "polygon_id"
in_id_shp_col = "HELCOM_ID"
in_group = "season"
in_p_value_col = "P_Value"
in_p_value_threshold = "0.05"

out_result_path_url = "map_trend_results.html"
out_result_path_png = "map_trend_results.png"

data <- data.table::fread(in_trend_results_path)
shp <- sf::st_read(in_shp_path)

library(tmap)
library(tmaptools)

map_trends_interactive <- function(shp, data, 
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

  tmap_mode("view")
  tm_basemap(server = providers$Esri)+
    tm_shape(shp_trend)+
    tm_polygons("trend_res", 
              alpha = 0.85, 
              title = "result of trend analysis",
              colorNA = NULL, 
              colorNULL = NULL, 
              textNA = "not tested") +
    tm_facets(by = in_group, sync = TRUE)+
    tm_tiles("Stamen.TonerLabels")

}



map_out <- map_trends_interactive(shp = shp, 
                                  data = data,
                                  id_trend_col = in_id_trend_col,
                                  id_shp_col = in_id_shp_col,
                                  p_value_threshold = in_p_value_threshold,
                                  p_value_col = in_p_value_col,
                                  group = in_group)

## I cannot find a way how to save faceted interactive maps..
## Output: Now need to store output:
print(paste0('Save map to html: ', out_result_path_url))
#saveWidget(map_out, out_result_path_url) # not working
#tmap_save(map_out, out_result_path_url) # not working
#mapview::mapshot(map_out, out_result_path_url) # not working
#htmltools::save_html(map_out, out_result_path_url) #not working

###
### static map
###

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path = "shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp"
in_trend_results_path = "mk_trend_analysis_results.csv"
in_id_trend_col = "polygon_id"
in_id_shp_col = "HELCOM_ID"
in_group = "season"
in_p_value_col = "P_Value"
in_p_value_threshold = "0.05"

out_result_path_url = "map_trend_results.html"
out_result_path_png = "map_trend_results.png"

data <- data.table::fread(in_trend_results_path)
shp <- sf::st_read(in_shp_path)

library(tmap)
library(tmaptools)
library(rosm)
library(sf)


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
    tm_facets(by = in_group, sync = TRUE)+
    tm_tiles("Stamen.TonerLabels")
}


map_out <- map_trends_static(shp = shp, 
                                  data = data,
                                  id_trend_col = in_id_trend_col,
                                  id_shp_col = in_id_shp_col,
                                  p_value_threshold = in_p_value_threshold,
                                  p_value_col = in_p_value_col,
                                  group = in_group)


## Output: Now need to store output:
print(paste0('Save map to html: ', out_result_path_url))
tmap_save(map_out_static, out_result_path_png)


########################################.






