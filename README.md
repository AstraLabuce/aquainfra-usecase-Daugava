# A Toolbox for Spatiotemporal Trend Detection Analysis

# MyBinder
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/AstraLabuce/aquainfra-usecase-Daugava/containerize)
 
# Description

This toolbox provides a set of predefined functions designed for spatiotemporal trend detection analysis, enabling reproducible data processing, statistical assessment, and visualisation of the results. It serves as the computational backbone of the workflow, supporting the identification of long-term trend across spatial and temporal scales.

Developed in the open-source R scripting language, the toolbox consists of seven functions that automate key steps in data preprocessing, trend analysis, and visualization:

Data Preprocessing:
a) Spatial aggregation: Assigns in situ environmental data points to spatial units based on polygon boundaries (function: points-att-polygon).
b) Temporal aggregation: Groups data points by time intervals for structured trend analysis (function: points-att-time).

Time Series Processing and Selection:
c) Calculating mean values by group (function: mean-by-group)
d) Selecting time series with sufficient data and interpolating missing values (NAs) to generate structured time series datasets optimized for trend detection (functions: ts-selection-interpolation).

Trend Detection:
e) Mann-Kendall analysis for statistically assessing long-term trends in environmental parameters across spatial units (function: trend-analysis-mk).

Visualization:
f) Interactive map generation for visualizing in situ data points over spatial assessment units (function: map-shapefile-points)
g) Trend representation in a static bar plot summarizing detected significant trends (function: barplot-trend-results).

This modular and adaptable toolbox is applicable to various environmental studies, beyond the Gulf of Riga (Baltic Sea) use case, where it has been applied to analyze water transparency (Secchi depth) trends.

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

## Building Docker image

```
git clone https://github.com/AstraLabuce/aquainfra-usecase-Daugava.git

cd aquainfra-usecase-Daugava

docker build -t daugava-workflow-image .
```

## Running functions via Docker 

`docker run -it -v ./out:/out -e R_SCRIPT="points_att_polygon.R" daugava-workflow-image -- "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip" "https://vm4072.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=json&limit=5871" "longitude" "latitude" "/out/tmp1.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="peri_conv.R" daugava-workflow-image -- "https://aquainfra.ogc.igb-berlin.de/download/out/data_merged_with_regions-57068ada-2a85-11f0-9159-fa163e42fba0.csv" "visit_date" "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30" "winter,spring,summer,autumn" "y/m/d" "true" "/out/tmp2.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="mean_by_group.R" daugava-workflow-image -- "https://aquainfra.ogc.igb-berlin.de/download/out/peri_conv-a45b847e-2a85-11f0-b44f-fa163e42fba0.csv" "longitude,latitude,Year_adj_generated,group_labels,HELCOM_ID" "transparen" "/out/tmp3.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="ts_selection_interpolation.R" daugava-workflow-image -- "https://aquainfra.ogc.igb-berlin.de/download/out/mean_by_group-52f1dd4f-2a86-11f0-9c65-fa163e42fba0.csv" "group_labels,HELCOM_ID" 80 "Year_adj_generated" "transparen" 10 "/out/tmp4.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="trend_analysis_mk.R" daugava-workflow-image -- "https://aquainfra.ogc.igb-berlin.de/download/out/interpolated_time_series-967ce25e-2a86-11f0-82fd-fa163e42fba0.csv" "group_labels,HELCOM_ID" "Year_adj_generated" "transparen" "/out/tmp5.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="barplot_trend_results.R" daugava-workflow-image -- "https://aquainfra.ogc.igb-berlin.de/download/out/trend_analysis_results-e3a22388-2a86-11f0-b08d-fa163e42fba0.csv" "HELCOM_ID" "Tau_Value" "P_Value" 0.05 "group_labels" "/out/tmp6.png"`

`docker run -it -v ./out:/out -e R_SCRIPT="map_shapefile_points.R" daugava-workflow-image -- "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip" "https://aquainfra.ogc.igb-berlin.de/download/out/data_merged_with_regions-57068ada-2a85-11f0-9159-fa163e42fba0.csv" "longitude" "latitude" "transparen" "HELCOM_ID" "/out/tmp7.html"`

## Create conda environment

`cd .binder`

`conda env create -f environment.yml`

`conda activate r-environment`
