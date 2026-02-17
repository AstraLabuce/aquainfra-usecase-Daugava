
packages <- c(
  "tmap",
  "rosm",
  "mapview",
  "dplyr",
  "ggplot2",
  "tidyr",
  "readxl",
  "data.table",
  "lubridate",
  "jsonlite",
  "magrittr",
  "janitor",
  "zoo",
  "Kendall",
  "viridis",
  "webshot"
)

# Install only if not already installed
installed <- rownames(installed.packages())
to_install <- setdiff(packages, installed)

if(length(to_install) > 0){
  install.packages(to_install, repos="https://cloud.r-project.org")
}

