### Aquainfra project
### This project has received funding from the European Commission?s Horizon
#### Europe Research and Innovation programme under grant agreement No 101094434.

### WP5 Use case: Baltic Sea Daugava-Gulf of Riga: shapefile attributes as grouping parameter
### Latvian Institute of Aquatic Ecology

# working directory ####.
# automatic setting wd to the folder where current script file is
current_path = rstudioapi::getActiveDocumentContext()$path
setwd(dirname(current_path))

###############################################################################################.
## THIS WE WILL TRY TO GET INTO AQUAINFRA DDAS - IN THE GOLD STANDART: READY FOR THE ANALYSIS #.

library(magrittr)
library(dplyr)

# load HELCOM shapefile for subbasins and adjust to the chosen projection
# example for HELCOM subbasin L4 shp: <- THIS IS ALREADY IN DDAS
## download at https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48
library(rgdal)

shapefile <-
  rgdal::readOGR("shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp") #"SpatialPolygonsDataFrame"

# locate in situ data set manually
# load in situ data and respective metadata (geolocation and date are mandatory metadata)
# example data
#data_raw <- readxl::read_excel("in_situ_data/in_situ_example.xlsx") %>% #example data from https://latmare.lhei.lv/
#  janitor::clean_names() # makes column names clean for R
data_raw <-
  readxl::read_excel("in_situ_data/Latmare_20240111_secchi_color.xlsx") %>% #datafvrom LIAE data base from https://latmare.lhei.lv/
  janitor::clean_names() # makes column names clean for R


#list relevant columns: geolocation (lat and lon), date and values for data points are mandatory
rel_columns <- c(
  "longitude",
  "latitude",
  #coordinates
  "visit_date",
  #date
  "measured_depth_m",
  #optional
  "transparency_m",
  #Secchi depth in meters (numeric)
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
#write.csv2(data_rel, file = "data_WP5_DaugavaUseCase_input.csv") # this should be made available to DDAS

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
  stopifnot("Error: `long` is not numeric." =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == long_col_name]))
  stopifnot("Error: `lat` is not numeric." =
              is.numeric(as.data.frame(dpoints)[, names(dpoints) == lat_col_name]))
  
  #dpoints to spatial
  data_spatial <- sf::st_as_sf(dpoints, coords = c(long_col_name, lat_col_name))
  # set to WGS84 projection
  sf::st_crs(data_spatial) <- 4326
  # make in situ points spatial
  data_spatial <- as(data_spatial, 'Spatial')
  
  # overlay shapefile and in situ locations
  data_shp <-
    sp::over(data_spatial, sp::spTransform(shp, sp::CRS("+proj=longlat +datum=WGS84 +no_defs")))
  # bind shapefile attributes to in situ data.frame
  res <- cbind(dpoints, data_shp)
  rm(data_spatial, data_shp)
  res
}

#test the function points_att_polygon
data_rel_shp_attributes <-
  points_att_polygon(
    shp = shapefile,
    dpoints = data_rel,
    long = "longitude",
    lat = "latitude"
  )

#rm(shapefile, data_rel, data_raw)
##############################################################################################.
## 2. peri_conv : period converter ####
# function peri_conv - adds December to the next year (all winter months together)
                            # in the result every year starts at Dec-01. and ends Nov-30;
                            # generates num variable 'Year_adjusted' to show change;
                            # generates chr variable 'season' to allow grouping the data based on season.

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
    
    data$period_label <- NA
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
    
    
    period_leap <- subset(period_fin, leap_year == TRUE)
    period_leap[period_leap$group_month_from == 12,]$group_date_from_dayoy <-
      period_leap[period_leap$group_month_from == 12,]$group_date_from_dayoy - 366
    
    data_leap <- subset(data, leap_year == TRUE)
    data_leap[data_leap$Month_generated == 12,]$dayoy <-
      data_leap[data_leap$Month_generated == 12,]$dayoy - 366
    
    for (each in seq(data_leap$visit_date)) {
      for (row in 1:length(period_leap$periods)) {
        if (data_leap[each,]$dayoy >= period_leap[row, ]$group_date_from_dayoy &
            data_leap[each,]$dayoy <= period_leap[row, ]$group_date_to_dayoy) {
          data_leap[each,]$period_label <-
            as.character(period_leap[row, ]$periods)
        }
      }
    }
    
    period_regular <- subset(period_fin, leap_year == FALSE)
    period_regular[period_regular$group_month_from == 12,]$group_date_from_dayoy <-
      period_regular[period_regular$group_month_from == 12,]$group_date_from_dayoy - 365
    
    data_regular <- subset(data, leap_year == FALSE)
    data_regular[data_regular$Month_generated == 12,]$dayoy <-
      data_regular[data_regular$Month_generated == 12,]$dayoy - 365
    
    for (each in seq(data_regular$visit_date)) {
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
    res <- res[,-which(names(res) %in% c("leap_year", "dayoy"))]
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
    res
  }

#test the function peri_conv
data_after_peri_conv <-
  peri_conv(
    data = data_rel_shp_attributes,
    date_col_name = "visit_date",
    group_to_periods = c(
      "Dec-01:Mar-15",
      "Mar-16:May-31",
      "Jun-01:Aug-31",
      "Sep-01:Nov-30"
    ),
    group_labels = c("winter", "spring", "summer", "autumn"),
    year_starts_at_Dec1 = TRUE
  )

##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## In Galaxy workflows , can we use Datamash function for this? ##############################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the workflow ######################.
##############################################################################################.
data_after_peri_conv$transparency_m <- as.numeric(data_after_peri_conv$transparency_m)

data_annual_seasonal_means <- data_after_peri_conv %>%
  group_by(longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean = mean(transparency_m)) %>%
  ungroup() %>% 
  group_by(Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean_annual = mean(Secchi_m_mean)) %>%
  ungroup()

##############################################################################################.
## 4. Interpolation of NAs ####
##############################################################################################.

#split data onto sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency
### list subgoups ####
list_subgroups <- function(
    data,
    rel_cols){
  list_groups <-  vector("list", length(rel_cols))
  
  for (each in seq(rel_cols)){
    list_groups[[each]] <- as.factor(data[,which(names(data) == rel_cols[each])][[1]])
  }
  split(data, list_groups)
}

sub_tables <- list_subgroups(data = data_annual_seasonal_means, 
               rel_cols = c("group_labels", "HELCOM_ID"))

# Some tables have too many missing years, therefore it is necessary to filter them out. 
# In the example, the treshold is 40% of missing years of the total consequence.
# create a function which will calculate a percentage of missing years

############## filtered tables- needs more work ####
### I do not know how to make this a nested function at the moment
### I tried but not successfully
filtered_tables <- lapply(sub_tables, function(table) {
  
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
  
  if (missing_percentage <= 40) {#can be modified as required <- this should be made a variable input into function
    return(table)
  } else {
    return(NULL)
  }
})

# Remove NULL elements from the list
sub_tables_subset <- Filter(Negate(is.null), filtered_tables)


############################################################################################.

######## extend to fill missing years ####
# Loop through each table in sub_tables_subset a function for extending 
# the dataframes by missing years

extend_data_continuos <-
  function (list_with_missing_years, year_col = "Year") {
    
    if (!requireNamespace("tidyr", quietly = TRUE)) {
      stop("Package \"tidyr\" must be installed to use this function.",
           call. = FALSE)
    }
    
    for (table_name in names(list_with_missing_years)) {
      # object for results
      sub_tables_subset_out <- list_with_missing_years
      # Extract the table
      table_data <-
        as.data.frame(list_with_missing_years[[table_name]])
      
      # Convert Year_corrected to numeric
      table_data$Year_d <-
        as.numeric(as.character(table_data[, which(names(table_data) == year_col)]))
      
      # Assign the extended table back to the list
      sub_tables_subset_out[[table_name]] <- 
        tidyr::complete(table_data, Year_d = min(table_data$Year_d):max(table_data$Year_d))
      return(sub_tables_subset_out)
    }
    
  }

sub_tables_subset_extended <-
  extend_data_continuos(list_with_missing_years = sub_tables_subset, 
                        year_col = "Year_adj_generated")

### interpolate NAs ####
# Loop through each table in sub_tables_subset

interpolate_linear <-
  function(data_list,
           year_col = "Year",
           value_col = "value_mean_annual") {
    for (table_name in names(data_list)) {
      # Remove the Season and HELCOM_ID columns
      processed_table <- data_list[[table_name]]
      processed_table <-
        processed_table[, which(names(processed_table) %in% c(year_col, value_col))]
      
      # Apply zoo::na.approx() to fill gaps if there re at least two non-NA values
      if (sum(!is.na(processed_table[, which(names(processed_table) == value_col)][[1]])) >= 2) {
        filled_table <- zoo::na.approx(processed_table)
        data_list[[table_name]] <- filled_table
      } else {
        data_list[[table_name]] <-
          paste("Insufficient non-NA values to interpolate")
      }
    }
    return(data_list)
  }

inter_res <- interpolate_linear(sub_tables_subset_extended,
                                year_col = "Year_adj_generated",
                                value_col = "Secchi_m_mean_annual")
################################################################################################.



