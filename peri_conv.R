##############################################################################################.
## 2. peri_conv : period converter ####
# function peri_conv - adds December to the next year (all winter months together)
                            # in the result every year starts at Dec-01. and ends Nov-30;
                            # generates num variable 'Year_adjusted' to show change;
                            # generates chr variable 'season' to allow grouping the data based on season.

library(lubridate)
library(dplyr)

peri_conv <- function(data,
           date_col_name,
           group_to_periods = #default season division; # do not put Feb-29th, if needed then choose Mar-01
             c("Dec-01:Mar-01", "Mar-02:May-30", "Jun-01:Aug-30", "Sep-01:Nov-30"),
           group_labels = #default = group_to_periods
             group_to_periods, #if defined, should be the same length as group_to_periods
           year_starts_at_Dec1 = TRUE #default
           ) {
    #data - dataset with columns for Year and Month (all the rest variables stays the same)
    #Date - column name to Date in format YYYY-MM-DD; Year, Month, Day, Year_adj - will be generated
    #group_to_periods <- group into periods: define the periods, e.g., mmm-DD:mmm-DD, Mar-15:Jun-01.
    if (!requireNamespace("lubridate", quietly = TRUE)) {
      stop("Package \"lubridate\" must be installed to use this function.",
           call. = FALSE)
    }

    if (!is.logical(year_starts_at_Dec1)) {
      stop(paste0('The parameter "year_starts_at_Dec1" is not a boolean value, but a ',
        typeof(year_starts_at_Dec1), ' value (', year_starts_at_Dec1, ')!'))
    }
  
    if (missing(data))
      stop("missing data")
    suppressWarnings(if (!unique(!is.na(as.Date(
      get(date_col_name, data), "%Y-%m-%d"
    ))))
      stop("Error: Date is not in format YYYY-MM-DD"))
    
    print(paste0('Generating required date format'))
    
    data$Day_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%d"))
    data$Month_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%m"))
    data$Year_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%Y"))
    data$Year_adj_generated <-
      as.numeric(format(as.Date(get(date_col_name, data), format = "%Y-%m-%d"), "%Y"))
    
    if(year_starts_at_Dec1 == TRUE ){
    data[data$Month_generated == 12,]$Year_adj_generated <-
      data[data$Month_generated == 12,]$Year_generated + 1}
    
    print(paste0('Generating defined period labels'))
    
    data$period_label <- "NA" #making period_label column as 'character'
    data$dayoy <-
      as.numeric(format(as.Date(data$visit_date, format = "%Y-%m-%d"), "%j"))
    data$leap_year <- lubridate::leap_year(data$visit_date)
    
    period <-
      expand.grid(periods = group_to_periods,
                  Year_generated = unique(data$Year_adj_generated))
    
    period$group_date_from <- NA
    period$group_date_to <- NA
    period$group_month_from <- NA
    period$group_month_to <- NA
    period$group_day_from <- NA
    period$group_day_to <- NA
    
    for (row in 1:length(period$periods)) {
      period[row, ]$group_date_from <-
        strsplit(as.character(period[row, ]$periods), "[:]")[[1]][1]
      period[row, ]$group_date_to <-
        strsplit(as.character(period[row, ]$periods), "[:]")[[1]][2]
      
      period[row, ]$group_month_from <-
        strsplit(as.character(period[row, ]$group_date_from), "[-]")[[1]][1]
      period[row, ]$group_day_from <-
        strsplit(as.character(period[row, ]$group_date_from), "[-]")[[1]][2]
      
      period[row, ]$group_month_to <-
        strsplit(as.character(period[row, ]$group_date_to), "[-]")[[1]][1]
      period[row, ]$group_day_to <-
        strsplit(as.character(period[row, ]$group_date_to), "[-]")[[1]][2]
    }
    period$group_month_from <-
      match(period$group_month_from, month.abb)
    period$group_month_to <- match(period$group_month_to, month.abb)
    
    period$group_date_from_fin <-
      paste0(period$Year_generated,
             "-",
             period$group_month_from,
             "-",
             period$group_day_from)
    period$group_date_to_fin <-
      paste0(period$Year_generated,
             "-",
             period$group_month_to,
             "-",
             period$group_day_to)
    
    period$group_date_from_dayoy <-
      as.numeric(format(as.Date(period$group_date_from_fin, format = "%Y-%m-%d"), "%j"))
    period$leap_year <-
      lubridate::leap_year(period$group_date_from_fin)
    
    period$group_date_to_dayoy <-
      as.numeric(format(as.Date(period$group_date_to_fin, format = "%Y-%m-%d"), "%j"))
    
    period_fin <-
      unique(period[c(
        "periods",
        "group_date_from",
        "group_date_to",
        "group_month_from",
        "group_month_to",
        "group_day_from",
        "group_day_to",
        "group_date_from_dayoy",
        "group_date_to_dayoy",
        "leap_year"
      )])
    
    print(paste0('Considering leap years'))
    
    period_leap <- subset(period_fin, leap_year == TRUE)
    period_leap[period_leap$group_month_from == 12,]$group_date_from_dayoy <-
      period_leap[period_leap$group_month_from == 12,]$group_date_from_dayoy - 366
    
    data_leap <- subset(data, leap_year == TRUE)
    data_leap[data_leap$Month_generated == 12,]$dayoy <-
      data_leap[data_leap$Month_generated == 12,]$dayoy - 366
    
    for (each in seq(data_leap$dayoy)) {
      for (row in 1:length(period_leap$periods)) {
        if (data_leap[each,]$dayoy >= period_leap[row, ]$group_date_from_dayoy &
            data_leap[each,]$dayoy <= period_leap[row, ]$group_date_to_dayoy) {
          data_leap[each,]$period_label <-
            as.character(period_leap[row, ]$periods)
        }
      }
    }
    
    print(paste0('Finalizing results'))
    
    period_regular <- subset(period_fin, leap_year == FALSE)
    period_regular[period_regular$group_month_from == 12,]$group_date_from_dayoy <-
      period_regular[period_regular$group_month_from == 12,]$group_date_from_dayoy - 365
    
    data_regular <- subset(data, leap_year == FALSE)
    data_regular[data_regular$Month_generated == 12,]$dayoy <-
      data_regular[data_regular$Month_generated == 12,]$dayoy - 365
    
    for (each in seq(data_regular$dayoy)) {
      for (row in 1:length(period_regular$periods)) {
        if (data_regular[each,]$dayoy >= period_regular[row, ]$group_date_from_dayoy &
            data_regular[each,]$dayoy <= period_regular[row, ]$group_date_to_dayoy) {
          data_regular[each,]$period_label <-
            as.character(period_regular[row, ]$periods)
        }
      }
    }
    res <- rbind(data_leap, data_regular)
    labels <-
      data.frame(period_label = group_to_periods, group_labels)
    res <- dplyr::full_join(res, labels, by = "period_label")
    
    rm(
      data,
      period,
      period_fin,
      period_leap,
      period_regular,
      data_leap,
      data_regular,
      labels
    )
    return(res[, -"dayoy"])
  }

