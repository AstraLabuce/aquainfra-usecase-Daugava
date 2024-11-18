##############################################################################################.
## 5. trend_analysis Mann Kendall ####
##############################################################################################.
#RUN WITH
#Rscript trend_analysis_mk.R "data_out_selected_interpolated.csv" "season, polygon_id" "Year_adj_generated" "Secchi_m_mean_annual" "mk_trend_analysis_results.csv"

library(jsonlite)

trend_analysis_mk <- function(
    data,
    rel_cols,
    time_colname = "year",
    value_colname = "value"){
  
  if (!requireNamespace("Kendall", quietly = TRUE)) {
    stop("Package \"Kendall\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package \"tidyr\" must be installed to use this function.",
         call. = FALSE)
  }
  
  err = paste0("Error: `", value_colname, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(data)[, names(data) == value_colname]))
  err = paste0("Error: `", time_colname, "` is not numeric.")
  stopifnot(err =
              is.numeric(as.data.frame(data)[, names(data) == time_colname]))
  
  # Create empty vectors to store data
  table_names <- c()
  tau_values <- c()
  p_values <- c()
  period <- c()
  list_groups <-  vector("list", length(rel_cols))
  
  for (each in seq(rel_cols)){
    list_groups[[each]] <- 
      as.factor(subset(data, select = names(data) == rel_cols[each])[[1]])
  }
  data <- split(data, list_groups, sep = ";")
  # Remove elements with 0 rows from the list
  data <- data[sapply(data, function(x) dim(x)[1]) > 0]
  
  gap_check <- lapply(data, function(table) {
    calculate_missing_percentage <- function(table) {
      # Extract the years from the table
      years <- suppressWarnings(sort(as.numeric(as.character(
        get(time_colname, table)
      ))))
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
    
    if (missing_percentage == 0) {
      return(table)
    } else {
      return(NULL)
    }
  })
  
  if (length(names(gap_check[sapply(gap_check, is.null)])) > 0)
    stop(paste0("Error: gaps in time_colname period identified. Remove data group describing ", names(gap_check[sapply(gap_check, is.null)])," or add missing data"))
  
    # Loop through each table in sub_tables_subset
    for (table_name in names(data)) {
      # Extract the current table
      current_table <- data[[table_name]]
      time <- subset(current_table, select = names(current_table) == time_colname)
      values <- subset(current_table, select = names(current_table) == value_colname)
      # Create time series object
      time_series_object <- ts(values, frequency = 1, start = c(min(time), 1))
      
      # Perform Mann-Kendall test
      mann_kendall_test_results <- Kendall::MannKendall(time_series_object)
      
      # Extract tau-value and p-value
      tau <- mann_kendall_test_results$tau
      p_value <- mann_kendall_test_results$sl
      
      # Append data to vectors
      table_names <- c(table_names, table_name)
      tau_values <- c(tau_values, tau)
      p_values <- c(p_values, p_value)
      period <- c(period, paste0(min(time), ":", max(time)))
    }
    
    # Combine data into a data frame
    results_table <- data.frame(ID = table_names, period = period, Tau_Value = tau_values, P_Value = p_values)
    # REPLY: you are correct noting this! It could be anything defined in rel_cols variable,
    # it could be one and it could be e.g. four parameters. Here is more generic approach:
    # ID is generated in the script hence it should always be there before this line.
    results_table <- tidyr::separate(results_table, ID,  rel_cols, sep = ";")
    
    # Return the results table
    return(results_table)
}

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
input_data_path_or_url = args[1]
in_rel_cols = args[2] # e.g. "season, polygon_id"
in_time_colname = args[3]  # e.g. "Year_adj_generated"
in_value_colname = args[4] # e.g. "Secchi_m_mean_annual"
out_result_path = args[5]  # e.g. "mk_trend_analysis_results.csv"

# Remove spaces and split:
in_rel_cols = gsub(" ", "", in_rel_cols, fixed = TRUE)
in_rel_cols = strsplit(in_rel_cols, ",")[[1]] # e.g. "season, polygon_id"

# Read the input data from file - this can take a URL!
data_list_subgroups <- data.table::fread(input_data_path_or_url)

# Run the function "peri_conv"
out_mk <- trend_analysis_mk(data = data_list_subgroups,
                  rel_cols = in_rel_cols,
                  value_col = in_value_colname,
                  time_colname = in_time_colname)

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_mk , file = out_result_path)