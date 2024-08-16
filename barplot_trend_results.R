### 6.2. barplot of trend analysis ####

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