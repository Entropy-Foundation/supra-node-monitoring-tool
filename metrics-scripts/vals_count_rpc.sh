#!/bin/bash

LOG_FILE="$1/log/supra-fullnode.log"

# Check if the log file exists
if ! ls $LOG_FILE* 1> /dev/null 2>&1; then
  exit 0  # Quiet exit if no log files found
fi

# Search for the latest occurrence of the "Reached connectivity level" line
line=$(grep -h "Reached connectivity level" $LOG_FILE* | tail -1)

# If the line is not found, exit quietly
if [ -z "$line" ]; then
  exit 0
fi

# Extract the value (e.g., 175) from the line
validators_numbers=$(echo "$line" | awk '{print $NF}' | awk -F'/' '{print $1}')

# Ensure the value is a valid number before printing it
if [[ "$validators_numbers" =~ ^[0-9]+$ ]]; then
  echo -n "$validators_numbers"
fi