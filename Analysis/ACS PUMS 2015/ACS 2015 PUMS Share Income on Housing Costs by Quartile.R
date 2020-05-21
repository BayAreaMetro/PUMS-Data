# ACS 2015 PUMS Share Income on Housing Costs by Quartile.R
# Analyze PUMS data for share income spent on housing by income quartile
# 2015 1-year PUMS data

# Import Libraries

suppressMessages(library(tidyverse))

# Input HH PUMS file and set working directory

HH_RDATA = "M:/Data/Census/PUMS/PUMS 2015/hbayarea15.Rdata"
WD = "C:/Users/sisrael/Documents/GitHub/regional_forecast/housing_income_share_metric"
setwd(WD)

# Set CPI values for 2000 and 2015 to inflate household income values, set up 2015-inflated breakpoints

CPI2000      <- 180.20
CPI2015      <- 258.57
CPI_ratio    <- CPI2015/CPI2000 # 2015 CPI/2000 CPI
break1       <- CPI_ratio*30000                   # First income break point for 2000$
break2       <- CPI_ratio*60000                   # Second income break point for 2000$
break3       <- CPI_ratio*100000                  # Third income break point for 2000$

# Bring in HH data

load (HH_RDATA) 

# Recode data

household <- hbayarea15 %>% mutate(
  adjustedinc=HINCP*(ADJINC/1000000),                 # Adjusted income to constant 2015$ 
  tenure=case_when(
    TEN==1     ~ "Owner",                             # Owned with a mortgage
    TEN==2     ~ "Owner",                             # Owned free and clear
    TEN==3     ~ "Renter",                            # Rented
    TEN==4     ~ "Renter"                             # Occupied without payment of rent
  ),
  quartile=case_when(
    adjustedinc <  break1                         ~ "Quartile1",  # Income below 30k in 2000$
    adjustedinc >= break1 & adjustedinc < break2  ~ "Quartile2",  # Income 30-60k in 2000$
    adjustedinc >= break1 & adjustedinc < break3  ~ "Quartile3",  # Income 60-100k in 2000$
    adjustedinc >  break3                         ~ "Quartile4"   # Income above 100k in 2000$
  ),
  own_cost  =if_else(is.na(SMOCP),0L,SMOCP),                      # Owner costs if SMOCP is not NA
  rent_cost =if_else(is.na(GRNTP),0L,GRNTP),                      # Renter costs if GRNTP is not NA
  total_cost=own_cost + rent_cost                                 # Sum of renter and owner costs
  ) %>% 
  filter(!is.na(TEN)) %>%                                         # Keep cases that are not GQ/vacant 
  select(SERIALNO,PUMA,PUMA_Name,County_Name,HINCP,ADJINC, TEN,adjustedinc,
         tenure,WGTP,own_cost,rent_cost,total_cost,quartile)      # Select out relevant variables

# Summarize by quartile and tenure, then for just quartile, concatenate and sort for a final dataset
# Divide income sums by 12 to get monthly income from annual

tenure_sum <- household %>% 
  group_by(quartile,tenure) %>% 
  summarize(aggregate_income=sum(WGTP*adjustedinc/12),aggregate_rent=sum(WGTP*rent_cost),aggregate_owncosts=sum(WGTP*own_cost),aggregate_costs=sum(WGTP*total_cost)) %>% 
  mutate(
    share_income=case_when(
    aggregate_rent>0   ~aggregate_rent/(aggregate_income),           # Share income for renters
    aggregate_owncosts >0   ~aggregate_owncosts/(aggregate_income),            # Share income for owners
  ))

tenure_sum <- household %>% 
  group_by(quartile,tenure) %>% 
  summarize(aggregate_income=sum(WGTP*adjustedinc/12),aggregate_rent=sum(WGTP*rent_cost),aggregate_owncosts=sum(WGTP*own_cost),aggregate_costs=sum(WGTP*total_cost)) %>% 
  mutate(
    share_income=case_when(
      aggregate_rent>0   ~aggregate_rent/(aggregate_income),           # Share income for renters
      aggregate_owncosts >0   ~aggregate_owncosts/(aggregate_income),            # Share income for owners
    ))

total_sum <- household %>% 
  group_by(quartile) %>% 
  summarize(tenure="Total",aggregate_income=sum(WGTP*adjustedinc/12),aggregate_rent=sum(WGTP*rent_cost),aggregate_owncosts=sum(WGTP*own_cost),
            aggregate_costs=sum(WGTP*total_cost)) %>% 
  mutate(
    share_income=aggregate_costs/(aggregate_income)       # Share income for sum of renters and owners
  )

final <- rbind(tenure_sum,total_sum) %>%          # Concatenate and sort
  arrange(quartile,tenure)

# Export

write.csv(final,file="ACS PUMS 2015 Share Income Spent on Housing by Quartile.csv",row.names = FALSE,quote=TRUE)