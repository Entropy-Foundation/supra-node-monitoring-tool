#!/bin/bash

LOG_FILE="$1/supra_node_logs/supra.log*"

# Check if log files exist
if ! ls $LOG_FILE 1> /dev/null 2>&1; then
  echo "Error: Log files not found at $LOG_FILE"
  exit 1
fi

# Extract the last occurrence of the "Reached connectivity level" line
line=$(grep "Reached connectivity level" $LOG_FILE | tail -1)

# Debug: Show the extracted line
# echo "Extracted line: $line"

# Check if the line was found
if [ -z "$line" ]; then
  echo "Error: No matching log entries found"
  exit 1
fi

# Extract the validator count from the line
validators_numbers=$(echo "$line" | awk '{print $NF}' | awk -F'/' '{print $1}')

# Ensure the value is valid (a number)
if ! [[ "$validators_numbers" =~ ^[0-9]+$ ]]; then
  echo "Error: Could not extract a valid number"
  exit 1
fi

# Output the validator count without trailing newlines or spaces
echo -n "$validators_numbers"