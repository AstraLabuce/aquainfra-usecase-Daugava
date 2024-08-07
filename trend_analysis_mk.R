##############################################################################################.
## 5. trend_analysis Mann Kendall ####
##############################################################################################.
#RUN WITH
#Rscript trend_analysis_mk.R "data_out_selected_interpolated.csv" "season, polygon_id" "Year_adj_generated" "Secchi_m_mean_annual" "mk_trend_analysis_results.csv"

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path = args[1]
in_rel_cols = strsplit(args[2], ",")[[1]] #todo: remove spaces if available. otherwise can result in subscript out of bounds error
in_time_colname = args[3]
in_value_colname = args[4]
out_result_path = args[5]

data_list_subgroups <- data.table::fread(in_data_path)


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
  err = paste0("Error: `", in_time_colname, "` is not numeric.")
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
    results_table <- tidyr::separate(results_table, ID, c("season", "polygon_id"), sep = ";")
    
    # Print the results table
    return(results_table)
}   
    
out_mk <- trend_analysis_mk(data = data_list_subgroups,
                  rel_cols = in_rel_cols,
                  value_col = in_value_colname,
                  time_colname = in_time_colname)

## Output: Now need to store output:
print(paste0('Write result to csv file: ', out_result_path))
data.table::fwrite(out_mk , file = out_result_path) 