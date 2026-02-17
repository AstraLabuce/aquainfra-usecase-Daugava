
# Example Docker Run Commands

<<<<<<< HEAD
Testing 2026-02-17 with image based on commit `5a309b550c2aed823faf5a8a9bc3aba8e57e263f`.
=======
Testing 2026-02-17 with new image based on commit `ce88a01b6a91391342ec7bd2724645f4bc172a4b`.
>>>>>>> 332fbf1 (Added README with docker run commands, tested 2026-02-17.)


## 1. points-att-polygon

Tested 2026-02-17

```
docker run -it -v ./out:/out -e SCRIPT="points_att_polygon.R" daugava-workflow-image:20260217-dev \
    "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.zip" \
    "https://raw.githubusercontent.com/AstraLabuce/aquainfra-usecase-Daugava/81f349dd549527df83bfd4eec589dc35b0c062d6/in_situ_data/in_situ_example.csv" \
    "longitude" "latitude" \
    "/out/output1_pointsAttPolygon.csv";
```


## 2. peri_conv

* Tested 2026-02-17
* Note: Date format needs `%` before letters, and `Y` has to be capital, in comparison to pygeoapi inputs
* Note: Boolean has to be string `"true"` or `"false"`

```
docker run -it -v ./out:/out -e SCRIPT="peri_conv.R" daugava-workflow-image:20260217-dev \
    "/out/output1_pointsAttPolygon.csv" \
    "visit_date" \
    "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30" \
    "winter,spring,summer,autumn" \
    "%Y/%m/%d" \
    "true" \
    "/out/output2_periConv.csv";
```

## 3. mean_by_group

* Tested 2026-02-17
* Note: No spaces in list!

```
docker run -it -v ./out:/out -e SCRIPT="mean_by_group.R" daugava-workflow-image:20260217-dev \
    "/out/output2_periConv.csv" \
    "longitude,latitude,Year_adj_generated,group_labels,HELCOM_ID" \
    "transparen" \
    "/out/output3_mean_by_group.csv";
```

## 4. ts-selection-interpolation

* Tested 2026-02-17
* Note: Numbers have to be strings, e.g. `"60"`

```
docker run -it -v ./out:/out -e SCRIPT="ts_selection_interpolation.R" daugava-workflow-image:20260217-dev \
    "/out/output3_mean_by_group.csv" \
    "group_labels,HELCOM_ID" \
    "60" \
    "Year_adj_generated" \
    "transparen" \
    "5" \
    "/out/output4_ts_selection_interpolation.csv";
```


## 5. trend_analysis

* Tested 2026-02-17

```
docker run -it -v ./out:/out -e SCRIPT="trend_analysis_mk.R" daugava-workflow-image:20260217-dev \
    "/out/output4_ts_selection_interpolation.csv" \
    "group_labels,HELCOM_ID" \
    "Year_adj_generated" \
    "transparen" \
    "/out/output5_trend_analysis.csv";
```


## 6. map_shapefile_points

* Tested 2026-02-17
* Input is output of process 1!

```
docker run -it -v ./out:/out -e SCRIPT="map_shapefile_points.R" daugava-workflow-image:20260217-dev \
    "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.zip" \
    "/out/output1_pointsAttPolygon.csv" \
    "longitude" \
    "latitude" \
    "transparen" \
    "HELCOM_ID" \
    "/out/output6_map_shapefile_points.html";
```


## 7. barplot_trend_results

* Tested 2026-02-17
* Note: Numbers have to be strings, e.g. `"0.05"`

```
docker run -it -v ./out:/out -e SCRIPT="barplot_trend_results.R" daugava-workflow-image:20260217-dev \
    "/out/output5_trend_analysis.csv" \
    "HELCOM_ID" \
    "Tau_Value" \
    "P_Value" \
    "0.05" \
    "period" \
    "/out/output7_barplot_trend_results.png";
```


## 8. map_trends_interactive

```
not implemented
```


## 9. map_trends_static

* Note: Numbers have to be strings, e.g. `"0.05"`

```
docker run -it -v ./out:/out -e SCRIPT="map_trends_static.R" daugava-workflow-image:20260217-dev \
    "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.zip" \
    "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/trend-analysis-mk/out/trend_analysis_results-1a7b73d8-0848-11f1-b387-fa163e42fba0.csv" \
    "HELCOM_ID" \
    "HELCOM_ID" \
    "period" \
    "P_Value" \
    "0.05" \
    "/out/output9_map_trends_static_test.png";


docker run -it -v ./out:/out -e SCRIPT="map_trends_static.R" daugava-workflow-image:20260217-dev \
    "https://aquainfra.ogc.igb-berlin.de/exampledata/daugava/points-att-polygon/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.zip" \
    "/out/output5_trend_analysis.csv" \
    "HELCOM_ID" \
    "HELCOM_ID" \
    "period" \
    "P_Value" \
    "0.05" \
    "/out/output9_map_trends_static_test.png";
```

Fails: `Error in library(rosm) : there is no package called ‘rosm’`

