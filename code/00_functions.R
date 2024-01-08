# code/00_functions.R
# The custom functions used for this particular project


# Setup -------------------------------------------------------------------

library(tidyverse)
library(ncdf4)
library(tidync)
library(ecmwfr) # For downloading ERA5 data
# devtools::install_github("markpayneatwork/RCMEMS")
library(RCMEMS)


# GLORYS ------------------------------------------------------------------

# NB: This function is currently designed to subset data to the MHWflux projects domain
# date_choice <- date_range$year_mon[311]
download_GLORYS <- function(date_choice){
  
  # The GLORYS script
  GLORYS_script <- 'python ~/motuclient-python/motuclient.py --motu http://my.cmems-du.eu/motu-web/Motu --service-id GLOBAL_REANALYSIS_PHY_001_030-TDS --product-id cmems_mod_glo_phy_my_0.083deg_P1D-m --longitude-min -180 --longitude-max 179.9166717529297 --latitude-min -80 --latitude-max 90 --date-min "2018-12-25 12:00:00" --date-max "2018-12-25 12:00:00" --depth-min 0.493 --depth-max 0.4942 --variable thetao --variable bottomT --variable so --variable zos --variable uo --variable vo --variable mlotst --variable siconc --variable sithick --variable usi --variable vsi --out-dir . --out-name test.nc --user uid --pwd pswd'
  
  # Prep the necessary URL pieces
  date_start <- parse_date(date_choice, format = "%Y-%m")
  date_end <- date_start %m+% months(1) - 1
  
  # if(date_end == as.Date("2018-12-31")) date_end <- as.Date("2018-12-25")
  
  file_name <- paste0("sval_GLORYS_",date_choice,".nc")
  
  cfg <- parse.CMEMS.script(GLORYS_script, parse.user = T)
  cfg_update <- RCMEMS::update(cfg, variable = "thetao --variable bottomT --variable so --variable zos --variable uo --variable vo --variable mlotst --variable siconc --variable sithick --variable usi --variable vsi",
                               longitude.min = "9",
                               longitude.max = "35",
                               latitude.min = "76",
                               latitude.max = "81",
                               date.min = as.character(date_start),
                               date.max = as.character(date_end),
                               out.name = file_name)
  
  # Download and save the file if needed
  if(file.exists(paste0("~/pCloudDrive/FACE-IT_data/GLORYS/",file_name))){
    return()
  } else{
    CMEMS.download(cfg_update)
  }
  Sys.sleep(2) # Give the server a quick breather
}

