##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## Can we use Datamash function for this in Galaxy workflows? ################################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the data analysis##################.
##############################################################################################.
## RUN WITH
## Rscript mean_by_group.R "data_out_peri_conv.csv" "data_out_seasonal_means.csv"

library(dplyr)

mean_by_group <- function(data, cols_to_group_by = "group", value_col = "value") {
  if (missing(data))
    stop("missing data")
  if (missing(cols_to_group_by))
    stop("missing cols_to_group_by")
  err = paste0("Error: `", value_col, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(data)[, names(data) == value_col]))
  print('calculating mean_by_group')

  data <- as.data.frame(data)[, names(data) %in% cols_to_group_by | names(data) == value_col]
  groups <- as.data.frame(unique(as.data.frame(data)[, ! names(data) == value_col]))
  groups$group_id <- seq(from = 1, to = dim(groups)[1], by = 1)
  data <- left_join(data, groups, by = cols_to_group_by)
  groups_mean <- aggregate(subset(data, select = names(data) == value_col), list(data$group_id), FUN=mean)
  colnames(groups_mean)[1] <- "group_id"
  out_means <- left_join(groups, groups_mean, by = "group_id")
  out_means <- select(out_means, -group_id)
  out_means
}

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
input_data_path = args[1]
in_cols_to_group_by = args[2] # e.g. "Year_adj_generated, group_labels, HELCOM_ID"
in_value = args[3] # e.g. "mean"
output_data_path = args[4]
# Read the input data from file - this can take a URL!
data_mean_by_group <- data.table::fread(input_data_path)

in_cols_to_group_by = strsplit(in_cols_to_group_by, ",")[[1]] # e.g. "season, polygon_id"

# Run the function "mean_by_group"
out_means <- mean_by_group(data_mean_by_group,
    cols_to_group_by = in_cols_to_group_by, value = in_value)


# Write the result to csv file:
print(paste0('Write result to csv file: ', output_data_path))
data.table::fwrite(out_means , file = output_data_path)