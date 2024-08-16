##############################################################################################.
## 4. TimeSeries selection and interpolation of NAs ####
##############################################################################################.
## RUN WITH
## Rscript ts_selection_interpolation.R "data_out_seasonal_means.csv" "group_labels,HELCOM_ID" 40 "Year_adj_generated" "Secchi_m_mean_annual" 10 "data_out_selected_interpolated.csv"

library(zoo)
library(tidyr)

# split data into sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency
ts_selection_interpolation <- function(
    data,
    rel_cols,
    missing_threshold = 30,
    year_col = "Year",
    value_col = "value",
    min_data_point = 10){
  
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package \"tidyr\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("zoo", quietly = TRUE)) {
    stop("Package \"zoo\" must be installed to use this function.",
         call. = FALSE)
  }

  list_groups <-  vector("list", length(rel_cols))
  
  for (each in seq(rel_cols)){
    list_groups[[each]] <- as.factor(subset(data, select = names(data) == rel_cols[each])[[1]])
  }
  sub_tables <- split(data, list_groups, sep = ";")
  
  # Some tables have too many missing years, therefore it is necessary to remove them from the analysis. 
  # In the example, the treshold for the removal is 40% of timeseries years missing.
  
  sub_tables_subset <- lapply(sub_tables, function(table) {
    
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
    
    if (missing_percentage <= missing_threshold) {
      return(table)
    } else {
      return(NULL)
    }
  })
  
  # Remove NULL elements from the list
  sub_tables_subset <- Filter(Negate(is.null), sub_tables_subset)
  
  # Loop through each table in sub_tables_subset a function for extending 
  # the dataframes by missing years
  # object for results
  sub_tables_subset_out <- list()
  
  for (table_name in names(sub_tables_subset)) {
    
    # Extract the table
    table_data <-
      as.data.frame(sub_tables_subset[[table_name]])
    
    # Convert Year_corrected to numeric
    table_data$Year_d <-
      as.numeric(as.character(table_data[, which(names(table_data) == year_col)]))
    
    # Assign the extended table back to the list
    processed_table <- 
      as.data.frame(tidyr::complete(table_data, Year_d = min(table_data$Year_d):max(table_data$Year_d)))
    
  ## interpolate NAs
  # Loop through each table in sub_tables_subset_out
  
  #for (table_name in names(sub_tables_subset_out)) {
    #processed_table <- sub_tables_subset_out[[table_name]]
    processed_table <- 
      subset(processed_table, select = names(processed_table) %in% c(year_col, value_col), drop = FALSE)

    # Apply zoo::na.approx() to fill gaps if there are at least two non-NA values
    if (sum(!is.na(subset(processed_table, select = names(processed_table) == value_col)[[1]])) >= 2) {
      filled_table <- as.data.frame(zoo::na.approx(processed_table))
      filled_table$ID <- rep(table_name, dim(filled_table)[1])
      sub_tables_subset_out[[table_name]] <- as.data.frame(filled_table)
    } else {
      sub_tables_subset_out[[table_name]] <-
        paste("Insufficient non-NA values to interpolate")
    }
  }
  
  #Remove datasets that has less than set threshold time-period points (default 10)
  short_datasets <- lapply(sub_tables_subset_out, dim)
  sub_tables_subset_out <- 
    sub_tables_subset_out[unname(unlist(sapply(short_datasets, function(i) lapply(i, "[[", 1))[1,]) > min_data_point)]
  # transform list to data.frame
  res <- data.frame(Reduce(rbind, sub_tables_subset_out))
  res <- tidyr::separate(res, ID, c("season", "polygon_id"), sep = ";")
  
  return(res)
}
