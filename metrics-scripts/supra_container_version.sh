#!/bin/bash

# Check if image name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <image_name>"
    exit 1
fi

# Get the image name from the argument
image_name=$1

# Get the image tag by filtering the image name and extract the tag from the full image name
image_tag=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "$image_name" | awk -F: '{print $2}' | head -n 1)

# Check if the image tag exists
if [ -z "$image_tag" ]; then
    echo "No image found with the name '$image_name'"
    exit 1
fi

# Output the tag value only
echo "$image_tag"
