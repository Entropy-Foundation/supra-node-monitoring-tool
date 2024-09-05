#!/bin/bash

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
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

# Get public IP address
public_ip=$(curl -s ifconfig.me)
read -p "Please enter the Public IPV4 address of the server: " public_ip

# Confirm the provided log path
echo "You entered: $public_ip"
read -p "Is this correct? (y/n) " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo "Public IPV4 address confirmed: $public_ip"
else
    echo "Public IPV4 address not confirmed. Please try again."
    exit 1
fi

# Get hostname
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
echo "Job name is, $job"

echo "Title name is $title"

# Ask the user for the log file path
read -p "Please enter the log file path: " log_path

# Confirm the provided log path
echo "You entered: $log_path"
read -p "Is this correct? (y/n) " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo "Log file path confirmed: $log_path"
else
    echo "Log file path not confirmed. Please try again."
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


### Checking for the old dashboard and remove it if exist####

echo "Deleting the Folder if exists"

curl -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{
            \"folder_name\": \"$folder_name\"
         }" \
     https://secure-api.services.supra.com/monitoring-supra-delete-folder

# Create a new Folder
echo "Creating new folder"

echo "Folder Name: $folder_name"

curl -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{
            \"folder_name\": \"$folder_name\",
            \"folder_uuid\": \"$folder_uuid\"
         }" \
     https://secure-api.services.supra.com/monitoring-supra-create-folder

echo "Created new folder"


echo "Updating Dashboard for Loki!"
file_content=$(curl -sL "https://gist.github.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/ccd84b760a6319209934e87aaebe5bcf5664f47a/node-logs.json")

# Update the JSON content with the desired values
updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/\"uid\": \"\$uuid\"/\"uid\": \"$uuid\"/g; s/job=\$job_name/job=\`$job\`/g; s/{{ folder_uuid }}/$folder_uuid/g")

# Save the updated JSON to a file
echo "$updated_content" > new-dashboard.json

echo "Dashboard Updated!"

echo "Creating Dashboard FOR LOKI IN GRAFANA"


curl -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"data\": $updated_content}" \
     https://secure-api.services.supra.com/monitoring-supra-create-dashboard


echo "Dashboard creation request sent!"


rm -rf new-dashboard.json 

sleep 2

echo "installing telegraf agent"

curl -s https://repos.influxdata.com/influxdata-archive_compat.key > influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
apt-get update && sudo apt-get install telegraf sysstat -y
rm /etc/telegraf/telegraf.conf*
curl -L  https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/83dd5336c537ae7e6fcfda6ba5aaacc1c575bbdb/telegraf.conf  -o  /etc/telegraf/telegraf.conf

curl -L https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/58766426b95347313d30232b1720234089178303/telegraf.service -o /lib/systemd/system/telegraf.service
systemctl daemon-reload
systemctl restart telegraf.service
systemctl enable telegraf.service

echo "Updating Dashboard"
sleep 2

# Fetch the template file
file_content=$(curl -sL "https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/985fa5d9478441f8b62d68891fef695305f4f0c6/telegraf-metrics.json")

# Replace placeholders with actual values
updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$hostname/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ MEM_MAX }}/$MEM_MAX/g; s/{{ DISK_SIZE }}/$DISK_SIZE/g")
echo "$updated_content" > new-telegraf-metrics.json

echo "Dashboard Updated!"

echo "Creating Dashboard for Node Metrics"

# Post the updated dashboard to the cloud function

curl -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"data\": $updated_content}" \
     https://secure-api.services.supra.com/monitoring-supra-create-dashboard


rm new-telegraf-metrics.json
unset api_key

read -p "Please specify e-mail for dashboard access: " email

share_result=$(echo {email: $email, dashboard: $folder_name})

echo  "Share the following information with Supra Team to get access to the dashboard:\n$share_result"

echo "Grafana dashboard url:  https://monitoring.services.supra.com/dashboards/f/$folder_uuid"
