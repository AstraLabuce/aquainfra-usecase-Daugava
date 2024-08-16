# aquainfra-usecase-Daugava

 Description TODO

 ! All the work contained in this repository is work in progress and
   in pre-alpha state.

The functionality is divided into various functions, where the result
of one function is used as the input to the next one.

1. points_att_polygon
1. peri_conv
1. mean_by_group
1. ts_selection_interpolation
1. trend_analysis_mk
1. Some visualisations...

The main script is `AqInfra_usecase_Daugava_functions.R`, which you can run
after adapting the paths to inputs/ouputs inside the file.

You can also run each function separately from command line, like this:

```
# 1
Rscript points_att_polygon_wrapper.R "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip" "https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx" "longitude" "latitude" "data_out_point_att_polygon.csv"

# 2
Rscript peri_conv_wrapper.R "data_out_point_att_polygon.csv" "visit_date" "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30" "winter,spring,summer,autumn" TRUE "data_out_peri_conv.csv"

# 3
Rscript mean_by_group.R "data_out_peri_conv.csv" "data_out_seasonal_means.csv"

# 4
Rscript ts_selection_interpolation_wrapper.R "data_out_seasonal_means.csv" "group_labels,HELCOM_ID" 40 "Year_adj_generated" "Secchi_m_mean_annual" 10 "data_out_selected_interpolated.csv"

# 5
Rscript trend_analysis_mk_wrapper.R "data_out_selected_interpolated.csv" "season,polygon_id" "Year_adj_generated" "Secchi_m_mean_annual" "mk_trend_analysis_results.csv"

# 6.1: map_shapefile_points
Rscript map_shapefile_points_wrapper.R "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp" "data_out_point_att_polygon.csv" "longitude" "latitude" "transparency_m" "HELCOM_ID" "map_shapefile_insitu.html"

# 6.2: barplot_trend_results
Rscript barplot_trend_results_wrapper.R "mk_trend_analysis_results.csv" "polygon_id" "Tau_Value" "P_Value" "0.05" "season" "barplot_trend_results.png"

# 6.3: map_trends_interactive
Rscript map_trends_interactive_wrapper.R "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp" "mk_trend_analysis_results.csv" "polygon_id" "HELCOM_ID" "season" "P_Value" "0.05" "map_trends_interactive.html"

# 6.4: map_trends_static
Rscript map_trends_static_wrapper.R "shp/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp" "mk_trend_analysis_results.csv" "polygon_id" "HELCOM_ID" "season" "P_Value" "0.05" "map_trend_results.png"

```

For this, you should have a `config.json` in your current working directory that
points the script to the input data directory:

```
cat config.json
{
    "input_data_dir": "/home/donaldduck/example_inputs/",
}
```


These R packages must be installed in order to run the functionality in
this repository:

```
install.packages("sf")
install.packages("dplyr")
install.packages("janitor")
install.packages("jsonlite")
install.packages("data.table")
install.packages("sp")
install.packages("readxl")
install.packages("zoo")
install.packages("Kendall")

# For the visualisations:
install.packages("mapview")
install.packages("webshot")
install.packages("pandoc")
install.packages("viridis")
install.packages("tmap")
install.packages("rosm")


```

## OGC processes

It is possible to install the functionality, or parts of it, as OGC processing
services using pygeoapi. That way, they can be called via http.

The `<name>.py` files in this repository contain the python modules that act as
wrapper to the functionality in the `<name>.R` functions, and the `<name>.json`
files contain the necessary metadata.

To run the python files, a `config.json` file is needed. The program looks for it
at the location given in the environment variable `DAUGAVA_CONFIG_FILE` which can
be set using `export DAUGAVA_CONFIG_FILE=/home/something/myconfig.json`. If that
environment variable is not set, the program looks in its current working dir
(`./config.json`)

To test an instance of this, you can use the
python script `pygeoapi_documentation/test_post_requests.py` .

For help and more details, please contact the AquaINFRA project.

