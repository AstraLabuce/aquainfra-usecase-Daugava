if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes", repos = "https://cran.rstudio.com/")
}

required_packages_versions <- list(
  "curl" = "5.2.1",
  "zoo" = "1.8-12",
  "readxl" = "1.4.3",
  "tidyr" = "1.3.0",
  "Kendall" = "2.2.1",
  "ggplot2" = "3.5.1",
  "jsonlite" = "1.8.7",
  "dplyr" = "1.1.2",
  "lubridate" = "1.9.3",
  "sf" = "1.0-14",
  "magrittr" = "2.0.3",
  "janitor" = "2.2.0",
  "sp" = "2.0-0",
  "data.table" = "1.14.8",
  "viridis" = "0.6.4"
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
