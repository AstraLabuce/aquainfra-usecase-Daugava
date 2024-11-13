get_relevant_data <- function(raw_data) {

# list relevant columns: geolocation (lat and lon), date and values for data points are mandatory
rel_columns <- c(
  "longitude",
  "latitude",
  "visit_date",
  "transparency_m",
  "color_id" #water color hue in Furel-Ule (categories)
)

data_relevant <- raw_data %>%
  dplyr::select(all_of(rel_columns)) %>%
  # remove cases when Secchi depth, water colour were not measured
  filter(
    !is.na(`transparency_m`) &
      !is.na(`color_id`) &
      !is.na(`longitude`) &
      !is.na(`latitude`)
  )

  # set coordinates ad numeric (in case they are read as chr variables)
  data_relevant <- data_relevant %>%
    mutate(
      longitude  = as.numeric(longitude),
      latitude   = as.numeric(latitude),
      transparency_m = as.numeric(transparency_m)
    )

  return(data_relevant)
}
