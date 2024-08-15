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

For help and more details, please contact the AquaINFRA project.

