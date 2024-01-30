# 02_analyse.R
# Load and analyse the physical data


# Setup -------------------------------------------------------------------

source("code/00_functions.R")


# Process GLORYS ----------------------------------------------------------

registerDoParallel(cores = 15)
system.time(
  is_GLORYS <- plyr::ldply(GLORYS_files, load_GLORYS, .parallel = TRUE)
) # 99 seconds for 360
saveRDS(is_GLORYS, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS.Rda")
data.table::fwrite(is_GLORYS, "data/GLORYS/is_GLORYS.csv")
if(!exists("is_GLORYS")) is_GLORYS <- data.table::fread("data/GLORYS/is_GLORYS.csv"); gc()

# test visual
is_GLORYS |> filter(t == "1997-01-01", variable == "siconc") |>
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = value)) + scale_fill_viridis_c() +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)

# Calculates clims+anoms and save
# is_mini <- filter(is_GLORYS, lon == lon[1], lat == lat[1]) # For testing
registerDoParallel(cores = 15)
system.time(
  is_GLORYS_anom <- plyr::ddply(is_GLORYS, c("lon", "lat", "depth", "variable"), calc_clim_anom,
                                .parallel = T, .paropts = c(.inorder = FALSE),
                                base_line = c("1993-01-01", "2022-12-31"), point_accuracy = 6)
) # 5 seconds for 1 pixel with 26 depths, 969 seconds for all
data.table::fwrite(is_GLORYS_anom, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.csv")
saveRDS(is_GLORYS_anom, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.Rda")
if(!exists("is_GLORYS_anom")) is_GLORYS_anom <- data.table::fread("~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.csv"); gc()

# test visual
is_GLORYS_anom |> filter(t == "1997-01-01", variable == "siconc") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = value)) + scale_fill_viridis_c() +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)
is_GLORYS_anom |> filter(t == "2010-01-18", variable == "siconc") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = anom)) +
  scale_fill_gradient2(low = "blue", high = "red") +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)


# Process ERA5 ------------------------------------------------------------

# NB: To get things moving more quickly, ERA5 data were accessed from tikoraluk
# These were processed to hourly and saved as .Rda files and loaded here
# Long term the full data are being downloaded from Copernicus as NetCDF

# File locations
ERA5_Rda_files <- dir("~/pCloudDrive/FACE-IT_data/ERA5/is", "Rda", full.names = TRUE)
ERA5_ncdf_files <- dir("~/pCloudDrive/FACE-IT_data/ERA5/is", "nc", full.names = TRUE)

# Load Rda data
ERA5_Rda <- plyr::ldply(ERA5_Rda_files, pivot_rds, .parallel = TRUE) |> 
  filter(lon >= 12.75, lon <= 17.5, lat >= 78, lat <= 79)

# Date ranges
ERA5_Rda_date_range <- ERA5_Rda |> 
  summarise(min_date = min(t), max_date = max(t), .by = "variable")

# Check grid
ERA5_Rda_grid <- dplyr::select(ERA5_Rda, lon, lat) |> distinct()

# Load ERA5 from NetCDF files
# NB: This will change later...
ERA5_ncf <- plyr::ldply(ERA5_ncdf_files[14:17], load_ERA5, .parallel = TRUE,
                        lon_range = c(12.75, 17.50), lat_range = c(78, 79))

# Combine the little half days
ERA5_ncf <- data.table(ERA5_ncf)
setkey(ERA5_ncf, lon, lat, t, variable)
ERA5_ncf <- ERA5_ncf[, lapply(.SD, mean), by = list(lon, lat, t, variable)] |> filter(year(t) <= 2022)

# Check grid
ERA5_ncf_grid <- dplyr::select(ERA5_ncf, lon, lat) |> distinct()

# Combine Rda and ncdf
ERA5_all <- rbind(ERA5_Rda, ERA5_ncf) |> distinct()

# Smooth out the join
# NB: This is necessary for the wind calcs
ERA5_all <- data.table(ERA5_all)
setkey(ERA5_all, lon, lat, t, variable)
ERA5_all <- ERA5_all[, lapply(.SD, mean), by = list(lon, lat, t, variable)] |> filter(year(t) <= 2022)

# Calculate wind speed and direction
ERA5_wind <- ERA5_all |> 
  dplyr::filter(variable %in% c("u10", "v10")) |> 
  pivot_wider(names_from = variable, values_from = value) |> 
  mutate(wind_spd = round(sqrt(u10^2 + v10^2), 4),
         wind_dir = round((270-(atan2(v10, u10)*(180/pi)))%%360)) |> 
  pivot_longer(u10:wind_dir, names_to = "variable", values_to = "value")
ERA5_all <- rbind(ERA5_all, ERA5_wind) |> distinct(); gc()

# Calculate anoms
system.time(
  ERA5_anom <- plyr::ddply(ERA5_all, c("lon", "lat", "variable"), calc_clim_anom,
                           .parallel = TRUE, .paropts = c(.inorder = FALSE),
                           base_line = c("1993-01-01", "2022-12-31"), point_accuracy = 6)
) # 38 seconds for all
data.table::fwrite(ERA5_anom, "~/pCloudDrive/FACE-IT_data/ERA5/is/ERA5_anom.csv")
saveRDS(ERA5_anom, "~/pCloudDrive/FACE-IT_data/ERA5/is/ERA5_anom.Rda")
if(!exists("ERA5_anom")) ERA5_anom <- data.table::fread("~/pCloudDrive/FACE-IT_data/ERA5/is/ERA5_anom.csv"); gc()

# test visual
ERA5_anom |> filter(t == "1997-01-01", variable == "t2m") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = value)) + scale_fill_viridis_c() +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)
ERA5_anom |> filter(t == "2010-01-18", variable == "e") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = anom)) +
  scale_fill_gradient2(low = "blue", high = "red") +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)

