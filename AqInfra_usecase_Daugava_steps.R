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
               rstudioapi)

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



