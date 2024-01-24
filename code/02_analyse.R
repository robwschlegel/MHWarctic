# 02_analyse.R
# Load and analyse the physical data


# Setup -------------------------------------------------------------------

source("code/00_functions.R")


# Load GLORYS -------------------------------------------------------------

registerDoParallel(cores = 7)
system.time(
  is_GLORYS <- plyr::ldply(GLORYS_files, load_GLORYS, .parallel = TRUE)
) # 99 seconds for 360
saveRDS(is_GLORYS, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS.Rda")
is_GLORYS <- readRDS("~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS.Rda")

# test visual
is_GLORYS |> filter(t == "1997-01-01", variable == "siconc") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = value)) + scale_fill_viridis_c() +
  coord_quickmap(xlim = bbox_is[1:2], ylim = bbox_is[3:4], expand = T)

# Calculates clims+anoms and save
registerDoParallel(cores = 7)
system.time(
  is_GLORYS_anom <- plyr::ddply(is_GLORYS, c("lon", "lat", "depth", "variable"), calc_clim_anom, .parallel = T,
                                point_accuracy = 6, .paropts = c(.inorder = FALSE))
) # 732 seconds on 25 cores
saveRDS(is_GLORYS_anom, "~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.Rda")
is_GLORYS_anom <- readRDS("~/pCloudDrive/FACE-IT_data/GLORYS/is_GLORYS_anom.Rda")

# test visual
is_GLORYS_anom |> filter(t == "1993-06-18", variable == "ssh") |> 
  ggplot(aes(x = lon, y = lat)) + geom_tile(aes(fill = anom)) +
  scale_fill_gradient2(low = "blue", high = "red") +
  coord_quickmap(xlim = bbox_is_wide[1:2], ylim = bbox_is_wide[3:4], expand = T)

