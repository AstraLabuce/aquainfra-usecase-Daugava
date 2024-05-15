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
    latitude   = as.numeric(latitude)
    #visit_date = as.POSIXct(visit_date),
    #month      = lubridate::month(visit_date),
    #year       = lubridate::year(visit_date),
    #day        = lubridate::month(visit_date)
  )

############################################################################################.

# FUNCTIONS for Galaxy ####

############################################################################################.
## points_att_polygon ####
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
#for manual output uncomment
#write.csv2(data_rel_shp_attributes, file = "output_f1.csv") 

##############################################################################################.
## peri_conv : period converter ####
# function peri_conv - adds December to the next year (all winter months together)
                            # in the result every year starts at Dec-01. and ends Nov-30;
                            # generates num variable 'Year_adjusted' to show change;
                            # generates chr variable 'season' to allow grouping the data based on season.

peri_conv <-
  function(data,
           date_col_name,
           group_to_periods = #default season division
             c("Dec-01:Feb-29", "Mar-01:May-30", "Jun-01:Aug-30", "Sep-01:Nov-30"), 
           group_labels = c("winter", "spring", "summer", "autumn") #optional - if not defined then labels == group_to_periods
           ) {
    #data - dataset with columns for Year and Month (all the rest variables stays the same)
    #Date - column name to Date in format YYYY-MM-DD; Year, Month, Day, Year_adj - will be generated
    #group_to_periods <- group into periods: define the periods, e.g., mmm-DD:mmm-DD, Mar-15:Jun-01.

    if (missing(data))
      stop("missing data")
    suppressWarnings(
    if (!unique(!is.na(as.Date(get(Date, data), "%Y-%m-%d"))))
      stop("Error: Date is not in format YYYY-MM-DD")
    )
    data$Day_generated <-
      as.numeric(format(as.Date(get(Date, data), format = "%Y-%m-%d"), "%d"))
    data$Month_generated <-
      as.numeric(format(as.Date(get(Date, data), format = "%Y-%m-%d"), "%m"))
    data$Year_generated <-
      as.numeric(format(as.Date(get(Date, data), format = "%Y-%m-%d"), "%Y"))
    data$Year_adj_generated <-
      as.numeric(format(as.Date(get(Date, data), format = "%Y-%m-%d"), "%Y"))
    
    data[data$Month_generated == 12, ]$Year_adj_generated <-
      data[data$Month_generated == 12, ]$Year_generated + 1
    
    data$season <- NA
    period <- data.frame(periods = group_to_periods, labels = group_labels)
    #rownames(period) <- period$group_to_periods
    
    period$group_date_from <- NA
    period$group_date_to <- NA
    
    for (row in 1:length(group_to_periods)) {
      period[row,]$group_date_from <- strsplit(period[row,]$periods, "[:]")[[1]][1]
      period[row,]$group_date_to <- strsplit(period[row,]$periods, "[:]")[[1]][2]
    }
    
    
    
    ## potential solution - in progress
    
    #for (year in 1:length(unique(data$Year_adj_generated))){
    #  
    #}
    #
    #data$Year_adj_generated, period
    
    # 
    # period$yday <- format(as.Date(period$group_date_from, format = "%h-%d"), "%j")
    # 
    # 
    # strftime(s_1, format = "%j")
    # 
    # data[data$Month_generated %in% c(12, 1, 2), ]$season <-
    #   "winter (Dec-Feb)"
    # data[data$Month_generated %in% c(3, 4, 5), ]$season <-
    #   "spring (Mar-May)"
    # data[data$Month_generated %in% c(6, 7, 8), ]$season <-
    #   "summer (Jun-Aug)"
    # data[data$Month_generated %in% c(9, 10, 11), ]$season <-
    #   "autumn (Sep-Nov)"
    # 
    # data
    # 
    # group_to_periods = #default season division
    #   c("Dec-01:Feb-29", "Mar-01:May-30", "Jun/01:Aug/30", "Sep-01:Nov-30")
        
  }

#test the function peri_conv
out <-
  peri_conv(
    data_rel_shp_attributes,
    date_col_name = "visit_date",
    group_to_periods = c(
      "Dec-01:Mar-14",
      "Mar-15:May-30",
      "Jun-01:Aug-30",
      "Sep-01:Nov-30"
    )
  )








