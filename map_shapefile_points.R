
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
