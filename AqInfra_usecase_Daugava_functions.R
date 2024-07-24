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
out_result_path = "data_out_selected_interpolated.csv"

data_list_subgroups <- data.table::fread(in_data_path)

# split data into sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency
ts_selection_interpolation <- function(
    data,
    rel_cols,
    missing_threshold = 30,
    year_col = "Year",
    value_col = "value"){
  
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
  res <- data.frame(Reduce(rbind, sub_tables_subset_out))
  res <- tidyr::separate(res, ID, c("season", "polygon_id"), sep = ";")
  
  return(res)

}

out_ts <- ts_selection_interpolation(
  data = data_list_subgroups, 
  rel_cols = in_rel_cols, 
  missing_threshold = in_missing_threshold_percentage, 
  year_col = in_year_colname,
  value_col = in_value_colname)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_ts , file = out_result_path) 


##############################################################################################.
## 5. trend_analysis Mann Kendall ####
##############################################################################################.

#TBC



