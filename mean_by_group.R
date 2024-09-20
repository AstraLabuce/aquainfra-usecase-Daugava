##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## Can we use Datamash function for this in Galaxy workflows? ################################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the data analysis##################.
##############################################################################################.
## RUN WITH
## Rscript mean_by_group.R "data_out_peri_conv.csv" "data_out_seasonal_means.csv"

library(data.table)

mean_by_group <- function(data, cols_to_group_by = "group", value = value) {
  if (missing(data))
    stop("missing data")
  if (missing(cols_to_group_by))
    stop("missing cols_to_group_by")
  
  err = paste0("Error: `", value, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(data)[, names(data) == value]))
  
  print('caluclating mean_by_group')
  out_means <- data[ ,list(mean=mean(as.data.frame(data)[, names(data) == value])), by=cols_to_group_by]
  out_means
}