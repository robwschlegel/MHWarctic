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


# Process ERA5 ------------------------------------------------------------

# NB: To get things moving more quickly, ERA5 data were accessed from tikoraluk
# These were processed to hourly and saved as .Rda files and loaded here
# Long term the full data are being downloaded from Copernicus as NetCDF

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
ERA5_ncf <- plyr::ldply(ERA5_ncdf_files[26:28], load_ERA5, .parallel = TRUE,
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
  dplyr::select(-u10, -v10) |> 
  pivot_longer(wind_spd:wind_dir, names_to = "variable", values_to = "value")
is_ERA5 <- rbind(ERA5_all, ERA5_wind); gc()

# Save
saveRDS(is_ERA5, "~/pCloudDrive/FACE-IT_data/ERA5/is/is_ERA5.Rda")
data.table::fwrite(is_ERA5, "data/ERA5/is_ERA5.csv")
if(!exists("is_ERA5")) is_ERA5 <- data.table::fread("data/ERA5/is_ERA5.csv"); gc()


# Detect MHWs -------------------------------------------------------------

# Load GLORYS data
if(!exists("is_GLORYS")) is_GLORYS <- data.table::fread("data/GLORYS/is_GLORYS.csv"); gc()

# Extract just temperature
is_GLORYS_temp <- is_GLORYS |> 
  filter(variable == "temp") |> 
  mutate(t = as.Date(t)) |> 
  pivot_wider(names_from = variable, values_from = value) |> 
  dplyr::select(lon, lat, depth, t, temp)
rm(is_GLORYS); gc()

# Detect events per pixel and depth
# NB: takes about 10 minutes
is_GLORYS_MHW <- is_GLORYS_temp |> 
  group_by(lon, lat, depth) |> 
  nest() |> 
  mutate(clims = map(data, ts2clm,
                     climatologyPeriod = c("1993-01-01", "2022-12-31")),
         events = map(clims, detect_event),
         cats = map(events, category, S = FALSE)) |> 
  select(-data, -clims) |> ungroup()
rm(is_GLORYS_temp); gc()

# Save
saveRDS(is_GLORYS_MHW, "data/GLORYS/is_GLORYS_MHW.Rda")


# Analyse MHWs ------------------------------------------------------------

# Load GLORYS data
if(!exists("is_GLORYS_MHW")) is_GLORYS_MHW <- read_rds("data/GLORYS/is_GLORYS_MHW.Rda"); gc()

# MHW results
is_GLORYS_events <- is_GLORYS_MHW |> 
  select(-cats) |> 
  unnest(events) |> 
  filter(row_number() %% 2 == 0)  |> 
  unnest(events)

# Max count of events per pixel and depth
is_GLORYS_events |> 
  group_by(lon, lat, depth)  |>  
  summarise(count = max(event_no))

# Average metrics
is_GLORYS_events |> 
  dplyr::select(lon, lat, depth, duration, intensity_mean, intensity_max, intensity_cumulative, rate_onset, rate_decline) |> 
  group_by(lon, lat, depth) |> 
  summarise_all("mean", na.rm = T, .groups = "drop")

# Annual count of MHWs - first MHW
is_GLORYS_events |> 
  mutate(year = year(date_peak))  |>  
  group_by(lon, lat, depth, year) |>  
  summarise(count = n(), .groups = "drop")  |>  
  data.frame()

# Differences between pixels
summary_pixel <- is_GLORYS_events |> 
  ungroup() |> 
  dplyr::select(lon, lat, duration, intensity_mean, intensity_max, intensity_cumulative, rate_onset, rate_decline) |> 
  pivot_longer(duration:rate_decline) |> 
  group_by(lon, lat, name) |> 
  summarise(value_mean = round(mean(value, na.rm = TRUE), 1),
            value_sd = round(sd(value, na.rm = TRUE), 1), .groups = "drop") |> 
  unite("value_summary", value_mean:value_sd, sep = " ± ") |> 
  pivot_wider(names_from = name, values_from = value_summary) |>  
  dplyr::rename(i_cum = intensity_cumulative, i_max = intensity_max, 
                i_mean = intensity_mean, r_decline = rate_decline, r_onset = rate_onset) |> 
  dplyr::select(lon, lat, duration, i_mean, i_max, i_cum, r_onset, r_decline)

# Differences between depths
summary_depth <- is_GLORYS_events %>% 
  ungroup() |> 
  dplyr::select(depth, duration, intensity_mean, intensity_max, intensity_cumulative, rate_onset, rate_decline) %>% 
  pivot_longer(duration:rate_decline) %>% 
  group_by(depth, name) %>% 
  summarise(value_mean = round(mean(value, na.rm = TRUE), 1),
            value_sd = round(sd(value, na.rm = TRUE), 1), .groups = "drop") %>% 
  unite("value_summary", value_mean:value_sd, sep = " ± ") %>% 
  pivot_wider(names_from = name, values_from = value_summary) %>% 
  dplyr::rename(i_cum = intensity_cumulative, i_max = intensity_max, 
                i_mean = intensity_mean, r_decline = rate_decline, r_onset = rate_onset) %>% 
  dplyr::select(depth, duration, i_mean, i_max, i_cum, r_onset, r_decline)

# Differences between years
summary_year <- is_GLORYS_events |> 
  ungroup() |> 
  mutate(year = year(date_peak)) |> 
  dplyr::select(year, duration, intensity_mean, intensity_max, intensity_cumulative, rate_onset, rate_decline) %>% 
  pivot_longer(duration:rate_decline) %>% 
  group_by(year, name) %>% 
  summarise(value_mean = round(mean(value, na.rm = TRUE), 1),
            value_sd = round(sd(value, na.rm = TRUE), 1), .groups = "drop") %>% 
  unite("value_summary", value_mean:value_sd, sep = " ± ") %>% 
  pivot_wider(names_from = name, values_from = value_summary) %>% 
  dplyr::rename(i_cum = intensity_cumulative, i_max = intensity_max, 
                i_mean = intensity_mean, r_decline = rate_decline, r_onset = rate_onset) %>% 
  dplyr::select(year, duration, i_mean, i_max, i_cum, r_onset, r_decline)

# Differences between depths
summary_season <- is_GLORYS_events |> 
  ungroup() |> 
  mutate(month_peak = lubridate::month(date_peak, label = T),
         season = case_when(month_peak %in% c("Jan", "Feb", "Mar") ~ "Winter",
                            month_peak %in% c("Apr", "May", "Jun") ~ "Spring",
                            month_peak %in% c("Jul", "Aug", "Sep") ~ "Summer",
                            month_peak %in% c("Oct", "Nov", "Dec") ~ "Autumn"),
         season = factor(season, levels = c("Spring", "Summer", "Autumn", "Winter"))) |> 
  dplyr::select(season, duration, intensity_mean, intensity_max, intensity_cumulative, rate_onset, rate_decline) |> 
  pivot_longer(duration:rate_decline) |> 
  group_by(season, name) |> 
  summarise(value_mean = round(mean(value, na.rm = TRUE), 1),
            value_sd = round(sd(value, na.rm = TRUE), 1), .groups = "drop") %>% 
  unite("value_summary", value_mean:value_sd, sep = " ± ") %>% 
  pivot_wider(names_from = name, values_from = value_summary) %>% 
  dplyr::rename(i_cum = intensity_cumulative, i_max = intensity_max, 
                i_mean = intensity_mean, r_decline = rate_decline, r_onset = rate_onset) %>% 
  dplyr::select(season, duration, i_mean, i_max, i_cum, r_onset, r_decline)


# Calculate anoms ---------------------------------------------------------

# Find grid pairing of ERA5 data to GLORYS
# NB: Comparing GLORYS pixels to the centre of the ERA5 pixels
grid_product_match <- grid_match(grid_GLORYS, grid_ERA5_centre) |>  
  dplyr::rename(lon_G = lon.x, lat_G = lat.x, lon_Ec = lon.y, lat_Ec = lat.y) |> 
  mutate(lon_E = lon_Ec-0.125, lat_E = lat_Ec+0.125) |> dplyr::select(-dist, everything(), dist)

# Load large data
if(!exists("is_GLORYS")) is_GLORYS <- data.table::fread("data/GLORYS/is_GLORYS.csv"); gc()
if(!exists("is_ERA5")) is_ERA5 <- data.table::fread("data/ERA5/is_ERA5.csv"); gc()

# Pivot wider for merging
is_GLORYS_wide <- is_GLORYS |> ungroup() |> 
  mutate(depth = case_when(depth < 1 ~ 0, TRUE ~ depth)) |> 
  pivot_wider(names_from = variable, values_from = value) |> 
  left_join(grid_product_match[c("lon_G", "lat_G", "lon_E", "lat_E")], by = c("lon" = "lon_G", "lat" = "lat_G"))
is_ERA5_wide <- is_ERA5 |> ungroup() |> mutate(depth = 0) |> 
  pivot_wider(names_from = variable, values_from = value) #|> 
  # NB: Don't join this here as it duplicates pixels to match GLORYS resolution
  # left_join(grid_product_match, by = c("lon" = "lon_E", "lat" = "lat_E"))
rm(is_GLORYS, is_ERA5); gc()

# Make the large join
# NB: This takes a while and a lot of RAM
is_all <- left_join(is_GLORYS_wide, is_ERA5_wide, by = c("lon_E" = "lon", "lat_E" = "lat", "t", "depth")) |> 
  dplyr::select(-lon_E, -lat_E)
rm(is_GLORYS_wide, is_ERA5_wide); gc()

# Pivot longer
# NB: This is very RAM heavy
is_all_long <- is_all |> 
  # NB: For the time being I am not calculating the escape value of SWR out of the MLD
  # I would need to decide on a Urlov water type for Isfjorden first
  # mutate(down = msnswrf*((0.67*exp(-mld/1.00))+((1-0.67)*exp(-mld/17.00)))) |> 
  # mutate(down = replace_na(down, 0),
  #        swr_down = msnswrf-down) |> 
  dplyr::rename(lwr = msnlwrf, swr = msnswrf, lhf = mslhf, 
                shf = msshf, mslp = msl, sst = temp) |> 
  # NB: Rather recalculate directions again later from the u/v vectors because directions are in radian values
  dplyr::select(-wind_dir, -cur_dir) |>
  mutate(qnet = lwr+swr+lhf+shf,
         qnet_mld = (qnet*86400)/(mld*1024*4000),
         lwr_mld = (lwr*86400)/(mld*1024*4000),
         swr_mld = (swr*86400)/(mld*1024*4000),
         lhf_mld = (lhf*86400)/(mld*1024*4000),
         shf_mld = (shf*86400)/(mld*1024*4000),
         mld_1 = 1/mld) %>% 
  pivot_longer(cols = c(-lon, -lat, -t, -depth), names_to = "variable", values_to = "value") |> 
  filter(!is.na(value))
rm(is_all); gc()

# Calculates clims+anoms and save
# is_mini <- filter(is_all_long, lon == lon[1], lat == lat[1]) # For testing
# is_mini_date <- is_mini |> group_by(lon, lat, depth, variable) |> summarise(min_date = min(t), max_date = max(t))
registerDoParallel(cores = 15)
system.time(
  is_all_anom <- plyr::ddply(is_all_long, c("lon", "lat", "depth", "variable"), calc_clim_anom,
                             .parallel = T, .paropts = c(.inorder = FALSE),
                             base_line = c("1993-01-01", "2022-12-31"), point_accuracy = 6)
) # 5 seconds for 1 pixel with 26 depths, 721 seconds for all
data.table::fwrite(is_all_anom, "data/is_all_anom.csv")
if(!exists("is_all_anom")) is_all_anom <- data.table::fread("data/is_all_anom.csv"); gc()

# test visual
is_all_anom |> filter(t == "1997-01-01", variable == "siconc") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = value)) + scale_fill_viridis_c() +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)
is_all_anom |> filter(t == "2010-01-18", variable == "siconc") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = anom)) +
  scale_fill_gradient2(low = "blue", high = "red") +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)


# Decompose heat budget ---------------------------------------------------

