#!/bin/bash

# Use awk to process all log files in a single pass
total_sum=$(awk '
    /Total transactions:/ {
        gsub(/[()]/, "", $NF)  # Remove parentheses from the last field
        sum += $NF             # Add to sum
    }
    END {
        print sum              # Print the total sum
    }
' $1/supra_node_logs/supra.log*)

# Print the result in InfluxDB line protocol format
echo "total_transactions value=$total_sum"
