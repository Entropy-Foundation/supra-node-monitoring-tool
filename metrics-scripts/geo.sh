#!/bin/bash
geo=$(curl -s ipinfo.io)
lat=$(echo $geo | jq -r '.loc' | cut -d',' -f1)
lon=$(echo $geo | jq -r '.loc' | cut -d',' -f2)

# Output JSON with lat and long (as fields)
echo "{\"latitude\": $lat, \"longitude\": $lon}"
# echo "metrics latitude=$lat,longitude=$lon"
