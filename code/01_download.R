# code/01_download.R
# The code used to download the large datasets


# Setup -------------------------------------------------------------------

source("code/00_functions.R")
devtools::install_github("metno/esd")

## Set CDS credentials
# NB: To replicate this file one must first create an account:
# https://cds.climate.copernicus.eu
# Then save your UID and API key as a vector
# e.g. CDS_API_UID_KEY <- c("UID", "API_KEY")
# e.g. save(CDS_API_UID_KEY, file = "metadata/CDS_API_UID_KEY.RData")
load("metadata/CDS_API_UID_KEY.RData")
# NB: This requires your login password for CDS
# But you only need to run it once
# wf_set_key(user = CDS_API_UID_KEY[1], key = CDS_API_UID_KEY[2], service = "cds")

## Load Copernicus Marine credentials
# NB: To replicate this file one must first create an account:
# https://data.marine.copernicus.eu/register
# Then save your user ID (UID) and password as a vector
# e.g. CM_UID_PWD <- c("UID", "password")
# e.g. save(CM_UID_PWD, file = "metadata/CM_UID_PWD.RData")
load("metadata/CM_UID_PWD.RData")


# ERA5 --------------------------------------------------------------------

# Set request
# TODO: Create a list of list to download by year
request <- list(
  dataset_short_name = "reanalysis-era5-single-levels",
  product_type = "reanalysis",
  format = "netcdf",
  variable = "2m_temperature",
  year = "2016",
  month = "08",
  day = "16",
  time = c("00:00", "01:00", "02:00", "03:00", "04:00", "05:00", 
           "06:00", "07:00", "08:00", "09:00", "10:00", "11:00", 
           "12:00", "13:00", "14:00", "15:00", "16:00", "17:00", 
           "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"),
  # area is specified as N, W, S, E
  area = c(81, 9, 76, 35),
  target = "sval_test.nc"
)

# NB: This requires your login password for CDS
wf_request(user = CDS_API_UID_KEY[1],
           request = request,
           transfer = TRUE,
           path = "~/pCloudDrive/FACE-IT_data/ERA5",
           verbose = TRUE)


# GLORYS ------------------------------------------------------------------

# To download these data see the bash script "data/GLORYS_dl.sh"


# Inspect -----------------------------------------------------------------

# Load a file
test_GLORYS <- tidync("~/Downloads/mercatorglorys12v1_gl12_mean_19930101_R19930106.nc") |> 
  hyper_filter(longitude = between(longitude, 0, 5),
               latitude = between(latitude, 0, 5)) |> 
  hyper_tibble() |> 
  mutate(t = as.Date(as.POSIXct(time*3600, origin = "1950-01-01", tz = "UTC")))

# Load a file
test_GLORYS <- tidync("~/pCloudDrive/FACE-IT_data/GLORYS/sval_GLORYS_1993-01-01.nc") |> 
  activate("D2,D1,D3") |> # 2D layers
  hyper_tibble() |> 
  mutate(t = as.Date(as.POSIXct(time*3600, origin = "1950-01-01", tz = "UTC")))

# Visualise
test_GLORYS |> 
  # filter(depth == min(depth), t == min(t)) |> 
  ggplot(aes(x = longitude, y = latitude)) +
  geom_raster(aes(fill = sithick)) +
  scale_fill_viridis_c()


                     