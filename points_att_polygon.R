## Args
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_shp_path = args[1]
in_dpoints_path = args[2]
in_long_col_name = args[3]
in_lat_col_name = args[4]
out_result_path = args[5]

# How to call this from command line:
#PATH_SHP="/home/.../test_inputs/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp"
#PATH_XLSX="/home/.../test_inputs/in_situ_example.xlsx"
#PATH_OUT="/home/.../test_outputs/mytestoutput.csv"
#/usr/bin/Rscript --vanilla /home/.../points_att_polygon.R ${PATH_SHP} ${PATH_XLSX} "longitude" "latitude" ${PATH_OUT}

#library(rgdal) # Outdated! See: https://cloud.r-project.org/web/packages/rgdal/index.html
library(sf)
library(janitor)
library(dplyr)

#shapefile <- rgdal::readOGR(in_shp_path) #"SpatialPolygonsDataFrame"
shapefile <- st_read(in_shp_path)


# locate in situ data set manually
# load in situ data and respective metadata (geolocation and date are mandatory metadata)
# example data
data_raw <- readxl::read_excel(in_dpoints_path) %>% #example data from https://latmare.lhei.lv/
  janitor::clean_names() # makes column names clean for R

#############.
# this is for our local full data set
# data_raw <-
#   readxl::read_excel("in_situ_data/Latmare_20240111_secchi_color.xlsx") %>% #datafvrom LIAE data base from https://latmare.lhei.lv/
#   janitor::clean_names() # makes column names clean for R
#############.

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
#rm(rel_columns, data_rel_spatial, data_shp_over)

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
  data_spatial <- sf::st_as_sf(dpoints, coords = c(long_col_name, lat_col_name))
  # set to WGS84 projection
  sf::st_crs(data_spatial) <- 4326
  # make in situ points spatial
  #data_spatial <- as(data_spatial, 'Spatial')
  
  # overlay shapefile and in situ locations
  #data_shp <-
  #    sp::over(data_spatial, sp::spTransform(shp, sp::CRS("+proj=longlat +datum=WGS84 +no_defs")))
  # Runs into this error:
  #   error in evaluating the argument 'y' in selecting a method for function 'over':
  #   unable to find an inherited method for function ‘spTransform’ for signature
  #   ‘x = "sf", CRSobj = "CRS"’
  # So instead, I use st_intersection:
  shp_wgs84 <- st_transform(shp, st_crs(data_spatial))
  print('Check if geometries are valid...')# TODO: Check actually needed? Maybe just make valid!
  if (!all(st_is_valid(shp_wgs84))) { # many are not (in the example data)!
    print('They are not! Making valid...')
    shp_wgs84 <- st_make_valid(shp_wgs84)  # slowish...
    print('Making valid done.')
  }
  data_shp <- st_intersection(shp_wgs84, data_spatial) # SLOOOOOW. CPU and RAM.
  # bind shapefile attributes to in situ data.frame
  res <- cbind(dpoints, data_shp)
  rm(data_spatial, data_shp)
  res
}

## Call the function:
out_data_rel_shp_attributes <- points_att_polygon(
  shapefile, data_rel, in_long_col_name, in_lat_col_name)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_data_rel_shp_attributes, file = out_result_path)

