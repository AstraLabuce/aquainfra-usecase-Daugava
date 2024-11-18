if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes", repos = "https://cran.rstudio.com/")
}

required_packages_versions <- list(
  "sf" = "1.0-14",
  "magrittr" = "2.0.3",
  "dplyr" = "1.1.2",
  "janitor" = "2.2.0",
  "sp" = "2.0-0",
  "data.table" = "1.14.8",
  "readxl" = "1.4.3",
  "jsonlite" = "1.8.7",
  "lubridate" = "1.9.3",
  "curl" = "5.2.1",
  "zoo" = "1.8-12",
  "tidyr" = "1.3.0",
  "Kendall" = "2.2.1",
  "ggplot2" = "3.5.1",
  "viridis" = "0.6.4",
  "mapview" = "2.11.2",
  "webshot" = "0.5.5",
  "tmap" = "3.3-3",
  "tmaptools" = "3.3-1",
  "rosm" = "0.3.0"
)

install_if_missing <- function(pkg, version) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    remotes::install_version(pkg, version = version, repos = "https://cran.rstudio.com/")
  }
}

invisible(lapply(names(required_packages_versions), function(pkg) {
  install_if_missing(pkg, required_packages_versions[[pkg]])
}))

sessionInfo()
