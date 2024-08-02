
## Imports
#library(rgdal)
library(sf)
library(magrittr)
library(dplyr)
library(janitor)
library(sp)
library(data.table)


## Args
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path = args[1]
in_dpoints_path = args[2]
in_long_col_name = args[3]
in_lat_col_name = args[4]
out_result_path = args[5]

#PATH_SHP="/home/mbuurman/work/pyg_geofresh/pygeoapi/pygeoapi/process/daugava/test_inputs/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp"
#PATH_XLSX="/home/mbuurman/work/pyg_geofresh/pygeoapi/pygeoapi/process/daugava/test_inputs/in_situ_example.xlsx"
#PATH_OUT="/home/mbuurman/work/pyg_geofresh/pygeoapi/pygeoapi/process/daugava/test_outputs/mytestoutput.csv"
#/usr/bin/Rscript --vanilla /home/mbuurman/work/pyg_geofresh/pygeoapi/pygeoapi/process/get_astra_1.R ${PATH_SHP} ${PATH_XLSX} "longitude" "latitude" ${PATH_OUT}
# TODO TEST THIS: Failing imports...

# Problem! rgdal is too old!
# See: https://stackoverflow.com/questions/76868135/r-package-rgdal-can-not-be-installed


## Data from disk to memory.
## This part is also directly from Astra's code.
## TODO: Make more format agnostic??

# load HELCOM shapefile for subbasins and adjust to the chosen projection
# example for HELCOM subbasin L4 shp: <- THIS IS ALREADY IN DDAS
## download at https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48
#shapefile <- rgdal::readOGR("shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp") #"SpatialPolygonsDataFrame"
#shp <- rgdal::readOGR(in_shp_path) #"SpatialPolygonsDataFrame"
shp <- st_read(in_shp_path)


# locate in situ data set manually
# load in situ data and respective metadata (geolocation and date are mandatory metadata)
# example data
#data_raw <- readxl::read_excel("in_situ_data/in_situ_example.xlsx") %>% #example data from https://latmare.lhei.lv/
data_raw <- readxl::read_excel(in_dpoints_path) %>% #example data from https://latmare.lhei.lv/
  janitor::clean_names() # makes column names clean for R

#############.
# this is for our local full data set
# data_raw <-
#   readxl::read_excel("in_situ_data/Latmare_20240111_secchi_color.xlsx") %>% #datafvrom LIAE data base from https://latmare.lhei.lv/
#   janitor::clean_names() # makes column names clean for R
#############.

#list relevant columns: geolocation (lat and lon), date and values for data points are mandatory
# TODO: Let user list them!
# Or move this prep to a separate step!
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
print('Making data_rel')
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
print('Making data_rel 2')
data_rel <- data_rel %>%
  mutate(
    longitude  = as.numeric(longitude),
    latitude   = as.numeric(latitude),
    transparency_m = as.numeric(transparency_m)
  )
#write.csv2(data_rel, file = "data_WP5_DaugavaUseCase_input.csv") # this should be made available to DDAS
#rm(rel_columns, data_rel_spatial, data_shp_over)
print('Making data_rel done:')
print(data_rel)


# This function was directly copied from https://github.com/AstraLabuce/aquainfra-usecase-Daugava/blob/main/AqInfra_usecase_Daugava_functions.R
# 2024-06-26

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

  # TODO: I added this check, et voila, wrong col name!
  if (! long_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", long_col_name))
  if (! lat_col_name %in% colnames(dpoints))
    stop(paste0("input data does not have column ", lat_col_name))

  # TODO: long and lat hardcoded!
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
  # make in situ points spatial
  ##data_spatial <- as(data_spatial, 'Spatial') # LEAVE OUT, KEEP AS SF! TO ALLOW USING SF_INTERSECTION
  
  # overlay shapefile and in situ locations
  # TODO FAILS
  ## FIrst, convert from WGS84-Pseudo-Mercator to pure WGS84
  #data_shp <-
  #  sp::over(data_spatial, sp::spTransform(shp, sp::CRS("+proj=longlat +datum=WGS84 +no_defs")))
  # shp_wgs84 <- sp::spTransform(shp, sp::CRS("+proj=longlat +datum=WGS84 +no_defs"))
  print('Setting geometry data to same CRS...')
  shp_wgs84 <- st_transform(shp, st_crs(data_spatial))
  ##print('Computing the intersection... This will take time...')
  ##data_shp <- sp::over(data_spatial, shp_wgs84) # FAILS: Error: unable to find an inherited method for function ‘over’ for signature ‘x = "SpatialPointsDataFrame", y = "sf"’
  ##data_shp <- st_intersection(shp_wgs84, data_spatial)
  ##print('Computing the intersection... Done.')
  # Error:
  #>   data_shp <- st_intersection(shp_wgs84, data_spatial)
  #Error in wk_handle.wk_wkb(wkb, s2_geography_writer(oriented = oriented,  : 
  #Loop 994 is not valid: Edge 18723 has duplicate vertex with edge 18736
  print('Check if geometries are valid...')
  if (!all(st_is_valid(shp_wgs84))) { # MANY ARE NOT!
    print('They are not! Making valid...')
    shp_wgs84 <- st_make_valid(shp_wgs84)  # SLOWISH
    print('Making valid done.')
  }
  print('Check if geometries are valid... Done.')
  print('Computing the intersection... This will take time...')
  print(paste0('Starting at  ', Sys.time()))
  data_shp <- st_intersection(shp_wgs84, data_spatial) # SLOOOOOW. CPU and RAM.
  print(paste0('Finishing at ', Sys.time()))
  print('Computing the intersection... Done.')

  # bind shapefile attributes to in situ data.frame
  res <- cbind(dpoints, data_shp)
  rm(data_spatial, data_shp)
  res
}

## Call the function:
out_data_rel_shp_attributes <- points_att_polygon(shp, data_rel, in_long_col_name, in_lat_col_name)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_data_rel_shp_attributes, file = out_result_path)


# Spatial: st_write(units, out_unitsCleanedFilePath)
# Tabular: fwrite(stationSamples, file = out_relevantStationSamplesPath)
