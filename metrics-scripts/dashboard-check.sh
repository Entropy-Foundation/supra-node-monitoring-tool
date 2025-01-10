#!/bin/bash

# Grafana instance URL and API token
grafana_url="https://monitoring.services.supra.com"
api_token="glsa_RL9Ld2zAHE2aM5MUwGjOWoMmRAgxprHP_91dd26c9"
folder_title="$folder_name"

# API endpoint for fetching folders
folders_url="$grafana_url/api/folders"

# Send GET request to fetch all folders
response=$(curl -s -X GET "$folders_url" -H "Content-Type: application/json" -H "Authorization: Bearer $api_token")

# Filter the folder by title using jq
folder_info=$(echo "$response" | jq -r ".[] | select(.title==\"$folder_title\")")

if [ -z "$folder_info" ]; then
    echo "Folder with title '$folder_title' does not exist"
    exit 1
else
    echo "Folder details:"
    echo "$folder_info" | jq '.'

    # Extract folder UID
    folder_uid=$(echo "$folder_info" | jq -r '.uid')
    
    # API endpoint for deleting the folder
    delete_folder_url="$grafana_url/api/folders/$folder_uid"

    # Send DELETE request to remove the folder
    delete_response=$(curl -s -X DELETE "$delete_folder_url" -H "Content-Type: application/json" -H "Authorization: Bearer $api_token")

    # Check if the delete was successful
    if [ -z "$delete_response" ]; then
        echo "Folder with title '$folder_title' and UID '$folder_uid' has been successfully deleted"
    else
        echo "Failed to delete the folder. Response: $delete_response"
    fi
fi
