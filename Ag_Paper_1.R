# Setup
library(readstata13)
library(tidyverse)
library(stargazer)
library(broom)
library(ggplot2)
library(mfx)
options(scipen=50)

# Load In Data
cpi <- read.csv("Data/CPI.csv")
fao_data <- read.csv("Data/FAOSTAT_data_2017.csv")
stocks_data <- read.csv("Data/FAOSTAT_stocks_data_2017.csv")
price_data <- read.dta13("Data/global_prices.dta")
quant_data <- read.dta13("Data/global_quantities.dta")
hemi_data <- read.dta13("Data/hemisphere.dta")

