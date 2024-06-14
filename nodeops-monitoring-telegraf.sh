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
public_ip=$(curl ifconfig.me)

# Get hostname
hostname=$(hostname)

CPU_MAX=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

MEM_MAX=$(grep MemTotal /proc/meminfo | awk '{sub(/^[ \t]+/, "", $2); sub(/ kB$/, "", $2); print $2 * 1024}')

DISK_SIZE=$(df -B1 / | awk 'NR==2 {print $2}')

uuid=$(uuidgen)
uuid_2=$(uuidgen)
title="Logs-$hostname-$public_ip"
job=$hostname
folder_uuid=$(uuidgen)
folder_name="$hostname-$public_ip-Dashboard"
metric_name="Metric-$hostname-$public_ip"
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
          job: $hostname
          __path__: "$log_path"
EOF


# Set permissions for the promtail.yml file
chmod 0644 /etc/promtail/config.yml

service promtail restart



curl -X POST \
  'https://monitoring.services.supra.com/api/folders' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer glsa_RL9Ld2zAHE2aM5MUwGjOWoMmRAgxprHP_91dd26c9' \
  -d "{ \"title\": \"$folder_name\", \"uid\": \"$folder_uuid\" }"

echo "Updating Dashboard!"
# file_content=$(<dashboard.json)
file_content=$(curl -sL "https://gist.github.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/ccd84b760a6319209934e87aaebe5bcf5664f47a/node-logs.json")

# Use sed to substitute the values in the JSON structure
# updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/\"uid\": \"\$uuid\"/\"uid\": \"$uuid\"/g")


updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/\"uid\": \"\$uuid\"/\"uid\": \"$uuid\"/g; s/job=\$job_name/job=\`$job\`/g; s/{{ folder_uuid }}/$folder_uuid/g")


# Write the updated content back to the file
echo "$updated_content" > new-dashboard.json

echo "Dashboard Updated!"

echo "Creating Dashboard"

curl -X POST   https://monitoring.services.supra.com/api/dashboards/db   -H 'Authorization: Bearer glsa_RL9Ld2zAHE2aM5MUwGjOWoMmRAgxprHP_91dd26c9'  -H 'Content-Type: application/json'   -d @new-dashboard.json 

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

echo "updating dashboard"
sleep 2

file_content=$(curl -sL "https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/5a5b11aae2d47636e2c8ca63c25f6ca8f3cce16a/telegraf-metrics.json")


updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$hostname/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ MEM_MAX }}/$MEM_MAX/g; s/{{ DISK_SIZE }}/$DISK_SIZE/g")
# Write the updated content back to the file
echo "$updated_content" > new-telegraf-metrics.json

# sed "s/{{ job_name }}/$job/g"  


echo "Dashboard Updated!"

echo "Creating Dashboard"

curl -X POST   https://monitoring.services.supra.com/api/dashboards/db   -H 'Authorization: Bearer glsa_RL9Ld2zAHE2aM5MUwGjOWoMmRAgxprHP_91dd26c9'  -H 'Content-Type: application/json'   -d @new-telegraf-metrics.json

rm new-telegraf-metrics.json


read -p "Please specify e-mail for dashboard access: " email

share_result=$(echo {email: $email, dashboard: $folder_name})

echo  "Share the following information with Supra Team to get access to the dashboard:\n$share_result"

echo "Grafana dashboard url:  https://monitoring.services.supra.com/dashboards/f/$folder_uuid"
