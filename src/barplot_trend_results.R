### 6.2. barplot of trend analysis ####

library(ggplot2)
library(jsonlite)

#plot the result for transparency
barplot_trend_results <- function(data, 
                            id = "polygon_id", 
                            test_value = "value",
                            p_value = "p_value",
                            p_value_threshold = 0.05,
                            group = "group"){
  
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package \"ggplot2\" must be installed to use this function.",
         call. = FALSE)
  }
  if (!requireNamespace("viridis", quietly = TRUE)) {
    stop("Package \"viridis\" must be installed to use this function.",
         call. = FALSE)
  }
  # ggplot(aes(x=data[,which(names(data) == id)], #why which is not working properly??
  #            y=data[,which(names(data) == test_value)]), 
  #        data=data)+
  #   geom_bar(aes(fill = data[,which(names(data) == group)], 
  #                alpha = data[,which(names(data) == p_value)] > p_value_threshold),
  #            width=0.6,
  #            position = position_dodge(width=0.6),
  #            stat = "identity")+
    
  ggplot(aes(
    x = subset(data, select = names(data) == id)[[1]],
    y = subset(data, select = names(data) == test_value)[[1]]
  ), data = data) +
    geom_bar(
      aes(
        fill = subset(data, select = names(data) == group)[[1]],
        alpha = subset(data, select = names(data) == p_value)[[1]] > p_value_threshold
      ),
      width = 0.6,
      position = position_dodge(width = 0.6),
      stat = "identity"
    ) +
    scale_alpha_manual(values = c(1, 0.35), guide = "none") +
    viridis::scale_fill_viridis(discrete = TRUE) +
    theme_minimal() +
    labs(
      x = paste(id),
      y = paste(test_value),
      fill = paste(group),
      caption = "*Translucent bars indicate statistically insignificant results"
    ) +
    theme_bw(base_size = 12) +
    theme(legend.position = "top")
}

# Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_data_path_or_url <- args[1] # e.g. "mk_trend_analysis_results.csv"
in_id_col <- args[2] # e.g. "polygon_id"
in_test_value <- args[3] # e.g. "Tau_Value"
in_p_value <- args[4] # e.g. "P_Value"
in_p_value_threshold <- args[5] # e.g. "0.05"
in_group <- args[6] # e.g. "season"
out_result_path <- args[7] # e.g. "barplot_trend_results.png"

# Read input data

# Read the input data from file - this can take a URL!
data_list_subgroups <- data.table::fread(in_data_path_or_url)

# Call the function:
#plot the result for transparency
barplot_trends <- barplot_trend_results(data = data_list_subgroups,
                      id = in_id_col,
                      test_value = in_test_value,
                      p_value = in_p_value,
                      p_value_threshold = in_p_value_threshold,
                      group = in_group)

# Write the result to csv file:
print(paste0('Write result to csv file: ', out_result_path))
ggsave(barplot_trends, file = out_result_path, dpi = 300)