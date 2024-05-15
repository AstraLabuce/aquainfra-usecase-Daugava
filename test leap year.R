library(lubridate)

testdaya$MONTH<-month(testdaya$visit_date,label=TRUE)
testdaya$DAY<-as.character(day(testdaya$visit_date))

input_for_spring_min_month<-"Mar"
input_for_spring_max_month<-"May"
input_for_spring_min_date<-"10"
input_for_spring_max_date<-"15"
season_name_spring<-"Spring"
testdaya_spring<-subset(testdaya, MONTH >= input_for_spring_min_month 
                  & MONTH <= input_for_spring_max_month
                  & DAY>=input_for_spring_min_date
                  & DAY<=input_for_spring_max_date )
testdaya_spring$Season<-rep(season_name_spring,rep(nrow(testdaya_spring)))
input_for_summer_min_month<-"Jun"
input_for_summer_max_month<-"Aug"
input_for_summer_min_date<-"10"
input_for_summer_max_date<-"15"
season_name_summer<-"Summer"
testdaya_summer<-subset(testdaya, MONTH >= input_for_summer_min_month 
                        & MONTH <= input_for_summer_max_month
                        & DAY>=input_for_summer_min_date
                        & DAY<=input_for_summer_max_date )
testdaya_summer$Season<-rep(season_name_summer,rep(nrow(testdaya_summer)))
new_data<-rbind(testdaya_spring,testdaya_summer)

