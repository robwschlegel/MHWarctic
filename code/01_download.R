# code/01_download.R
# The code used to download the large datasets


# Setup -------------------------------------------------------------------

source("code/00_functions.R")


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

# Download ans install Miniforge
# https://github.com/conda-forge/miniforge
# NB: One may need to run this in the console after installing
# source ~/.profile

# To start the environment run:
# mamba activate cmc-beta

# Then this to insert your username and password for future use
# eval "copernicus-marine login"

# Basic commands for Copernicus Marine Toolbox
# https://help.marine.copernicus.eu/en/articles/7972861-copernicus-marine-toolbox-cli-subset



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

# https://catalogue.marine.copernicus.eu/documents/PUM/CMEMS-GLO-PUM-001-030.pdf

# Daily GLORYS from 1993-01-01 to 2021-06-31
"cmems_mod_glo_phy_my_0.083deg_P1D-m"

# Daily GLORYS from 2021-07-01 to recent time
"cmems_mod_glo_phy_myint_0.083deg_P1D-m"


# system("mamba activate cmc-beta")
system("copernicus-marine subset -i cmems_mod_glo_phy_my_0.083deg_P1D-m -x 9.0 -X 35.0 -y 76.0 -Y 81.0 -z 0. -Z 10. -v uo -v vo -t 2022-01-01 -T 2022-01-03 -o ~/pCloudDrive/FACE-IT_data/GLORYS -f test.nc")
"copernicus-marine subset -i cmems_mod_glo_phy_myint_0.083deg_P1D-m -x 9.0 -X 35.0 -y 76.0 -Y 81.0 -z 0. -Z 10. -v uo -v vo -t 2022-01-01 -T 2022-01-03 -o ~/pCloudDrive/FACE-IT_data/GLORYS -f test2.nc"

# Download static values
"copernicus-marine -i cmems_mod_glo_phy_my_0.083deg_static -x 9.0 -X 35.0 -y 76.0 -Y 81.0 -v e1t -v e2t -v e3t -v mask -v deptho -v deptho_lev -v mdt -o ~/pCloudDrive/FACE-IT_data/GLORYS -f sval_static.nc"


# Here is a cunning method of generating a brick of year-month values
date_range <- base::expand.grid(1993:2018, 1:12) %>% 
  dplyr::rename(year = Var1, month = Var2) %>% 
  arrange(year, month) %>% 
  mutate(year_mon = paste0(year,"-",month)) %>% 
  dplyr::select(year_mon)


# Inspect -----------------------------------------------------------------

# Load a file
test_GLORYS <- tidync("~/pCloudDrive/FACE-IT_data/GLORYS/test.nc") |> 
  hyper_tibble() |> 
  mutate(t = as.Date(as.POSIXct(time*3600, origin = "1950-01-01", tz = "UTC")))

test_GLORYS |> 
  filter(depth == min(depth), t == min(t)) |> 
  ggplot(aes(x = longitude, y = latitude)) +
  geom_raster(aes(fill = uo))

                     