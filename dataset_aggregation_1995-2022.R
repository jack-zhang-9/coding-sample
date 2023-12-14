library(haven)
library(readxl)
library(writexl)
library(dplyr)

setwd("D:/张知遥/武汉大学/刘淼RA/Are Chinese Growth and Inflation Too Smooth Evidence from Engel Curves/Replication_1995-2022/data")

###################### 1.import raw data #################

est_1995_2011 <- read_dta("Estimation Region 1995-2011.dta") %>%
  filter(commodity=="food") 
  
expfood_2012_2022 <- read_xlsx("ExpenditureFood 2012-2022.xlsx",
                               col_names = c("year","region","scope","total_exp","food_exp"),skip = 1) %>%
  mutate(year = as.numeric(year),
         region = as.numeric(region)) %>%
  select(-scope) %>%
  arrange(year,region)

CPIfood_2012_2022 <- read_xlsx("PriceIndexFood 2012-2022.xlsx",
                               skip = 1,
                               col_names = c("year","region","CPIoverall","CPIfood")) %>%
  mutate(year = as.numeric(year),
         region = as.numeric(region))

#################### 2.combine data #############################

 # extract expenditure&CPI from 1995-2011
est_food_1995_2011 <- est_1995_2011 %>%
  filter(year >= 1995) %>%
  select(year,region,CPIFood,expenditureFood,CPIOverall,TotalExpenditures)
 
 # note that the statistics of Chongqing province start with 1997

 # convert the region name (character) in 1995-2011 into region code
region_nm_transition <- read_xlsx("RegionNameTransition.xlsx",col_names = TRUE)
est_food_1995_2011 <- est_food_1995_2011 %>%
  rename(region_nm = region) %>%
  left_join(region_nm_transition, by = "region_nm") %>%
  select(-region_nm) %>%
  rename(food_exp = expenditureFood,
         total_exp = TotalExpenditures,
         CPIoverall = CPIOverall,
         CPIfood = CPIFood)

 # combine with 2012-2021
est_food_2012_2022 <- expfood_2012_2022 %>%
  left_join(CPIfood_2012_2022,by = c("year","region")) %>%
  filter(year >= 2012) %>%
  filter(region != 156 & region != 540000)
 #Xizang province（540000） is not included in 1995-2011 sample, 
 #but is in 2012-2022 sample
 #We drop the observation of Xizang here

est_food <- rbind(est_food_1995_2011,est_food_2012_2022) %>%
  arrange(region,year)

########## 4.calculate chained inflation and relative price ###############

 # Compute Chained Inflation (The algorithm ensures whenever there is discontinuity in
 # the price data, the chained inflation is computed from the beginning. That is, the discontinuity
 # in price is treated as missing value instead of zero)
chained_inflation <- function(CPI){
  chain_infl <- vector(length = length(CPI))
  CPI = CPI/100
  for(i in 1:length(CPI)){
    if(!is.na(CPI[i])) {
      if (i==1){
        chain_infl[i]=1
      } else if (is.na(CPI[i-1])) {
        chain_infl[i]=1
      } else {
        chain_infl[i] <- chain_infl[i-1]*CPI[i]
      }
    } else {
      chain_infl[i] = NA
    }
  }
  chain_infl
}

 # generate key variables in regressions
est_food <- est_food %>%
  group_by(region) %>%
  arrange(year,.by_group = TRUE) %>%
  mutate(chain_infl_overall = chained_inflation(CPIoverall),
         chain_infl_food = chained_inflation(CPIfood),
         food_exp_share = food_exp/total_exp,
         price_CPI_food = log(chain_infl_food)-log(chain_infl_overall),
         real_total_exp = log(total_exp)-log(chain_infl_overall)
  )

############### 5.merge other control variables ############################

household <- read_xlsx("household.xlsx",col_names = T)%>%
  mutate(year = as.numeric(year),
         region = as.numeric(region))
unemployment <- read_xlsx("unemployment.xlsx",col_names = T)%>%
  mutate(year = as.numeric(year),
         region = as.numeric(region))
dependecyrate <- read_xlsx("dependencyrate.xlsx",col_names = T)%>%
  mutate(year = as.numeric(year),
         region = as.numeric(region))

control <- household %>%
  filter(year >= 1995) %>%
  filter(region != 156 & region != 540000) %>%
  left_join(unemployment) %>%
  left_join(dependecyrate)

est_food <- est_food %>%
  left_join(control) %>%
  select(year,region,region_nm,everything())

write_dta(est_food,"Estimation Food.dta")

################# 6. data check #################################

library(ggplot2)

ggplot(est_food)+
  geom_boxplot(aes(x=as.factor(year),y=price_CPI_food))

ggplot(est_food)+
  geom_boxplot(aes(x=as.factor(year),y=food_exp_share))

ggplot(est_food)+
  geom_boxplot(aes(x=as.factor(year),y=real_total_exp))
