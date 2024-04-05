### Aquainfra project 
### This project has received funding from the European Commission?s Horizon
#### Europe Research and Innovation programme under grant agreement No 101094434.

### WP5 Use case: Baltic Sea Daugava-Gulf of Riga: shapefile attributes as grouping parameter
### Latvian Institute of Aquatic Ecology

# before running this script download shapefile from and store in your local directory:
# https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48

# load libraries
# versions has to be set stationary! not done at the moment
if (!require("pacman")) install.packages("pacman")
pacman::p_load(readxl, 
               dplyr, 
               magrittr, 
               reshape2, 
               rgdal, sp, 
               readxl, 
               sf,
               janitor, 
               rstudioapi,
               lubridate,
               tidyr,
               zoo,
               Kendall)

#blablablabalabla


# working directory ####
# automatic setting wd to the folder where current script file is
current_path = rstudioapi::getActiveDocumentContext()$path 
setwd(dirname(current_path ))
#print( getwd() ) # uncomment for checking

# load HELCOM shapefile for subbasins and adjust to the chosen projection
# locate shapefile manually
# example for HELCOM subbasin L4 shp: 
## download at https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48 
shapefile <- readOGR("shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp") 
shp <- spTransform(shapefile, CRS("+proj=longlat +datum=WGS84 +no_defs"))

# locate in situ data set manually
# load in situ data and respective metadata (geolocation and date are mandatory metadata)
# example data
data_raw <- readxl::read_excel("in_situ_data/in_situ_example.xlsx") %>% #example data from https://latmare.lhei.lv/
  janitor::clean_names() # makes column names clean for R

#list relevant columns: geolocation (lat and lon), date and values for data points are mendatory
rel_columns <- c("longitude", "latitude", #coordinates
                 "visit_date", #date
                 "measured_depth_m", #optional 
                 "transparency_m", #Secchi depth in meters (numeric)
                 "color_id" #water color hue in Furel-Ule (categories)
                 )

# relevant data
data_rel <- data_raw %>%
  #select only relevant columns
  select(all_of(rel_columns)) %>%
    # remove cases when Secchi depth, water colour were not measured
   filter(!is.na(`transparency_m`) & !is.na(`color_id`)) # make sure to use correct column names

# set coordinates ad numeric (in case they are read as chr variables)
data_rel$`longitude` <- as.numeric(data_rel$`longitude`)
data_rel$`latitude` <- as.numeric(data_rel$`latitude`)

# make data points spatial
data_rel_spatial <- st_as_sf(data_rel, coords = c("longitude","latitude"))

# set to WGS84 projection
st_crs(data_rel_spatial) <- 4326
# make in situ points spatial
data_rel_spatial <- as(data_rel_spatial, 'Spatial')

# overlay shapefile and in situ locations
data_shp_over <- sp::over(data_rel_spatial, shp)

# bind shapefile attributes to in situ data.frame
data_rel_shp_attributes <- cbind(data_rel, data_shp_over)

################################################################################
#STEP 2: group data by seasons
################################################################################
#create new columns of the 'Day','Month' and 'Year'
data_rel_shp_attributes$visit_date<-as.POSIXct(data_rel_shp_attributes$visit_date)

data_rel_shp_attributes$Month<-month(data_rel_shp_attributes$visit_date)
data_rel_shp_attributes$Year<-year(data_rel_shp_attributes$visit_date)
data_rel_shp_attributes$Day<-day(data_rel_shp_attributes$visit_date)

#change year indication for December observations in order to assign it to the correct season
data_rel_shp_attributes$Year_corrected <- ifelse(data_rel_shp_attributes$Month == 12, 
                                                 data_rel_shp_attributes$Year + 1, 
                                                 data_rel_shp_attributes$Year)

#create new column 'Season'
data_rel_shp_attributes$Season <- ifelse(data_rel_shp_attributes$Month %in% c(4, 5)|
                                           (data_rel_shp_attributes$Month == 3 & data_rel_shp_attributes$Day > 15), "Spring",
                                            ifelse(data_rel_shp_attributes$Month %in% c(6, 7, 8), "Summer",
                                                   ifelse(data_rel_shp_attributes$Month %in% c(12, 1, 2) | 
                                                            (data_rel_shp_attributes$Month == 3 & data_rel_shp_attributes$Day <= 15), "Winter", "Autumn")))


################################################################################
#STEP 3: calculate data average per year, per season and per HELCOM_ID
################################################################################
data_rel_shp_attributes$HELCOM_ID<-as.factor(data_rel_shp_attributes$HELCOM_ID)
data_rel_shp_attributes$Year_corrected<-as.factor(data_rel_shp_attributes$Year_corrected)
data_rel_shp_attributes$Season<-as.factor(data_rel_shp_attributes$Season)
data_rel_shp_attributes$transparency_m<-as.numeric(data_rel_shp_attributes$transparency_m)
data_rel_shp_attributes$color_id<-as.numeric(data_rel_shp_attributes$color_id)

Transarency_m_mean<-aggregate(transparency_m ~ longitude+latitude +Year_corrected+Season+HELCOM_ID, data = data_rel_shp_attributes, FUN = mean, na.rm = TRUE)
Transarency_m_mean2<-aggregate(transparency_m ~ Year_corrected+Season+HELCOM_ID, data = Transarency_m_mean, FUN = mean, na.rm = TRUE)

Color_id_median<-aggregate(cbind(color_id) ~ longitude+latitude +Year_corrected+Season+HELCOM_ID, data = data_rel_shp_attributes, FUN = median, na.rm = TRUE)

################################################################################
#STEP 4: Interpolation of NAs
################################################################################

#split data onto sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency
sub_tables <- split(Transarency_m_mean2, list(Transarency_m_mean2$Season, Transarency_m_mean2$HELCOM_ID))

#EST data are short, only few years since 1976, therefore the data frames are excluded from the further analysis

# Identify indices of elements containing "EST" in HELCOM_ID
indices <- grep("EST", names(sub_tables), invert = TRUE)

# Subset sub_tables to exclude elements containing "EST"
sub_tables_subset <- sub_tables[indices]

#library(tidyr), probably it competes with dplyr if it was not fixed

# Loop through each table in sub_tables_subset a function for extending the dataframes by missing years
for (table_name in names(sub_tables_subset)) {
  # Extract the table
  table_data <- as.data.frame(sub_tables_subset[[table_name]])
  
  # Convert Year_corrected to numeric
  table_data$Year_corrected <- as.numeric(as.character(table_data$Year_corrected))
  
  # Extend the data frame
  extended_table <- complete(table_data, Year_corrected = min(table_data$Year_corrected):max(table_data$Year_corrected))
  
  # Assign the extended table back to the list
  sub_tables_subset[[table_name]] <- extended_table
}

# Check the result for one table (e.g., Autumn.LAT-005)
print(sub_tables_subset$"Autumn.LAT-005", n=nrow(sub_tables_subset$"Autumn.LAT-005"))


#interpolate the transparency 
# Loop through each table in sub_tables_subset
for (table_name in names(sub_tables_subset)) {
  # Remove the Season and HELCOM_ID columns
  processed_table <- sub_tables_subset[[table_name]] %>% 
    select(-Season, -HELCOM_ID)
  
  # Apply na.approx() to fill gaps if there are at least two non-NA values
  if (sum(!is.na(processed_table$transparency_m)) >= 2) {
    filled_table <- na.approx(processed_table)
    sub_tables_subset[[table_name]] <- filled_table
  } else {
    cat("Insufficient non-NA values to interpolate in", table_name, "\n")
  }
}

################################################################################
#STEP 5: Mann-Kendall test for transparency and the table with results
################################################################################

# Create empty vectors to store data
table_names <- c()
tau_values <- c()
p_values <- c()

# Loop through each table in sub_tables_subset
for (table_name in names(sub_tables_subset)) {
  # Extract the current table
  current_table <- sub_tables_subset[[table_name]]
  
  # Convert columns to numeric if they are not already
  current_table[, "Year_corrected"] <- as.numeric(as.character(current_table[, "Year_corrected"]))
  current_table[, "transparency_m"] <- as.numeric(as.character(current_table[, "transparency_m"]))
  
  # Create time series object
  TS <- ts(current_table[, "transparency_m"], frequency = 1, start = c(min(current_table[, "Year_corrected"]), 1))
  
  # Perform Mann-Kendall test
  MK_Test <- MannKendall(TS)
  
  # Extract tau-value and p-value
  tau <- MK_Test$tau
  p_value <- MK_Test$sl
  
  # Append data to vectors
  table_names <- c(table_names, table_name)
  tau_values <- c(tau_values, tau)
  p_values <- c(p_values, p_value)
}

# Combine data into a data frame
results_table <- data.frame(Table = table_names, Tau_Value = tau_values, P_Value = p_values)

# Print the results table
print(results_table)