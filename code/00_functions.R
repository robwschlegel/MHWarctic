# code/00_functions.R
# The custom functions used for this particular project


# Setup -------------------------------------------------------------------

library(tidyverse)
library(ncdf4)
library(tidync)
library(seacarb) # For thetatao conversion
library(doParallel); registerDoParallel(cores = 15)

# CDS (ERA5) related libraries that weren't used
# library(ecmwfr) # For downloading ERA5 data
# devtools::install_github("metno/esd")
# library(esd) # For downloading daily ERA5 data


# Metadata ----------------------------------------------------------------

# Isfjorden bounding box
bbox_is <- c(12.97, 17.50, 77.95, 78.90)
bbox_is_wide <- c(10.0, 18.0, 77.0, 79.0)

# GLORYS files location
# NB: It is muuuuuch faster to work on the files locally
# But they are generally very large so this isn't always possible
if(file.exists("data/GLORYS/sval_GLORYS_1993-01.nc")){
  GLORYS_files <- dir("data/GLORYS", pattern = "sval", full.names = TRUE)
} else {
  GLORYS_files <- dir("~/pCloudDrive/FACE-IT_data/GLORYS", pattern = "sval", full.names = TRUE)
}


# Utility -----------------------------------------------------------------

# Useful legacy code used to access variables directly within a NetCDF
# While this may be faster than tidync, it is much more cumbersome
# nc_file <- nc_open(file_name)
# nc_lon <- ncdf4::ncvar_get(nc_file, "longitude")
# nc_lat <- ncdf4::ncvar_get(nc_file, "latitude")
# lon_idx <- which(nc_file$dim$longitude$vals >= bbox[1] & nc_file$dim$longitude$vals <= bbox[2])
# lat_idx <- which(nc_file$dim$latitude$vals >= bbox[3] & nc_file$dim$latitude$vals <= bbox[4])
# Convenience function for subsetting from a NetCDF
ncvar_get_idx <- function(var_name, lon_idx, lat_idx, depth = TRUE){
  if(depth){
    start_idx <- c(lon_idx[1], lat_idx[1], 1, 1)
    count_idx <- c(length(lon_idx), length(lat_idx), -1, -1)
  } else {
    start_idx <- c(lon_idx[1], lat_idx[1], 1)
    count_idx <- c(length(lon_idx), length(lat_idx), -1)
  }
  nc_var <- ncvar_get(nc = nc_file, varid = var_name, 
                      start = start_idx, count = count_idx)
  return(nc_var)
}
# system.time(
#   nc_temp <- ncvar_get_idx("thetao", lon_idx, lat_idx)
# )
# system.time(
#   nc_vars <- plyr::ldply(c("thetao", "so", "uo"), ncvar_get_idx, .parallel = TRUE, lon_idx = lon_idx, lat_idx = lat_idx)
# )


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

# Load and extract data from a GLORYS file
# NB: The lon/lat bbox and other metadata are hard coded here for convenience, change as necessary
# testers...
# file_name <- GLORYS_files[20]
load_GLORYS <- function(file_name, wide = FALSE){
  
  # Ready, set, ...
  message(paste0("Began run on ",file_name," at ",Sys.time()))
  
  # Determine bbox
  if(wide){
    bbox <- bbox_is_wide
  } else {
    bbox <- bbox_is
  }
  # Depth vars: temp, U, V, SSS
  message(paste0("Began loading depth data at ",Sys.time()))
  res1 <- tidync(file_name) |> 
    hyper_filter(longitude = between(longitude, bbox[1], bbox[2]),
                 latitude = between(latitude, bbox[3], bbox[4])) |> 
    hyper_tibble() |> 
    dplyr::rename(temp = thetao, sal = so, u = uo, v = vo) |> 
    mutate(temp = round(temp, 4), sal = round(sal, 4),
           u = round(u, 6), v = round(v, 6),
           # Calculate current speed+direction
           cur_spd = round(sqrt(u^2 + v^2), 4),
           cur_dir = round((270-(atan2(v, u)*(180/pi)))%%360), 
           .before = "longitude") |> 
    pivot_longer(temp:cur_dir, names_to = "variable", values_to = "value")
  
  # Surface vars: MLD, bottomT, SSH, ice variables
  message(paste0("Began loading surface data at ",Sys.time()))
  res2 <- tidync(file_name) |> 
    activate("D2,D1,D3") |>
    hyper_filter(longitude = between(longitude, bbox_is_wide[1], bbox_is_wide[2]),
                 latitude = between(latitude, bbox_is_wide[3], bbox_is_wide[4])) |> 
    hyper_tibble() |>
    dplyr::rename(mld = mlotst, ssh = zos) |> 
    mutate(depth = 0) |> # Intentionally separate
    mutate(bottomT = round(bottomT, 4),
           siconc = round(siconc, 4), sithick = round(sithick, 4),
           mld = round(mld, 4), ssh = round(ssh, 4),
           usi = round(usi, 6), vsi = round(vsi, 6),
           # Replace NA sea ice values with 0
           siconc = ifelse(is.na(siconc), 0, siconc),
           sithick = ifelse(is.na(sithick), 0, sithick),
           usi = ifelse(is.na(usi), 0, usi),
           vsi = ifelse(is.na(vsi), 0, vsi),
           # Calculate sea ice speed+direction
           si_spd = round(sqrt(usi^2 + vsi^2), 4),
           si_dir = round((270-(atan2(vsi, usi)*(180/pi)))%%360),
           .before = "longitude") |> 
    pivot_longer(ssh:si_dir, names_to = "variable", values_to = "value")
  
  # Combine and process
  message(paste0("Began combining data at ",Sys.time()))
  res <- rbind(res1, res2) |> 
    dplyr::rename(lon = longitude, lat = latitude, t = time) |> 
    mutate(t = as.Date(as.POSIXct(t*3600, origin = '1950-01-01', tz = "GMT"))) |> 
    dplyr::select(lon, lat, t, depth, variable, value)
  rm(res1, res2); gc()
  return(res)
}


# ERA5 --------------------------------------------------------------------

# I found the CDS API (via R) so cumbersome to work with that I opted to use the web UI
# and manually download the data, one year at a time


# Both --------------------------------------------------------------------

# This function expects to be given only one pixel/ts at a time
# TODO: Add option to calculate based on 30, 20, and 10 year baselines
# Both forwards and backwards along the 30 yeaar period of data available
# testers...
# base_line <- c("1993-01-01", "2022-12-31")
calc_clim_anom <- function(df, base_line, point_accuracy){
  res <- ts2clm(df, y = val, roundClm = point_accuracy,
                climatologyPeriod = base_line)
  res$anom <- round(res$val-res$seas, point_accuracy)
  return(res)
}

