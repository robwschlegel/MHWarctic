# code/01_download.R
# The code used to download the large datasets


# Setup -------------------------------------------------------------------

source("code/00_functions.R")
library(ecmwfr) # For downloading ERA5 data

## Set CDS credentials
# NB: To replicate this file one must first create an account:
# https://cds.climate.copernicus.eu
# Then save your UID and API key as a vector
# e.g. CDS_API_UID_KEY <- c("UID", "API_KEY")
# e.g. save(CDS_API_UID_KEY, file = "metadata/CDS_API_UID_KEY.RData")
# load("metadata/CDS_API_UID_KEY.RData")
# cds.key <- CDS_API_UID_KEY[2]
# NB: This requires your login password for CDS
# But you only need to run it once
# wf_set_key(user = CDS_API_UID_KEY[1], key = cds.key, service = "cds")

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

wf_request(user = CDS_API_UID_KEY[1],
           request = request,
           transfer = TRUE,
           path = "~/pCloudDrive/FACE-IT_data/ERA5",
           verbose = TRUE)


# GLORYS ------------------------------------------------------------------

# We will use the OPeNDAP method to access these data

# creates the OPeNDAP url
CM_server <- "@nrt.cmems-du.eu"
datasetID <- "cmems_mod_glo_phy_my_0.083_P1D-m"
CM_user <- CM_UID_PWD[1]
CM_pswd <- CM_UID_PWD[2]
GLORYS_url <- paste0("https://",CM_user,":",CM_pswd,CM_server,"/thredds/dodsC/",datasetID)

GLORYS_url <- "https://nrt.cmems-du.eu/thredds/dodsC/cmems_mod_glo_phy-cur_anfc_0.083deg_P1D-m"

# cmems_mod_glo_phy_my_0.083_P1D-m

# Open the connection
ds <- nc_open(GLORYS_url)

