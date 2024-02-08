# code/00_functions.R
# The custom functions used for this particular project


# Setup -------------------------------------------------------------------

library(tidyverse)
library(data.table)
library(FNN)
library(geosphere)
library(ncdf4)
library(tidync)
library(heatwaveR)
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

# ERA5 file locations
ERA5_Rda_files <- dir("~/pCloudDrive/FACE-IT_data/ERA5/is", pattern = "is*", full.names = TRUE)
ERA5_ncdf_files <- dir("~/pCloudDrive/FACE-IT_data/ERA5/is", "nc", full.names = TRUE)

# GLORYS grid
# grid_GLORYS <- load_GLORYS(GLORYS_files[1]) |> dplyr::select(lon, lat) |> distinct()
# write_csv(grid_GLORYS, "metadata/grid_GLORYS.csv")
grid_GLORYS <- read_csv("metadata/grid_GLORYS.csv")

# ERA grid
# grid_ERA5 <- load_ERA5(ERA5_ncdf_files[1], lon_range = c(12.75, 17.50), lat_range = c(78, 79)) |> 
#   dplyr::select(lon, lat) |> distinct()
# write_csv(grid_ERA5, "metadata/grid_ERA5.csv")
grid_ERA5 <- read_csv("metadata/grid_ERA5.csv")
grid_ERA5_centre <- data.frame(lon = grid_ERA5$lon+0.125, lat = grid_ERA5$lat-0.125)


# Utility -----------------------------------------------------------------

# Convenience function for subsetting from a NetCDF
# While this may be faster than tidync, it is much more cumbersome
# NB: This isn't set to work with depth data at the moment (i.e. GLORYS)
ncvar_get_idx <- function(var_name, nc_file, lon_range, lat_range, depth = FALSE){
  
  # Find the necessary time shift
  if(var_name %in% c("mslhf", "msshf", "msnlwrf", "msnswrf")){
    time_shift = 43200
  } else{
    time_shift = 0
  }
  
  # Extract data from NetCDF
  nc_lon <- ncvar_get(nc_file, "longitude")
  nc_lat <- ncvar_get(nc_file, "latitude")
  nc_time <- ncvar_get(nc_file, "time")
  lon_idx <- which(nc_lon %between% lon_range)
  lat_idx <- which(nc_lat %between% lat_range)
  nc_lon_sub <- nc_lon[lon_idx]
  nc_lat_sub <- nc_lat[lat_idx]
  
  # Get subset indices
  if(depth){
    start_idx <- c(lon_idx[1], lat_idx[1], 1, 1)
    count_idx <- c(length(lon_idx), length(lat_idx), -1, -1)
  } else {
    start_idx <- c(lon_idx[1], lat_idx[1], 1)
    count_idx <- c(length(lon_idx), length(lat_idx), -1)
  }
  nc_array <- ncvar_get(nc = nc_file, varid = var_name,
                        start = start_idx, count = count_idx)
  
  # Convert to data.frame and exit
  res_df <- t(as.data.frame(nc_array)) |> 
    as.data.frame() |> 
    `colnames<-`(nc_lon_sub) |> 
    mutate(lat = rep(nc_lat_sub, length(nc_time)),
           t = rep(nc_time, length(nc_lat_sub))) |> 
    pivot_longer(cols = c(-lat, -t), names_to = "lon", values_to = "value") |> 
    mutate(across(everything(), as.numeric)) |> 
    # mutate(lon = if_else(lon > 180, lon-360, lon)) |>  # Shift to +- 180 scale
    # na.omit() |>  
    mutate(t = as.POSIXct(t * 3600, origin = '1900-01-01', tz = "GMT")) |> 
    mutate(t = t+time_shift) |> # Time shift for heat flux integrals
    mutate(t = as.Date(t)) |> 
    mutate(variable = var_name) |> 
    dplyr::select(lon, lat, t, variable, value)
  return(res_df)
}

# Find the nearest grid cells for each site
## NB: Requires two data.frames with lon, lat in that order
grid_match <- function(coords_base, coords_match){
  if(!"lon" %in% colnames(coords_base)) stop("Need lon/lat columns in coords_base")
  if(!"lon" %in% colnames(coords_match)) stop("Need lon/lat columns in coords_match")
  coords_match$idx <- 1:nrow(coords_match)
  grid_index <- data.frame(coords_base,
                           idx = knnx.index(data = as.matrix(coords_match[,1:2]),
                                            query = as.matrix(coords_base[,1:2]), k = 1))
  grid_points <- left_join(grid_index, coords_match, by = c("idx")) %>% 
    mutate(dist = round(distHaversine(cbind(lon.x, lat.x),
                                      cbind(lon.y, lat.y))/1000, 2), idx = NULL)
  return(grid_points)
}
#

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
dl_GLORYS <- function(dl_date, dl_range = "month", force_dl = FALSE){
  
  # Set working directories and username+password
  out_dir <- "~/pCloudDrive/FACE-IT_data/GLORYS"
  # out_dir <- "data/GLORYS"
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
  
  if(force_dl) file.remove(paste0(out_dir,"/",out_name))
  
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
# TODO: This could have the clim+anon calculations baked directly in
# This would save a step in the workflow, and reduce redundant file sizes
# NB: The lon/lat bbox and other metadata are hard coded here for convenience, change as necessary
# testers...
# file_name <- GLORYS_files[228]
load_GLORYS <- function(file_name, wide = FALSE){
  
  # Ready, set, ...
  # message(paste0("Began run on ",file_name," at ",Sys.time()))
  
  # Determine bbox
  if(wide){
    bbox <- bbox_is_wide
  } else {
    bbox <- bbox_is
  }
  # Depth vars: temp, U, V, SSS
  # message(paste0("Began loading depth data at ",Sys.time()))
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
  # message(paste0("Began loading surface data at ",Sys.time()))
  res2 <- tidync(file_name) |> 
    activate("D2,D1,D3") |>
    hyper_filter(longitude = between(longitude, bbox[1], bbox[2]),
                 latitude = between(latitude, bbox[3], bbox[4])) |> 
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
  # message(paste0("Began combining data at ",Sys.time()))
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

# Convenience function for loading and pivoting ERA5 Rds files
pivot_rds <- function(file_name){
  res <- read_rds(file_name) |> 
    pivot_longer(-c(lon, lat, t), names_to = "variable")
}

# Function for loading a single ERA 5 NetCDF file
# The ERA5 data are saved as annual files with all variables
# testers...
# file_name <- "~/pCloudDrive/FACE-IT_data/ERA5/is/web_UI_2022.nc"
# lon_range = c(12.75, 17.50); lat_range = c(78, 79)
load_ERA5 <- function(file_name, lon_range, lat_range){
  
  # Extract data from NetCDF
  nc_file <- nc_open(file_name)
  
  # Get subset of data for all variables
  # NB: There has to be a better way to do this
  # But I don't quite understand why this occasionally throws errors
  # And it doesn't seem possible to reliably test the error case
  # It may have been multicoring it...
  # error_NA <- NULL
  # while(is.null(error_NA)){
  #   error_NA <- "All good"
  #   res_df <- tryCatch(plyr::ldply(names(nc_file$var), ncvar_get_idx, .parallel = FALSE,
  #                                  nc_file = nc_file, lon_range = lon_range, lat_range = lat_range),
  #                      error = function(nc_file) {error_NA <<- NULL})
  # }
  res_df <- plyr::ldply(names(nc_file$var), ncvar_get_idx, .parallel = FALSE,
                        nc_file = nc_file, lon_range = lon_range, lat_range = lat_range)
  nc_close(nc_file)
  
  # Switch to data.table for faster means
  res_dt <- data.table(res_df)
  setkey(res_dt, lon, lat, t, variable)
  res_mean <- res_dt[, lapply(.SD, mean), by = list(lon, lat, t, variable)]
  return(res_mean)
  # rm(file_name, var_name, nc_file, lon_range, lat_range res_array, res_df, res_dt, res_mean); gc()
}

# Function for processing ERA5 data
# NB: Not currently used
# lon_range <- c(12.75, 17.50); lat_range <- c(78, 79) # testers...
process_ERA5 <- function(file_name, file_prefix, lon_range, lat_range){
  
  # The base data rounded to daily
  # print(paste0("Began loading ",file_df$var_group[1]," at ", Sys.time()))
  # system.time(
  res_base <- plyr::ldply(annual_filter(file_df$files, year_range)$file_name, load_ERA5, 
                          .parallel = FALSE, .paropts = c(.inorder = FALSE),
                          lon_range = lon_range, lat_range = lat_range)
  # ) # 2 seconds for 1, 21 for 4, 553 for ~30
  
  # Combine the little half days and save
  print(paste0("Began meaning ",file_df$var_group[1]," at ", Sys.time()))
  res_dt <- data.table(res_base)
  setkey(res_dt, lon, lat, t)
  res_mean <- res_dt[, lapply(.SD, mean), by = list(lon, lat, t)] |> 
    filter(year(t) <= max(annual_filter(file_df$files, year_range)$year))
  saveRDS(res_mean, paste0("extracts/",file_prefix,"_ERA5_",file_df$var_group[1],".Rda"))
  rm(res_base, res_dt, res_mean); gc()
  return()
  # rm(file_df, file_prefix, lon_range, lat_range, year_range); gc()
}

# To change the EA5 coordinates to be the centre of the pixel, rather than the corner
# mutate(lon = lon+0.125, lat = lat-0.125)


# Both --------------------------------------------------------------------

# This function expects to be given only one pixel/ts at a time
# TODO: Add option to calculate based on 30, 20, and 10 year baselines
# Both forwards and backwards along the 30 yeaar period of data available
# testers...
# base_line <- c("1993-01-01", "2022-12-31")
calc_clim_anom <- function(df, base_line, point_accuracy){
  res <- ts2clm(df, y = value, roundClm = point_accuracy,
                climatologyPeriod = base_line)
  res$anom <- round(res$val-res$seas, point_accuracy)
  return(res)
}

