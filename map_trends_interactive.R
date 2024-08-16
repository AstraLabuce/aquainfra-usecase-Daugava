### 6.3. trend result map ####
# plot a map of trend results
### interactive map

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
