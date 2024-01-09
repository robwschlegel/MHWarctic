# code/00_functions.R
# The custom functions used for this particular project


# Setup -------------------------------------------------------------------

library(tidyverse)
library(ncdf4)
library(tidync)
library(ecmwfr) # For downloading ERA5 data
# devtools::install_github("metno/esd")
library(esd) # For downloading daily ERA5 data
library(doParallel); registerDoParallel(cores = 15)


# GLORYS ------------------------------------------------------------------

## See this website to download the files used here
# https://help.marine.copernicus.eu/en/articles/8638253-how-to-download-data-via-the-copernicus-marine-toolbox-in-r

## Run these lines in the Terminal pane in RStudio
# NB: Copy paste in Terminal requires 'ctrl+shift', rather than just 'ctrl'
# conda env create --file metadata/copernicus-marine-client-env.yml
# conda activate R_env
# where copernicus-marine
# OR
# type -a copernicus-marine
# Copy the output of the last command
# E.g. /home/robert/miniforge3/envs/R_env/bin/copernicus-marine
# and replace the value for 'cmt_dir' in the function below

# NB: This function requires some out-of-R code to be run first (see above)
# NB: The lon/lat bbox and other metadata are hard coded here for convenience, change as necessary
# dl_date <- dl_dates[86] # tester...
# dl_date <- dl_dates[343] # tester...
dl_GLORYS <- function(dl_date, dl_range = "month"){
  
  # Set working directories and username+password
  out_dir <- "~/pCloudDrive/FACE-IT_data/GLORYS" 
  cmt_dir <- "~/miniforge3/envs/R_env/bin/copernicus-marine"
  if(!exists("CM_UID_PWD")) load("metadata/CM_UID_PWD.RData")
  USERNAME <- CM_UID_PWD[1] # Copernicus Marine username
  PASSWORD <- CM_UID_PWD[2] # Copernicus Marine password
  
  # Product ID based on date requested
  if(dl_date <= as.Date("2021-06-30")){
    productId <- "cmems_mod_glo_phy_my_0.083deg_P1D-m"
  } else {
    productId <- "cmems_mod_glo_phy_myint_0.083deg_P1D-m"
  }
  
  # NB: Keep the space at the beginning
  variables <- c(" --variable thetao --variable so --variable uo --variable vo --variable zos --variable mlotst --variable bottomT --variable siconc --variable sithick --variable usi --variable vsi")
  
  # Time range
  date_min <- dl_date
  if(dl_range == "day"){
    date_max <- date_min
  } else if(dl_range == "month"){
    date_max <- date_min %m+% months(1) - 1
  } else if(dl_range == "year"){
    date_max <- date_min %m+% years(1) - 1
  }
  
  # Geographic area and depth level 
  lon <- list(8, 35)  # lon_min, lon_max
  lat <- list(76, 81) # lat_min, lat_max
  depth <- list(0.0, 5000.0) # depth_min, depth_max
  
  # Output filename
  if(dl_range == "day"){
    date_file <- as.character(dl_date)
  } else if(dl_range == "month"){
    date_file <- substr(dl_date, 1, 7)
  } else if(dl_range == "year"){
    date_file <- substr(dl_date, 1, 4)
  }
  out_name <- paste0("sval_GLORYS_",date_file,".nc")
  
  if(!file.exists(paste0(out_dir,"/",out_name))){
    # NB: If running in R console, replace (cmt_dir, "subset -i" with ("copernicus-marine subset -i"
    command <- paste(cmt_dir,"subset -i", productId,
                     "-x", lon[1], "-X", lon[2], "-y", lat[1], "-Y", lat[2],
                     "-t", date_min, "-T", date_max, "-z", depth[1], "-Z", depth[2],                    
                     variables, 
                     "--force-download", "-o", out_dir, "-f", out_name, 
                     "--username", USERNAME, "--password", PASSWORD, sep = " ")
    print(command)
    system(command, intern = TRUE)
  }
}

