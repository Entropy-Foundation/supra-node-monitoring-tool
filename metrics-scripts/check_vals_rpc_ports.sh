#!/bin/bash

# Ensure at least one port number is provided as an argument
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <port_number> [<port_number> ...]"
  exit 1
fi

# Loop through each port number provided as arguments
for port in "$@"; do
  if netstat -an | grep -E "LISTEN" | grep -E "[^0-9]$port[^0-9]" >/dev/null; then
    # Port is listening, output a success metric
    echo "port_check,port=$port status=200"
  else
    # Port is not listening, output an error metric
    echo "port_check,port=$port status=404"
  fi
done
