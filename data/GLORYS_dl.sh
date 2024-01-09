#!/bin/bash

# To download GLORYS data follow these steps:

# 1) Create an account
# https://data.marine.copernicus.eu/register

# 2) Download and install Miniforge
# https://github.com/conda-forge/miniforge
# NB: May need to run this in the console after installing
# source ~/.profile

# 3) Install the new Copernicus Marine Toolbox
# https://help.marine.copernicus.eu/en/articles/7970514-copernicus-marine-toolbox-installation
# Basic commands, FYI
# https://help.marine.copernicus.eu/en/articles/7972861-copernicus-marine-toolbox-cli-subset

# 4) Startup necessary environment
# mamba activate cmc-beta
# And insert your username and password for future use
# eval "copernicus-marine login"

# 5) Run this script in that environment
# NB: Change directory or file pathway accordingly
# bash GLORYS_dl.sh

# Note that this script can be replicated in R and run in RStudio:
# https://help.marine.copernicus.eu/en/articles/8638253-how-to-download-data-via-the-copernicus-marine-toolbox-in-r

# Output directory
outdir="~/pCloudDrive/FACE-IT_data/GLORYS"

# Product ID and date range
# NB: Change product ID according to desired dates of data
productId="cmems_mod_glo_phy_my_0.083deg_P1D-m" # 1993-01-01 to 2021-06-31
# productId="cmems_mod_glo_phy_myint_0.083deg_P1D-m" # 2021-07-01 to near present

# Coordinates
lon=(8 35)
lat=(76 81)

# Variables
variable=("thetao" "so" "uo" "vo" "zos" "mlotst" "bottomT" "siconc" "sithick" "usi" "vsi")

for y in {1995..1995}; do
  for m in {1..12}; do
    
    startDate=$(date -d "$y-$m-1" +%Y-%m-%d)
    endDate=$(date -d "$y-$m-1 + 1 month - 1 day" +%Y-%m-%d)
    fileDate=$(date -d "$startDate" '+%Y-%m')
    
    echo "=============== $startDate to $endDate ===================="

    command="copernicus-marine subset -i $productId \
    -x ${lon[0]} -X ${lon[1]} -y ${lat[0]} -Y ${lat[1]} -z 0. -Z 5000.\
    -v ${variable[0]} -v ${variable[1]} -v ${variable[2]} -v ${variable[3]} -v ${variable[4]} -v ${variable[5]} -v ${variable[6]} -v ${variable[7]} -v ${variable[8]} -v ${variable[9]} -v ${variable[10]} \
    -t \"$startDate\" -T \"$endDate\" \
    --force-download -o $outdir --overwrite-output-data -f sval_GLORYS_$fileDate.nc"

    echo -e "$command \n============="
    eval "$command"
    echo "=========== Download completed! ===========\n"
    
  done
done

