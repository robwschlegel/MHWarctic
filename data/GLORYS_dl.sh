#!/bin/bash

# Output directory
outdir="~/pCloudDrive/FACE-IT_data/GLORYS"

# Dataset ID and date range
productId="cmems_mod_glo_phy_my_0.083deg_P1D-m" # 1993-01-01 to 2021-06-31
# startDate=$(date -d "1993-01-03" +%Y-%m-%d)
# endDate=$(date -d "1993-01-01" +%Y-%m-%d) # For testing
# endDate=$(date -d "1993-01-31" +%Y-%m-%d)
# endDate=$(date -d "2021-06-31" +%Y-%m-%d)
# productId="cmems_mod_glo_phy_myint_0.083deg_P1D-m" # 2021-07-01 to near present
# startDate=$(date -d "2021-07-01" +%Y-%m-%d)
# endDate=$(date -d "2022-12-31" +%Y-%m-%d)

# Coordinates
lon=(8 35)   #longitude
lat=(76 81)     #latitude

# Variables
variable=("thetao" "so" "uo" "vo" "zos" "mlotst" "bottomT" "siconc" "sithick" "usi" "vsi")

# time step
# addDays=1

# endDate=$(date -d "$endDate + $addDays days" +%Y-%m-%d)

# Time range loop
# while [[ "$startDate" != "$endDate" ]]; do
# 
#     echo "=============== Date: $startDate ===================="
# 
#     command="copernicus-marine subset -i $productId \
#     -x ${lon[0]} -X ${lon[1]} -y ${lat[0]} -Y ${lat[1]} -z 0. -Z 5000.\
#     -v ${variable[0]} -v ${variable[1]} -v ${variable[2]} -v ${variable[3]} -v ${variable[4]} -v ${variable[5]} -v ${variable[6]} -v ${variable[7]} -v ${variable[8]} -v ${variable[9]} -v ${variable[10]} \
#     -t \"$startDate\" -T \"$startDate\" \
#     --force-download -o $outdir --overwrite-output-data -f sval_GLORYS_$(date -d "$startDate" +%Y-%m-%d).nc"
# 
#     echo -e "$command \n============="
#     eval "$command"
# 
#     startDate=$(date -d "$startDate + $addDays days" +%Y-%m-%d)
# 
# done

for y in {1993..1993}; do
  for m in {6..12}; do
    
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
    echo "=========== Download completed! ==========="
    
  done
done

