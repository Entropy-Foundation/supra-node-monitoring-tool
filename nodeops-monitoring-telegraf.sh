#!/bin/bash

# Function to print messages in a consistent format
print_message() {
    echo -e "\n\033[1;34m$1\033[0m"
}

# Function to print error messages in a consistent format
print_error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m"
}


# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Check if API key is set
if [ -z "$api_key" ]; then
  print_error "API key is missing."
  exit 1
fi

URL="https://secure-api.services.supra.com"

echo "Checking the URL: $URL"

# Use curl to send a HEAD request and get the HTTP status code (-ILk to follow redirects and ignore SSL errors)
STATUS_CODE=$(curl -ILk -o /dev/null -w "%{http_code}" "$URL")

# Check the status code and print the corresponding message
if [ "$STATUS_CODE" -eq 404 ]; then
    echo "Status 404: Your IP is whitelisted."
elif [ "$STATUS_CODE" -eq 403 ]; then
    echo "Status 403: Your IP is not whitelisted. Please provide your IPv4 to the Supra Team."
    exit 1
else
    echo "Unexpected status code: $STATUS_CODE"
fi

# Update package lists
echo "Updating package lists..."
apt-get update -y

# Create directory for keyrings
echo "Creating directory for keyrings..."
mkdir -p /etc/apt/keyrings
chmod 0755 /etc/apt/keyrings

# Add Grafana signing key
echo "Adding Grafana signing key..."
curl -sSL https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Add Grafana repository
echo "Adding Grafana repository..."
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

# Update package lists again
echo "Updating package lists again..."
apt-get update -y

# Install promtail
echo "Installing promtail..."
apt-get install -y promtail

echo "promtail installation completed."

# Copy promtail service configuration
echo "Copying promtail service configuration..."
tee /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/promtail -config.file /etc/promtail/config.yml
TimeoutSec=60
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Restart promtail service
echo "Restarting promtail service..."
systemctl daemon-reload
systemctl restart promtail

echo "Done!"

public_ip=$(curl -s ifconfig.me)

# User input for public IP
read -p "Please enter the Public IPv4 address of the server: " public_ip

# Confirm the provided public IP address
print_message "You entered: $public_ip"
read -p "Is this correct? (y/n) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    print_message "Public IPv4 address confirmed: $public_ip"
else
    print_error "Public IPv4 address not confirmed. Please try again."
    exit 1
fi

# Predefined variables

hostname=$(hostname)
CPU_MAX=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
MEM_MAX=$(grep MemTotal /proc/meminfo | awk '{sub(/^[ \t]+/, "", $2); sub(/ kB$/, "", $2); print $2 * 1024}')
DISK_SIZE=$(df -B1 / | awk 'NR==2 {print $2}')
uuid=$(uuidgen)
uuid_2=$(uuidgen)
title="Logs-$hostname-$public_ip"
job="$hostname-$public_ip"
folder_uuid=$(uuidgen)
folder_name="$hostname-$public_ip-Dashboard"
metric_name="Metric-$hostname-$public_ip"
export folder_name="$hostname-$public_ip-Dashboard"

print_message "Job name is: $job"
print_message "Title name is: $title"

# Ask the user for the log file path
read -p "Please enter the log file path: " log_path

# Confirm the provided log path
print_message "You entered: $log_path"
read -p "Is this correct? (y/n) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    print_message "Log file path confirmed: $log_path"
else
    print_error "Log file path not confirmed. Please try again."
    exit 1
fi


read -p "Please enter the supra binary path: " supra_location

# Confirm the provided log path
print_message "You entered: $supra_location"
read -p "Is this correct? (y/n) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    print_message "supra binary path confirmed: $supra_location"
else
    print_error "supra binary path not confirmed. Please try again."
    exit 1
fi

# Generate the promtail.yml file
cat << EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: https://loki.services.supra.com/loki/api/v1/push

scrape_configs:
  - job_name: smr
    static_configs:
      - targets:
        - localhost
        labels:
          job: $job
          __path__: "$log_path"
EOF

# Set permissions for the promtail.yml file
chmod 0644 /etc/promtail/config.yml

service promtail restart

# Deleting the Folder if it exists
print_message "Attempting to delete the folder if it exists..."
delete_response=$(curl -s -w "%{http_code}" -o /tmp/delete_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"folder_name\": \"$folder_name\"}" \
     https://secure-api.services.supra.com/monitoring-supra-delete-folder)

# Extract HTTP status code and response body for delete request
delete_status=$(tail -n1 <<< "$delete_response")
delete_response_body=$(head -n -1 <<< "$delete_response")

# Handle response based on HTTP status code
case $delete_status in
  200)
    print_message "Folder deleted successfully."
    ;;
  404)
    print_message "Folder not found. Proceeding to create a new folder."
    ;;
  400)
    print_error "Error 400: Please enter a valid/updated API key."
    rm /tmp/delete_response.txt
    exit 1
    ;;
  401)
    print_error "Error 401: Unauthorized access. Please check your API key."
    rm /tmp/delete_response.txt
    exit 1
    ;;
  403)
    print_error "Error 403: Please provide your public IPv4 to whitelist."
    rm /tmp/delete_response.txt
    exit 1
    ;;
  *)
    print_error "Failed to delete folder. HTTP status: $delete_status"
    echo "Response body: $delete_response_body"
    rm /tmp/delete_response.txt
    exit 1
    ;;
esac

# Create a new folder
print_message "Creating a new folder..."
create_response=$(curl -s -w "%{http_code}" -o /tmp/create_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"folder_name\": \"$folder_name\", \"folder_uuid\": \"$folder_uuid\"}" \
     https://secure-api.services.supra.com/monitoring-supra-create-folder)

# Extract HTTP status code and response body for create request
create_status=$(tail -n1 <<< "$create_response")
create_response_body=$(head -n -1 <<< "$create_response")

if [ "$create_status" -eq 200 ]; then
  print_message "Created new folder successfully."
else
  print_error "Failed to create folder. HTTP status: $create_status"
  echo "Response body: $create_response_body"
  rm /tmp/create_response.txt
  exit 1
fi

# Update the Dashboard for Loki
print_message "Updating Dashboard for Loki..."
file_content=$(curl -sL "https://gist.github.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/ccd84b760a6319209934e87aaebe5bcf5664f47a/node-logs.json")

# Update the JSON content with the desired values
updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/\"uid\": \"\$uuid\"/\"uid\": \"$uuid\"/g; s/job=\$job_name/job=\`$job\`/g; s/{{ folder_uuid }}/$folder_uuid/g")

# Save the updated JSON to a file
echo "$updated_content" > new-dashboard.json

print_message "Dashboard Updated!"

print_message "Creating Dashboard FOR LOKI IN GRAFANA..."
create_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_dashboard_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"data\": $updated_content}" \
     https://secure-api.services.supra.com/monitoring-supra-create-dashboard)

# Extract HTTP status code and response body for dashboard creation
create_dashboard_status=$(tail -n1 <<< "$create_dashboard_response")
create_dashboard_response_body=$(head -n -1 <<< "$create_dashboard_response")

if [ "$create_dashboard_status" -eq 200 ]; then
  print_message "Dashboard creation request sent successfully!"
else
  print_error "Failed to create dashboard. HTTP status: $create_dashboard_status"
  echo "Response body: $create_dashboard_response_body"
  rm /tmp/create_dashboard_response.txt
  rm /tmp/new-dashboard.json
  exit 1
fi


echo "installing telegraf agent"

curl -s https://repos.influxdata.com/influxdata-archive_compat.key > influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
apt-get update && sudo apt-get install telegraf sysstat -y
rm /etc/telegraf/telegraf.conf*
# curl -L  https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/83dd5336c537ae7e6fcfda6ba5aaacc1c575bbdb/telegraf.conf  -o  /etc/telegraf/telegraf.conf

file_content=$(curl -sL "https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/cbf65213b286eccf08fe1aa7e67b4fcb7fbf18d9/telegraf-test.conf") 

updated_content=$(echo "$file_content" | sed "s|{{ supra_location }}|$supra_location|g")

echo "$updated_content" | sudo tee /etc/telegraf/telegraf.conf > /dev/null

curl -L https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/58766426b95347313d30232b1720234089178303/telegraf.service -o /lib/systemd/system/telegraf.service
systemctl daemon-reload
systemctl restart telegraf.service
systemctl enable telegraf.service

sleep 2

# Updating the Dashboard for Telegraf Metrics
print_message "Updating Dashboard for Telegraf Metrics..."
file_content=$(curl -sL "https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/985fa5d9478441f8b62d68891fef695305f4f0c6/telegraf-metrics.json")

# Replace placeholders with actual values
updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$hostname/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ MEM_MAX }}/$MEM_MAX/g; s/{{ DISK_SIZE }}/$DISK_SIZE/g")

# Save the updated JSON to a file
echo "$updated_content" > /tmp/new-telegraf-metrics.json

print_message "Dashboard Updated for Telegraf Metrics!"

print_message "Creating Dashboard for Node Metrics..."
create_telegraf_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_telegraf_dashboard_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"data\": $updated_content}" \
     https://secure-api.services.supra.com/monitoring-supra-create-dashboard)

# Extract HTTP status code and response body for Telegraf dashboard creation
create_telegraf_dashboard_status=$(tail -n1 <<< "$create_telegraf_dashboard_response")
create_telegraf_dashboard_response_body=$(head -n -1 <<< "$create_telegraf_dashboard_response")

# Check if HTTP status code is numeric
if ! [[ "$create_telegraf_dashboard_status" =~ ^[0-9]+$ ]]; then
  print_error "Invalid HTTP status code received: $create_telegraf_dashboard_status"
  echo "Response body: $create_telegraf_dashboard_response_body"
  [ -f /tmp/create_telegraf_dashboard_response.txt ] && rm /tmp/create_telegraf_dashboard_response.txt
  [ -f /tmp/new-telegraf-metrics.json ] && rm /tmp/new-telegraf-metrics.json
  exit 1
fi

# Handle the response based on HTTP status code
if [ "$create_telegraf_dashboard_status" -eq 200 ]; then
  print_message "Telegraf Metrics Dashboard creation request sent successfully!"
else
  print_error "Failed to create Telegraf Metrics Dashboard. HTTP status: $create_telegraf_dashboard_status"
  echo "Response body: $create_telegraf_dashboard_response_body"
  [ -f /tmp/create_telegraf_dashboard_response.txt ] && rm /tmp/create_telegraf_dashboard_response.txt
  [ -f /tmp/new-telegraf-metrics.json ] && rm /tmp/new-telegraf-metrics.json
  exit 1
fi

# Clean up temporary files if they exist
print_message "Cleaning up temporary files..."
for file in /tmp/delete_response.txt /tmp/create_response.txt /tmp/create_dashboard_response.txt /tmp/create_telegraf_dashboard_response.txt /tmp/new-dashboard.json /tmp/new-telegraf-metrics.json; do
  if [ -f "$file" ]; then
    rm "$file"
  fi
done

unset api_key

# Collect email and share details
read -p "Please specify e-mail for dashboard access: " email

share_result=$(echo "{\"email\": \"$email\", \"dashboard\": \"$folder_name\"}")

print_message "Share the following information with the Supra Team to get access to the dashboard:\n$share_result"
print_message "Grafana dashboard URL: https://monitoring.services.supra.com/dashboards/f/$folder_uuid"

exit 0
