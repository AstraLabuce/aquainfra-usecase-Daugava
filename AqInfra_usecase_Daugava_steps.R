### Aquainfra project 
### This project has received funding from the European Commission?s Horizon
#### Europe Research and Innovation programme under grant agreement No 101094434.

### WP5 Use case: Baltic Sea Daugava-Gulf of Riga: shapefile attributes as grouping parameter
### Latvian Institute of Aquatic Ecology

# before running this script download shapefile from and store in your local directory:
# https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48

# load libraries
# versions has to be set stationary! not done at the moment
if (!require("pacman")) install.packages("pacman")
pacman::p_load(readxl, 
               dplyr, 
               magrittr, 
               reshape2, 
               rgdal, sp, 
               readxl, 
               sf,
               janitor, 
               rstudioapi,
               lubridate,
               tidyr,
               zoo,
               Kendall,
               ggplot2,
               ggsci,
               broom,
               ggpubr,
               Cairo)



# working directory ####
# automatic setting wd to the folder where current script file is
current_path = rstudioapi::getActiveDocumentContext()$path 
setwd(dirname(current_path ))
#print( getwd() ) # uncomment for checking

# load HELCOM shapefile for subbasins and adjust to the chosen projection
# locate shapefile manually
# example for HELCOM subbasin L4 shp: 
## download at https://maps.helcom.fi/website/MADS/download/?id=67d653b1-aad1-4af4-920e-0683af3c4a48 
shapefile <- readOGR("shp/HELCOM_subbasins_with_coastal_WFD_waterbodies_or_watertypes_2018.shp") 
shp <- spTransform(shapefile, CRS("+proj=longlat +datum=WGS84 +no_defs"))

# locate in situ data set manually
# load in situ data and respective metadata (geolocation and date are mandatory metadata)
# example data
#data_raw <- readxl::read_excel("in_situ_data/in_situ_example.xlsx") %>% #example data from https://latmare.lhei.lv/
#  janitor::clean_names() # makes column names clean for R
data_raw <- readxl::read_excel("in_situ_data/Latmare_20240111_secchi_color.xlsx") %>% #datafvrom LIAE data base from https://latmare.lhei.lv/
  janitor::clean_names() # makes column names clean for R

#list relevant columns: geolocation (lat and lon), date and values for data points are mendatory
rel_columns <- c("longitude", "latitude", #coordinates
                 "visit_date", #date
                 "measured_depth_m", #optional 
                 "transparency_m", #Secchi depth in meters (numeric)
                 "color_id" #water color hue in Furel-Ule (categories)
                 )

# relevant data
data_rel <- data_raw %>%
  #select only relevant columns
  select(all_of(rel_columns)) %>%
    # remove cases when Secchi depth, water colour were not measured
   filter(!is.na(`transparency_m`) & !is.na(`color_id`)& !is.na(`longitude`)& !is.na(`latitude`)) # make sure to use correct column names

# set coordinates ad numeric (in case they are read as chr variables)
data_rel$`longitude` <- as.numeric(data_rel$`longitude`)
data_rel$`latitude` <- as.numeric(data_rel$`latitude`)

# make data points spatial
data_rel_spatial <- st_as_sf(data_rel, coords = c("longitude","latitude"))

# set to WGS84 projection
st_crs(data_rel_spatial) <- 4326
# make in situ points spatial
data_rel_spatial <- as(data_rel_spatial, 'Spatial')

# overlay shapefile and in situ locations
data_shp_over <- sp::over(data_rel_spatial, shp)

# bind shapefile attributes to in situ data.frame
data_rel_shp_attributes <- cbind(data_rel, data_shp_over)

################################################################################
#STEP 2: group data by seasons
################################################################################
#create new columns of the 'Day','Month' and 'Year'
data_rel_shp_attributes$visit_date<-as.POSIXct(data_rel_shp_attributes$visit_date)

data_rel_shp_attributes$Month<-month(data_rel_shp_attributes$visit_date)
data_rel_shp_attributes$Year<-year(data_rel_shp_attributes$visit_date)
data_rel_shp_attributes$Day<-day(data_rel_shp_attributes$visit_date)

#change year indication for December observations in order to assign it to the correct season
data_rel_shp_attributes$Year_corrected <- ifelse(data_rel_shp_attributes$Month == 12, 
                                                 data_rel_shp_attributes$Year + 1, 
                                                 data_rel_shp_attributes$Year)

#create new column 'Season'
data_rel_shp_attributes$Season <- ifelse(data_rel_shp_attributes$Month %in% c(4, 5)|
                                           (data_rel_shp_attributes$Month == 3 & data_rel_shp_attributes$Day > 15), "Spring",
                                            ifelse(data_rel_shp_attributes$Month %in% c(6, 7, 8), "Summer",
                                                   ifelse(data_rel_shp_attributes$Month %in% c(12, 1, 2) | 
                                                            (data_rel_shp_attributes$Month == 3 & data_rel_shp_attributes$Day <= 15), "Winter", "Autumn")))


################################################################################
#STEP 3: calculate data average per year, per season and per HELCOM_ID
################################################################################
data_rel_shp_attributes$HELCOM_ID<-as.factor(data_rel_shp_attributes$HELCOM_ID)
data_rel_shp_attributes$Year_corrected<-as.factor(data_rel_shp_attributes$Year_corrected)
data_rel_shp_attributes$Season<-as.factor(data_rel_shp_attributes$Season)
data_rel_shp_attributes$transparency_m<-as.numeric(data_rel_shp_attributes$transparency_m)
data_rel_shp_attributes$color_id<-as.numeric(data_rel_shp_attributes$color_id)

Transarency_m_mean<-aggregate(transparency_m ~ longitude+latitude +Year_corrected+Season+HELCOM_ID, data = data_rel_shp_attributes, FUN = mean, na.rm = TRUE)
Transarency_m_mean2<-aggregate(transparency_m ~ Year_corrected+Season+HELCOM_ID, data = Transarency_m_mean, FUN = mean, na.rm = TRUE)

Color_id_median<-aggregate(cbind(color_id) ~ longitude+latitude +Year_corrected+Season+HELCOM_ID, data = data_rel_shp_attributes, FUN = median, na.rm = TRUE)

################################################################################
#STEP 4: Interpolation of NAs
################################################################################

#split data onto sub-tables for each season and HELCOM_ID separately
# Create a list to store sub-tables of transparency
sub_tables <- split(Transarency_m_mean2, list(Transarency_m_mean2$Season, Transarency_m_mean2$HELCOM_ID))

#Some tables have too many missing years, therefore it is necessary to filter them out. In the example, the treshold is 30% of missing years of the total consequence.

#create a function for which will calculate a percentage of missing years
calculate_missing_percentage <- function(table) {
  # Extract the years from the table
  years <- as.numeric(as.character(table$Year_corrected))
  
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

#filter out the tables where part of missing years is above 30% percentage
filtered_tables <- lapply(sub_tables, function(table) {
  missing_percentage <- calculate_missing_percentage(table)
  
  if (missing_percentage <= 40) {#can be modified as required
    return(table)
  } else {
    return(NULL)
  }
})

# Remove NULL elements from the list
sub_tables_subset <- Filter(Negate(is.null), filtered_tables)

# Show the filtered tables
summary(sub_tables_subset)


#library(tidyr), probably it competes with dplyr if it was not fixed

# Loop through each table in sub_tables_subset a function for extending the dataframes by missing years
for (table_name in names(sub_tables_subset)) {
  # Extract the table
  table_data <- as.data.frame(sub_tables_subset[[table_name]])
  
  # Convert Year_corrected to numeric
  table_data$Year_corrected <- as.numeric(as.character(table_data$Year_corrected))
  
  # Extend the data frame
  extended_table <- complete(table_data, Year_corrected = min(table_data$Year_corrected):max(table_data$Year_corrected))
  
  # Assign the extended table back to the list
  sub_tables_subset[[table_name]] <- extended_table
}

# Check the result for one table 
print(sub_tables_subset[4])


#interpolate the transparency 
# Loop through each table in sub_tables_subset
for (table_name in names(sub_tables_subset)) {
  # Remove the Season and HELCOM_ID columns
  processed_table <- sub_tables_subset[[table_name]] %>% 
    select(-Season, -HELCOM_ID)
  
  # Apply na.approx() to fill gaps if there are at least two non-NA values
  if (sum(!is.na(processed_table$transparency_m)) >= 2) {
    filled_table <- na.approx(processed_table)
    sub_tables_subset[[table_name]] <- filled_table
  } else {
    cat("Insufficient non-NA values to interpolate in", table_name, "\n")
  }
}

print(sub_tables_subset[4])
################################################################################
#STEP 5: Mann-Kendall test for transparency and the table with results
################################################################################

# Create empty vectors to store data
table_names <- c()
tau_values <- c()
p_values <- c()

# Loop through each table in sub_tables_subset
for (table_name in names(sub_tables_subset)) {
  # Extract the current table
  current_table <- sub_tables_subset[[table_name]]
  
  # Convert columns to numeric if they are not already
  current_table[, "Year_corrected"] <- as.numeric(as.character(current_table[, "Year_corrected"]))
  current_table[, "transparency_m"] <- as.numeric(as.character(current_table[, "transparency_m"]))
  
  # Create time series object
  TS <- ts(current_table[, "transparency_m"], frequency = 1, start = c(min(current_table[, "Year_corrected"]), 1))
  
  # Perform Mann-Kendall test
  MK_Test <- MannKendall(TS)
  
  # Extract tau-value and p-value
  tau <- MK_Test$tau
  p_value <- MK_Test$sl
  
  # Append data to vectors
  table_names <- c(table_names, table_name)
  tau_values <- c(tau_values, tau)
  p_values <- c(p_values, p_value)
}

# Combine data into a data frame
results_table <- data.frame(Table = table_names, Tau_Value = tau_values, P_Value = p_values)

# Print the results table
print(results_table)

################################################################################
#STEP 6: Plot results
################################################################################
str(results_table)
results_table$Table<-as.factor(results_table$Table)
# Add the polygon column
results_table$HELCOM_ID <- sub(".*\\.(.*)", "\\1", results_table$Table)
# Replace '-' with '_'
#results_table$polygon <- gsub("-", "_", results_table$polygon)

# Add the Season column
results_table$Season <- substring(results_table$Table, 1, regexpr("\\.", results_table$Table) - 1)

# Reorder the levels of the Season column
results_table$Season <- factor(results_table$Season, levels = c("Winter", "Spring", "Summer", "Autumn"))


#plot the result for trasparency
barplot_alldata<-ggplot(aes(x=HELCOM_ID, y=Tau_Value), data=results_table)+
  geom_bar(aes(fill = Season, alpha = P_Value > 0.05),
           width=0.6,
           position = position_dodge(width=0.6),
           stat = "identity")+
  scale_alpha_manual(values = c(1, 0.3), guide = FALSE) +  # Adjust the transparency if necessary
  scale_fill_npg()+
  annotate("text", x = 0.5, y = -Inf, label = "Blurred bars indicate statistically \n insignificant changes over time",
           vjust = -1, hjust = 0, size = 3) +  # Add annotation
  labs(x = "Polygons according to the HELCOM shapefile", y = "Tau-value from Mann-Kendall test") +
  ggtitle('Results from time series analysis \nfor polygons and seasons containing <40% \nof missing years per observation period')+
  theme_bw()+
  theme(axis.text.y = element_text(size=12),
        axis.text.x = element_text(size=12, angle = 90),
        axis.title = element_text(size=12),
        title = element_text(size=12),
        legend.text = element_text(size=12),
        legend.title = element_text(size=12))
print(barplot_alldata)

#plot a map

# Convert selected_shp to a tidy format
# Define the HELCOM_IDs you want to include
selected_ids <- levels(as.factor(results_table$HELCOM_ID))

# Subset the shapefile to include only the selected HELCOM_IDs
selected_shp <- shp[shp$HELCOM_ID %in% selected_ids, ]

selected_shp_tidy <- tidy(selected_shp)
b <- cbind(HELCOM_ID = selected_shp@data$HELCOM_ID, id = rownames(selected_shp@data)) #Astra
selected_shp_tidy <- left_join(selected_shp_tidy, as.data.frame(b), by="id") # Astra
rm(b) #Astra
selected_shp_tidy <- left_join(selected_shp_tidy, selected_shp@data, by = ("HELCOM_ID")) #Astra

#add information from Mann-Kendall test to the shape data for mapping
joined_data <- left_join(selected_shp_tidy, results_table, by = c("HELCOM_ID" = "HELCOM_ID"))

#add condition of polygon fill color in a new column
joined_data <- joined_data %>%
  mutate(fill_color = ifelse(is.na(Tau_Value) | is.na(P_Value), "white", # For missing values
                             ifelse(P_Value > 0.05, "grey",#Non-significant P_Value
                                    ifelse( P_Value <= 0.05&Tau_Value < 0 , "red",  # Negative Tau_Value and significant P_Value
                                            ifelse(P_Value <= 0.05&Tau_Value > 0 , "blue",  # Positive Tau_Value and significant P_Value
                                                   "green")  # for error
                                           )
                                    )
                             )
         )

#convert to factors
joined_data$fill_color<-as.factor(joined_data$fill_color)


# Filter for a season with maximal number of cases in the table with results of Mann-kendall test
subset_data <- results_table[results_table$P_Value <= 0.05, ]
factor_counts <- table(subset_data$Season)
max_level <- names(factor_counts)[which.max(factor_counts)]

#filter data for the selected season
selected_shp_tidy_max_data <- joined_data %>% filter(Season == max_level)

#create a fill color and label condition for the future plot
color_condition <- data.frame(
  col_values = levels(selected_shp_tidy_max_data$fill_color))
color_condition <- color_condition %>%
  mutate( col_labels = ifelse(is.na(levels(selected_shp_tidy_max_data$fill_color)), "No data", 
                              ifelse(levels(selected_shp_tidy_max_data$fill_color) == "grey", "P > 0.05",
                                     ifelse(levels(selected_shp_tidy_max_data$fill_color) == "red", "Negative Tau, P < 0.05", 
                                            ifelse(levels(selected_shp_tidy_max_data$fill_color) == "blue", "Positive Tau, P < 0.05",
                                                   "Error")
                                     )
                              )
  )
  )

# Create a plot showing a map with Mann-Kendall results
plot_map_max_data <- ggplot(selected_shp_tidy_max_data, aes(x = long, y = lat, group = group, fill = fill_color)) +
  geom_polygon(color = "black", size = 0.1) +
  coord_map("azequidistant") +
  scale_x_continuous(breaks = seq(21.7,24.5, by = 0.7), labels=seq(21.7,24.5,0.7))+
  scale_y_continuous(breaks = seq(57,59, by = 0.4),labels = seq(57,59,0.40)) +
  theme_void() +
  labs(title = paste("HELCOM subbasins in the Gulf of Riga -", max_level)) +
  theme(panel.grid.major = element_line(colour = "grey"),
        panel.border = element_blank(),
        axis.text = element_text()) +
  
  scale_fill_manual(values = color_condition$col_values,
                    labels = color_condition$col_labels)+
  labs(fill = "Results of Mann-Kendall test")

# Print the plot
print(plot_map_max_data)

#create a plot with map of HELCOM subbasins
plot_subbasins <- ggplot(joined_data, aes(x = long, y = lat, group = group, fill = HELCOM_ID)) +
  geom_polygon(color = "black", size = 0.1) +
  coord_map("azequidistant") +
  scale_x_continuous(breaks = seq(21.7,24.5, by = 0.7), labels=seq(21.7,24.5,0.7))+
  scale_y_continuous(breaks = seq(57,59, by = 0.4),labels = seq(57,59,0.40)) +
  theme_void() +
  labs(title = "HELCOM subbasins in the Gulf of Riga") +
  theme(panel.grid.major = element_line(colour = "grey"),
        panel.border = element_blank(),
        axis.text = element_text()) +
  labs(fill = "HELCOM_ID")


# Print the plot
print(plot_subbasins)

# Create a table plot with Mann-Kendall rwsults
library(gridExtra)
# Set theme to allow for plotmath expressions
printing_table<-results_table[,-1]
printing_table <- printing_table[, c(3, 4, 1, 2)]
tt <- ttheme_default(colhead=list(fg_params = list(parse=TRUE)))
tbl <- tableGrob(printing_table, rows=NULL, theme=tt)

###############################################################################
#Print results
##############################################################################
#arrange all results on one plot
transparency_results<-ggarrange(ggarrange(tbl, barplot_alldata,ncol = 2, labels = c("A", "B")) ,                                               # First row with table
          ggarrange(plot_map_max_data, plot_subbasins, ncol = 2, labels = c("C", "D"),heights = c(1, 0.85),widths=c(1, 0.85)), # Second row with map and barplot
          nrow = 2                                        # Labels of the scatter plot
) +
  theme(
    plot.background = element_rect(fill = "white"),   # Change plot background color
    panel.background = element_rect(fill = "white")   # Change panel background color
  )
print(transparency_results)

#save the plot with results
ggsave(transparency_results, file="transparency_results.png", type="cairo-png", dpi = 300,
       width = 25, height = 20, units = "cm")
###############################################################################
# END FOR TRANSPARENCY ANALYSIS
###############################################################################