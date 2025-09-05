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

## Building Docker image

```
git clone https://github.com/AstraLabuce/aquainfra-usecase-Daugava.git

cd aquainfra-usecase-Daugava

docker build -t daugava-workflow-image .
```

## Running functions via Docker 

The following commands were implemented and tested on Ubuntu 22.04.5 LTS. Other operating systems might require adjustments regarding file paths. The commands can be executed one after the other.  

`docker run -it -v ./out:/out -e R_SCRIPT="points_att_polygon.R" daugava-workflow-image -- "https://zenodo.org/records/15234377/files/inputdata_shapefile.zip?download=1" "https://zenodo.org/records/15234377/files/inputdata_points.json?download=1" "longitude" "latitude" "/out/output1_pointsAttPolygon.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="peri_conv.R" daugava-workflow-image -- "/out/output1_pointsAttPolygon.csv" "visit_date" "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30" "winter,spring,summer,autumn" "y/m/d" "true" "/out/output2_periConv.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="mean_by_group.R" daugava-workflow-image -- "/out/output2_periConv.csv" "longitude,latitude,Year_adj_generated,group_labels,HELCOM_ID" "transparen" "/out/output3_meanByGropup.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="mean_by_group.R" daugava-workflow-image -- "/out/output3_meanByGropup.csv" "longitude,latitude,Year_adj_generated,group_labels,HELCOM_ID" "transparen" "/out/output4_meanByGropup.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="ts_selection_interpolation.R" daugava-workflow-image -- "/out/output4_meanByGropup.csv" "group_labels,HELCOM_ID" 80 "Year_adj_generated" "transparen" 10 "/out/output5_tsSelectionInterpolation.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="trend_analysis_mk.R" daugava-workflow-image -- "/out/output5_tsSelectionInterpolation.csv" "group_labels,HELCOM_ID" "Year_adj_generated" "transparen" "/out/output6_trendAnalysisMk.csv"`

`docker run -it -v ./out:/out -e R_SCRIPT="barplot_trend_results.R" daugava-workflow-image -- "/out/output6_trendAnalysisMk.csv" "HELCOM_ID" "Tau_Value" "P_Value" 0.05 "group_labels" "/out/output7_barplotTrendResults.png"`

`docker run -it -v ./out:/out -e R_SCRIPT="map_shapefile_points.R" daugava-workflow-image -- "https://zenodo.org/records/15234377/files/inputdata_shapefile.zip?download=1" "/out/output1_pointsAttPolygon.csv" "longitude" "latitude" "transparen" "HELCOM_ID" "/out/output8_mapShapefilePoints.html"`

## Running functions via cURL commands

The response of the commands include a jobID, which can be attached to the URL `https://aquainfra.ogc.igb-berlin.de/pygeoapi/jobs/", e.g., https://aquainfra.ogc.igb-berlin.de/pygeoapi/jobs/bde6c077-8a26-11f0-960c-fa163e42fba0`. Under `https://aquainfra.ogc.igb-berlin.de/pygeoapi/jobs/bde6c077-8a26-11f0-960c-fa163e42fba0/results?f=json` you can find the URL ot the resulting output under `href`. This URL can be used as input for the next function. 

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/points-att-polygon/execution' \
--header 'Content-Type: application/json' \
--header 'Prefer: respond-async' \
--data '{ 
    "inputs": {
        "regions": "https://zenodo.org/records/15234377/files/inputdata_shapefile.zip?download=1",
        "input_data": "https://zenodo.org/records/15234377/files/inputdata_points.json?download=1",
        "colname_long": "longitude",
        "colname_lat": "latitude"
    }
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/peri-conv/execution' \
--header 'Content-Type: application/json' \
--header 'Prefer: respond-async' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/data_merged_with_regions-9c71a3f5-8a36-11f0-84b2-fa163e42fba0.csv",
        "colname_date": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "period_labels": "winter,spring,summer,autumn",
        "year_starts_at_dec1": "True",
        "date_format": "y/m/d"
    } 
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/mean-by-group/execution' \
--header 'Prefer: respond-async' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/peri_conv-e44223d5-8a36-11f0-b067-fa163e42fba0.csv",
        "colnames_to_group_by": "longitude,latitude,Year_adj_generated,group_labels,HELCOM_ID",
        "colname_value": "transparen"
    } 
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/mean-by-group/execution' \
--header 'Prefer: respond-async' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/mean_by_group-01fb02d1-8a37-11f0-bc88-fa163e42fba0.csv",
        "colnames_to_group_by": "longitude,latitude,Year_adj_generated,group_labels,HELCOM_ID",
        "colname_value": "transparen"
    } 
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/ts-selection-interpolation/execution' \
--header 'Prefer: respond-async' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/mean_by_group-3d4aa80c-8a37-11f0-b32f-fa163e42fba0.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": 80.0,
        "colname_year": "Year_adj_generated",
        "colname_value": "transparen",
        "min_data_point": "10"
    } 
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/trend-analysis-mk/execution' \
--header 'Prefer: respond-async' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/interpolated_time_series-559099a4-8a37-11f0-a0ff-fa163e42fba0.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "colname_time": "Year_adj_generated",
        "colname_value": "transparen"
    } 
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/barplot-trend-results/execution' \
--header 'Prefer: respond-async' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/trend_analysis_results-68929f43-8a37-11f0-b329-fa163e42fba0.csv",
        "colname_id": "HELCOM_ID",
        "colname_test_value": "Tau_Value",
        "colname_p_value": "P_Value",
        "p_value_threshold": "0.05",
        "colname_group": "group_labels"
    } 
}'`

`curl --location 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/map-shapefile-points/execution' \
--header 'Prefer: respond-async' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://zenodo.org/records/15234377/files/inputdata_shapefile.zip?download=1",
        "colname_long": "longitude",
        "colname_lat": "latitude",
        "input_data": "https://aquainfra.ogc.igb-berlin.de/download/out/data_merged_with_regions-aa74c30a-8a2a-11f0-a3e3-fa163e42fba0.csv",
        "colname_value_name": "transparen",
        "colname_region_id": "HELCOM_ID"
    } 
}'`


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