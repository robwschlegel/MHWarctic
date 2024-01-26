# 02_analyse.R
# Load and analyse the physical data


# Setup -------------------------------------------------------------------

source("code/00_functions.R")

# 
# registerDoParallel(cores = 7)
# system.time(
#   is_GLORYS <- plyr::ldply(GLORYS_files, load_GLORYS, .parallel = TRUE)
# ) # 99 seconds for 360
# saveRDS(is_GLORYS, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS.Rda")
# data.table::fwrite(is_GLORYS, "data/GLORYS/is_GLORYS.csv")
# if(!exists("is_GLORYS")) is_GLORYS <- data.table::fread("data/GLORYS/is_GLORYS.csv"); gc()


# Process GLORYS ----------------------------------------------------------

# test visual
# is_GLORYS |> filter(t == "1997-01-01", variable == "siconc") |> 
#   ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = value)) + scale_fill_viridis_c() +
#   coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)

# Calculates clims+anoms and save
# is_mini <- filter(is_GLORYS, lon == lon[1], lat == lat[1]) # For testing
# registerDoParallel(cores = 7)
# system.time(
#   is_GLORYS_anom <- plyr::ddply(is_GLORYS, c("lon", "lat", "depth", "variable"), calc_clim_anom, 
#                                 .parallel = T, .paropts = c(.inorder = FALSE), 
#                                 base_line = c("1993-01-01", "2022-12-31"), point_accuracy = 6)
# ) # 5 seconds for 1 pixel with 26 depths, 969 seconds for all
# data.table::fwrite(is_GLORYS_anom, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.csv")
# saveRDS(is_GLORYS_anom, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.Rda")
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


