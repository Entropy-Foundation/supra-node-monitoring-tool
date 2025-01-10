#!/bin/bash
read -r -p "Please enter the log path: " log_dir
read -r -p "Please confirm this node is validator-node or rpc-node: " node_name

# Check if API key is set
if [ -z "$api_key" ]; then
    read -p "Enter API key: " api_key
    export api_key=$api_key
fi
# Check the input and set the file URL accordingly
if [ "$node_name" == "validator-node" ]; then
  log_path="$log_dir/supra_node_logs/supra.log"
elif [ "$node_name" == "rpc-node" ]; then
  log_path="$log_dir/rpc_node_logs/rpc_node.log"
else
  echo "Invalid input. Please enter 'validator-node' or 'rpc-node'."
  exit 1
fi
echo "The log path you entered is: $log_path"
public_ip=$(curl -s ifconfig.me)

user=$(whoami)

# Create necessary directories
echo "Creating directories..."
mkdir -p telegraf
mkdir -p promtail


# First ensure 
touch promtail/config.yml
touch telegraf/telegraf.conf

# Set proper permissions
echo "Setting permissions..."
find promtail telegraf -type d -exec chmod 755 {} \;

chmod 644 promtail/config.yml
chmod 644 telegraf/telegraf.conf
chmod 755 promtail
chmod 755 telegraf

# Get system metrics
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

# Check the input and set the file URL accordingly
if [ "$node_name" == "validator-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-vals.conf"
elif [ "$node_name" == "rpc-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-rpc.conf"
else
  echo "Invalid input. Please enter 'validator-node' or 'rpc-node'."
  exit 1
fi
file_content=$(curl -sL "$file_url")

updated_content=$(echo "$file_content" | sed "s|{{ agent_name }}|$job|g; s|{{ LOG_PATH }}|$log_dir|g")

echo "$updated_content" | tee telegraf/telegraf.conf > /dev/null

cat > promtail/config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yml

clients:
  - url: https://loki.services.supra.com/loki/api/v1/push

scrape_configs:
  - job_name: ${job}
    static_configs:
      - targets:
          - localhost
        labels:
          job: ${title}
          __path__: "/var/log/user_logs/user_logs.log"
EOF

# Update docker-compose.yml to include InfluxDB
cat > docker-compose.yml << EOF
version: '3.8'

services:
  promtail:
    image: grafana/promtail:2.9.2
    container_name: promtail
    volumes:
      - ./promtail:/promtail
      - ./promtail/config.yml:/etc/promtail/config.yml:ro
      # - /var/log:/var/log
      - $log_path:/var/log/user_logs/user_logs.log

    command: -config.file=/promtail/config.yml
    networks:
      - monitoring

  telegraf:
    image: telegraf:1.32.2
    container_name: telegraf
    user: root:root
    volumes:
      - ./telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro
      - $log_dir:/$log_dir
      - ./telegraf:/etc/telegraf/
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/rootfs/proc:ro
      - /sys:/rootfs/sys:ro
      - /etc:/rootfs/etc:ro
      - $log_path:/var/log/user_logs/user_logs.log
      
    environment:
      - HOST_PROC=/rootfs/proc
      - HOST_SYS=/rootfs/sys
      - HOST_ETC=/rootfs/etc
    networks:
      - monitoring
    # restart: unless-stopped
    privileged: true
    entrypoint: >
      /bin/sh -c '
      apt-get update &&
      apt-get install -y sysstat python3 python3-pip jq docker.io && pip3 install requests python-dateutil --break-system-packages && curl -s https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/geo.sh | bash -s > /tmp/geo.json &&
      mkdir -p /etc/default &&
      echo "ENABLED=\"true\"" > /etc/default/sysstat &&
      service sysstat start || true &&
      /entrypoint.sh telegraf'

networks:
  monitoring:
    driver: bridge

volumes:
  grafana-data:
  loki-data:
  influxdb-data:
  loki-rules:
  loki-chunks:
EOF

# Start the stack
echo "Starting the monitoring stack..."
# docker-compose down -v
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 15

# Check services status
echo "Checking services status..."
docker compose ps

# Save InfluxDB credentials to a secure file
disk_type_1=$(ls /dev | grep -E '^(sda|nvme0n1)' | head -n 1)
disk_type=$(ls /dev | grep -E '^(sda1|nvme0n1p1)' | head -n 1)
hostname=$(hostname)
CPU_MAX=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
total_mem=$(grep MemTotal /proc/meminfo | awk '{sub(/^[ \t]+/, "", $2); sub(/ kB$/, "", $2); print $2 * 1024}')
total_disk=$(df -B1 / | awk 'NR==2 {print $2}')
uuid=$(uuidgen)
uuid_2=$(uuidgen)
title="Logs-$hostname-$public_ip"
job="$hostname-$public_ip"
folder_uuid=$(uuidgen)
folder_name="$hostname-$public_ip-Dashboard"
metric_name="Metric-$hostname-$public_ip"
export folder_name="$hostname-$public_ip-Dashboard"

echo "Attempting to delete the folder if it exists..."
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
    echo "Folder deleted successfully."
    ;;
  404)
    echo "Folder not found. Proceeding to create a new folder."
    ;;
  400)
    echo "Error 400: Please enter a valid/updated API key."
    rm /tmp/delete_response.txt
    exit 1
    ;;
  401)
    echo "Error 401: Unauthorized access. Please check your API key."
    rm /tmp/delete_response.txt
    exit 1
    ;;
  403)
    echo "Error 403: Please provide your public IPv4 to whitelist."
    rm /tmp/delete_response.txt
    exit 1
    ;;
  *)
    echo "Failed to delete folder. HTTP status: $delete_status"
    echo "Response body: $delete_response_body"
    rm /tmp/delete_response.txt
    exit 1
    ;;
esac

# Create a new folder
echo "Creating a new folder..."
create_response=$(curl -s -w "%{http_code}" -o /tmp/create_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"folder_name\": \"$folder_name\", \"folder_uuid\": \"$folder_uuid\"}" \
     https://secure-api.services.supra.com/monitoring-supra-create-folder)

# Extract HTTP status code and response body for create request
create_status=$(tail -n1 <<< "$create_response")
create_response_body=$(head -n -1 <<< "$create_response")

if [ "$create_status" -eq 200 ]; then
  echo "Created new folder successfully."
else
  echo "Failed to create folder. HTTP status: $create_status"
  echo "Response body: $create_response_body"
  rm /tmp/create_response.txt
  exit 1
fi

# Update the Dashboard for Loki
echo "Updating Dashboard for Loki..."
file_content=$(curl -sL "https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/node-logs.json")

# Update the JSON content with the desired values
updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/\"uid\": \"\$uuid\"/\"uid\": \"$uuid\"/g; s/job=\$job_name/job=\`$job\`/g; s/{{ folder_uuid }}/$folder_uuid/g")

# Save the updated JSON to a file
echo "$updated_content" > new-dashboard.json

echo "Dashboard Updated!"

echo "Creating Dashboard FOR LOKI IN GRAFANA..."
create_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_dashboard_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"data\": $updated_content}" \
     https://secure-api.services.supra.com/monitoring-supra-create-dashboard)

# Extract HTTP status code and response body for dashboard creation
create_dashboard_status=$(tail -n1 <<< "$create_dashboard_response")
create_dashboard_response_body=$(head -n -1 <<< "$create_dashboard_response")

if [ "$create_dashboard_status" -eq 200 ]; then
  echo "Dashboard creation request sent successfully!"
else
  echo "Failed to create dashboard. HTTP status: $create_dashboard_status"
  echo "Response body: $create_dashboard_response_body"
  rm /tmp/create_dashboard_response.txt
  rm new-dashboard.json
  exit 1
fi


# Check the input and set the file URL accordingly
if [ "$node_name" == "validator-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-vals.json"
elif [ "$node_name" == "rpc-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-rpc.json"
else
  echo "Invalid input. Please enter 'validator-node' or 'rpc-node'."
  exit 1
fi
#Download the selected configuration file
file_content=$(curl -sL "$file_url")

# Replace placeholders with actual values
updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$job/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ total_mem }}/$total_mem/g; s/{{ total_disk }}/$total_disk/g; s/{{ disk_type }}/$disk_type/g; s/{{ disk_type_1 }}/$disk_type_1/g")

# Save the updated JSON to a file
echo "$updated_content" > /tmp/new-telegraf-metrics.json

echo "Dashboard Updated for Telegraf Metrics!"

echo "Creating Dashboard for Node Metrics..."
create_telegraf_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_telegraf_dashboard_response.txt -X POST -H "x-api-key: $api_key" \
     -H "Content-Type: application/json" \
     -d "{\"data\": $updated_content}" \
     https://secure-api.services.supra.com/monitoring-supra-create-dashboard)

# Extract HTTP status code and response body for Telegraf dashboard creation
create_telegraf_dashboard_status=$(tail -n1 <<< "$create_telegraf_dashboard_response")
create_telegraf_dashboard_response_body=$(head -n -1 <<< "$create_telegraf_dashboard_response")

# Check if HTTP status code is numeric
if ! [[ "$create_telegraf_dashboard_status" =~ ^[0-9]+$ ]]; then
  echo "Invalid HTTP status code received: $create_telegraf_dashboard_status"
  echo "Response body: $create_telegraf_dashboard_response_body"
  [ -f /tmp/create_telegraf_dashboard_response.txt ] && rm /tmp/create_telegraf_dashboard_response.txt
  [ -f /tmp/new-telegraf-metrics.json ] && rm /tmp/new-telegraf-metrics.json
  exit 1
fi

# Handle the response based on HTTP status code
if [ "$create_telegraf_dashboard_status" -eq 200 ]; then
  echo "Telegraf Metrics Dashboard creation request sent successfully!"
else
  echo "Failed to create Telegraf Metrics Dashboard. HTTP status: $create_telegraf_dashboard_status"
  echo "Response body: $create_telegraf_dashboard_response_body"
  [ -f /tmp/create_telegraf_dashboard_response.txt ] && rm /tmp/create_telegraf_dashboard_response.txt
  [ -f /tmp/new-telegraf-metrics.json ] && rm /tmp/new-telegraf-metrics.json
  exit 1
fi

# Clean up temporary files if they exist
echo "Cleaning up temporary files..."
for file in /tmp/delete_response.txt /tmp/create_response.txt /tmp/create_dashboard_response.txt /tmp/create_telegraf_dashboard_response.txt /tmp/new-dashboard.json /tmp/new-telegraf-metrics.json; do
  if [ -f "$file" ]; then
    rm "$file"
  fi
done

unset api_key

# Collect email and share details
read -p "Please specify e-mail for dashboard access: " email

share_result=$(echo "{\"email\": \"$email\", \"dashboard\": \"$folder_name\"}")

echo "Share the following information with the Supra Team to get access to the dashboard:\n$share_result"
echo "Grafana dashboard URL: https://monitoring.services.supra.com/dashboards/f/$folder_uuid"

exit 0