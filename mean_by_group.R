##############################################################################################.
## 3. mean_by_group ####
## calculate data average per site, per year, per season and per HELCOM_ID ###################.
## Can we use Datamash function for this in Galaxy workflows? ################################.
## if we cannot - I will work more on this. ##################################################.
## At the moment, quick and easy version, just to continue the data analysis##################.
##############################################################################################.
## RUN WITH
## Rscript mean_by_group.R "data_out_peri_conv.csv" "data_out_seasonal_means.csv"

library(magrittr)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
input_data_path = args[1]
output_data_path = args[2]

data_mean_by_group <- data.table::fread(input_data_path)
data_mean_by_group$transparency_m <- as.numeric(data_mean_by_group$transparency_m)

out_seasonal_means <- data_mean_by_group %>%
  group_by(longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean = mean(transparency_m)) %>%
  ungroup() %>% 
  group_by(Year_adj_generated, group_labels, HELCOM_ID) %>%
  summarise(Secchi_m_mean_annual = mean(Secchi_m_mean)) %>%
  ungroup()

print(paste0('Write result to csv file: ', output_data_path))
data.table::fwrite(out_seasonal_means , file = output_data_path)
