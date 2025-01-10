#!/bin/bash
read -r -p "Please enter the log path: " log_dir

# # Print the log path to confirm it was saved
# echo "The log path you entered is: $log_dir"

read -r -p "Please confirm this node is validator-node or rpc-node: " node_name

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


# Create necessary directories
echo "Creating directories..."
# mkdir -p grafana/provisioning/datasources
# mkdir -p grafana/provisioning/dashboards
# mkdir -p grafana/dashboards
mkdir -p telegraf
# mkdir -p loki
mkdir -p promtail
# mkdir -p influxdb/config


# First ensure all required files exist
echo "Creating necessary files if they don't exist..."
# touch grafana/provisioning/datasources/datasources.yaml
# touch grafana/provisioning/dashboards/local.yaml
# touch loki/local-config.yml
touch promtail/config.yml
touch telegraf/telegraf.conf
# touch influxdb/config/config.yml

# Set proper permissions
echo "Setting permissions..."
# Set directory permissions
# find grafana promtail loki telegraf influxdb -type d -exec chmod 755 {} \;
find promtail telegraf -type d -exec chmod 755 {} \;

# Set file permissions for configuration files
# find grafana/provisioning -type f -exec chmod 644 {} \;
# chmod 644 loki/local-config.yml
chmod 644 promtail/config.yml
chmod 644 telegraf/telegraf.conf
# chmod 644 influxdb/config/config.yml

# Ensure parent directories are accessible
# chmod 755 grafana/provisioning
# chmod 755 grafana/provisioning/datasources
# chmod 755 grafana/provisioning/dashboards
# chmod 755 loki
chmod 755 promtail
chmod 755 telegraf
# chmod 755 influxdb/config


# Ensure directories are created before proceeding
# if [ ! -d "grafana/dashboards" ]; then
#     print_error "Failed to create directories"
#     exit 1
# fi

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

# Generate secure random passwords
# INFLUXDB_PASSWORD=$(openssl rand -base64 32)
# INFLUXDB_ADMIN_TOKEN=$(openssl rand -hex 32)


# echo "INFLUXDB_PASSWORD is $INFLUXDB_PASSWORD"


# Create InfluxDB configuration
# cat > influxdb/config/config.yml << EOF
# bolt-path: /var/lib/influxdb2/influxdb.bolt
# engine-path: /var/lib/influxdb2/engine
# http-bind-address: :8086
# EOF

# Update Grafana datasources configuration to include InfluxDB
# cat > grafana/provisioning/datasources/datasources.yaml << EOF
# apiVersion: 1

# datasources:
#   - name: Loki
#     type: loki
#     access: proxy
#     url: http://loki:3100
#     isDefault: true
#     editable: false

#   - name: InfluxDB
#     type: influxdb
#     access: proxy
#     url: http://influxdb:8086
#     secureJsonData:
#       token: ${INFLUXDB_ADMIN_TOKEN}
#     jsonData:
#       version: Flux
#       organization: myorg
#       defaultBucket: supra-metrics
#       tlsSkipVerify: true
#     isDefault: false
#     editable: false

# EOF

# cat > loki/local-config.yml << EOF
# auth_enabled: false

# server:
#   http_listen_port: 3100
#   http_listen_address: 0.0.0.0

# common:
#   path_prefix: /etc/loki
#   storage:
#     filesystem:
#       chunks_directory: /etc/loki/chunks
#       rules_directory: /etc/loki/rules
#   replication_factor: 1
#   ring:
#     instance_addr: 0.0.0.0
#     kvstore:
#       store: inmemory

# schema_config:
#   configs:
#     - from: 2020-05-15
#       store: boltdb-shipper
#       object_store: filesystem
#       schema: v11
#       index:  # grafana:
  #   image: grafana/grafana:11.2.2-security-01
  #   container_name: grafana
  #   ports:
  #     - "3000:3000"
  #   volumes:
  #     - grafana-data:/var/lib/grafana
  #     - ./grafana/provisioning:/etc/grafana/provisioning
  #     - ./grafana/dashboards:/etc/grafana/dashboards
  #   environment:
  #     - GF_SECURITY_ADMIN_USER=admin
  #     - GF_SECURITY_ADMIN_PASSWORD=admin
  #     - GF_USERS_ALLOW_SIGN_UP=false
  #     - GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/node-logs.json
  #   networks:
  #     - monitoring
  #   restart: unless-stopped
#         prefix: index_
#         period: 24h
# EOF
# curl -o telegraf/check_port.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/131f56b49ea294d320b159a379775f7d63b50acb/check_port.sh
# chmod +x telegraf/check_port.sh

# curl -o telegraf/total_transactions.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/total_transaction_2.sh
# chmod +x telegraf/total_transactions.sh

# curl -o telegraf/epoch.py https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/epoch.py
# chmod +x telegraf/epoch.py

# curl -o telegraf/vals_participate.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/vals_count.sh
# chmod +x telegraf/vals_participate.sh

# curl -o telegraf/block_rate.py https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/block_rate.py
# chmod +x telegraf/block_rate.py

# curl -o telegraf/vals_count.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/vals_participate.sh
# chmod +x telegraf/vals_count.sh

# curl -o telegraf/sync.py https://gist.githubusercontent.com/skadam-supra/32dd5597728051d367c11615718fbab8/raw/cbfd759658976d40ea12459a3684c0d1dbe6d7fb/sync.py
# chmod +x telegraf/sync.py

# curl -o telegraf/blocks.py https://gist.githubusercontent.com/skadam-supra/116f04566dd44991b17e7fd760d32e84/raw/e75c13d228fd9aed8311df7667d0d7c1544a7e50/blocks.py
# chmod +x telegraf/blocks.py

# curl -o telegraf/txn-metrics.py https://gist.githubusercontent.com/skadam-supra/0cd7183523db2482859fbed2dd333ab7/raw/587c127d8aa89d5dd25d3043f26463779acc4915/txn-metrics.py
# chmod +x telegraf/txn-metrics.py

# curl -o telegraf/consensus_latency.py https://gist.githubusercontent.com/skadam-supra/f4b28c06f0aa16aab5c9c06862c9c1dd/raw/5352a842adad63973fa56006f0fd0c9a09c93f9a/consensus_latency.py
# chmod +x telegraf/consensus_latency.py

# # curl -o telegraf/mainnet_validator.py https://gist.githubusercontent.com/skadam-supra/21cbb2264ddb3839258a074ab9b25b8f/raw/ef35801bb1cd0cec120e568c69406de42b802765/mainnet_validator.py
# # chmod +x telegraf/mainnet_validator.py

# curl -o telegraf/mainnet_rpc.sh https://gist.githubusercontent.com/skadam-supra/71f5784e5f40640dc5a207550d524b7c/raw/0efea95a879692070e4ce41dc46dba5e3bc5843a/mainnet_rpc.sh
# chmod +x telegraf/mainnet_rpc.sh

# # Update Telegraf configuration to send data to InfluxDB
# cat > telegraf/telegraf.conf << EOF
# EOF
# Check the input and set the file URL accordingly
if [ "$node_name" == "validator-node" ]; then
  file_url="https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/1bfff68f9b9a3a7065375ee8dce92fba72e5245f/telegraf-vals.conf"
elif [ "$node_name" == "rpc-node" ]; then
  file_url="https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/1bfff68f9b9a3a7065375ee8dce92fba72e5245f/telegraf-rpc.conf"
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
  # grafana:
  #   image: grafana/grafana:11.2.2-security-01
  #   container_name: grafana
  #   ports:
  #     - "3000:3000"
  #   volumes:
  #     - grafana-data:/var/lib/grafana
  #     - ./grafana/provisioning:/etc/grafana/provisioning
  #     - ./grafana/dashboards:/etc/grafana/dashboards
  #   environment:
  #     - GF_SECURITY_ADMIN_USER=admin
  #     - GF_SECURITY_ADMIN_PASSWORD=admin
  #     - GF_USERS_ALLOW_SIGN_UP=false
  #     - GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/node-logs.json
  #   networks:
  #     - monitoring
  #   restart: unless-stopped

#   influxdb:
#     image: influxdb:2.7
#     container_name: influxdb
#     volumes:
# #      - influxdb-data:/var/lib/influxdb2
#       - ./influxdb/config:/etc/influxdb2
#     environment:
#       - DOCKER_INFLUXDB_INIT_MODE=setup
#       - DOCKER_INFLUXDB_INIT_USERNAME=admin
#       - DOCKER_INFLUXDB_INIT_PASSWORD=${INFLUXDB_PASSWORD}
#       - DOCKER_INFLUXDB_INIT_ORG=myorg
#       - DOCKER_INFLUXDB_INIT_BUCKET=supra-metrics
#       - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${INFLUXDB_ADMIN_TOKEN}
#     ports:
#       - "8086:8086"  # Added explicit port mapping
#     networks:
#       - monitoring
#     restart: unless-stopped

  # loki:
  #   image: grafana/loki:2.9.2
  #   container_name: loki    
  #   ports:
  #     - "3100:3100"
  #   volumes:
  #     - loki-data:/loki
  #     - ./loki/local-config.yml:/etc/loki/local-config.yml      
  #   command: -config.file=/etc/loki/local-config.yml
  #   networks:
  #     - monitoring

  promtail:
    image: grafana/promtail:2.9.2
    container_name: promtail
    volumes:
      - ./promtail:/promtail
      # - /var/log:/var/log
      - $log_path:/var/log/user_logs/user_logs.log

    command: -config.file=/promtail/config.yml
    networks:
      - monitoring

  telegraf: 
    image: telegraf:1.32.2
    container_name: telegraf
    user: root:root  # Add this line to run as root
    volumes:
      - ./telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro
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
      apt-get install -y sysstat python3 python3-pip jq && pip3 install requests python-dateutil --break-system-packages && curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/0ee36e564761e803268edfac7487ccc83da84cc8/geo.sh | bash -s ${log_path} > /tmp/geo.json &&
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

# Set proper permissions
# echo "Setting permissions..."
# chmod -R 644 grafana/provisioning/datasources/* grafana/provisioning/dashboards/* loki/* promtail/* telegraf/* influxdb/config/*
# chmod 755 grafana/provisioning/{datasources,dashboards} grafana loki promtail telegraf influxdb/config

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
echo "Saving InfluxDB credentials to .env.influxdb..."
cat > .env.influxdb << EOF
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=${INFLUXDB_PASSWORD}
INFLUXDB_ADMIN_TOKEN=${INFLUXDB_ADMIN_TOKEN}
EOF
chmod 666 .env.influxdb

echo "InfluxDB credentials have been saved to .env.influxdb"

response=$(curl -s http://admin:admin@localhost:3000/api/datasources)

# Use jq to extract UIDs for InfluxDB and Loki
influxdb_uuid=$(echo "$response" | jq -r '.[] | select(.name=="InfluxDB") | .uid')
loki_uid=$(echo "$response" | jq -r '.[] | select(.name=="Loki") | .uid')
original_disk_name=$(lsblk -no NAME | grep -E '^(sd[a-z]|nvme[0-9]n[0-9])$')
# Print the UIDs
# echo "InfluxDB UID: $influxdb_uuid"
# echo "Loki UID: $loki_uid"


folder_uuid=$(uuidgen)
# echo "$folder_uuid"
# Define the folder name
folder_name="Monitoring"

# Print a message
# echo "Creating folder with name: $folder_name and UID: $folder_uuid..."

# Create the folder in Grafana
create_folder_response=$(curl -s -w "%{http_code}" -o /tmp/create_folder_response.txt -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"uid\": \"$folder_uuid\",
      \"title\": \"$folder_name\"
    }" \
    http://admin:admin@localhost:3000/api/folders)

# Check the response
create_folder_status=$(tail -n1 <<< "$create_folder_response")
create_folder_response_body=$(head -n -1 <<< "$create_folder_response")

if [ "$create_folder_status" -eq 200 ]; then
    echo "Folder '$folder_name' created successfully!"
else
    echo "ERROR: Failed to create folder. HTTP status: $create_folder_status"
    echo "Response body: $create_folder_response_body"
    exit 1
fi



echo "Updating Dashboard for Loki..."

# Check the input and set the file URL accordingly
if [ "$node_name" == "validator-node" ]; then
  file_url="https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/5a05241715569abc5a5dbf427fef25ef7dda8bb3/telegraf-vals.json"
elif [ "$node_name" == "rpc-node" ]; then
  file_url="https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/5a05241715569abc5a5dbf427fef25ef7dda8bb3/telegraf-rpc.json"
else
  echo "Invalid input. Please enter 'validator-node' or 'rpc-node'."
  exit 1
fi

# Download the selected configuration file
file_content=$(curl -sL "$file_url")

# Replace placeholders with actual values
updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$job/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ total_mem }}/$total_mem/g; s/{{ total_disk }}/$total_disk/g")

# Save the updated JSON to a file
echo "$updated_content" > new-dashboard.json

echo "Dashboard Updated!"  

echo "Creating Dashboard FOR LOKI IN GRAFANA..."
create_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_dashboard_response.txt -X POST \
    -H "Content-Type: application/json" \
    -d @new-dashboard.json \
    http://admin:admin@localhost:3000/api/dashboards/db)

create_dashboard_status=$(tail -n1 <<< "$create_dashboard_response")
create_dashboard_response_body=$(head -n -1 <<< "$create_dashboard_response")

if [ "$create_dashboard_status" -eq 200 ]; then
  echo "Dashboard creation request sent successfully!"
else
  print_error "Failed to create dashboard. HTTP status: $create_dashboard_status"
  echo "Response body: $create_dashboard_response_body"
  rm /tmp/create_dashboard_response.txt
  exit 1
fi



# echo "Updating Dashboard for Telegraf Metrics..."
# file_content=$(curl -sL "https://gist.githubusercontent.com/skadam-supra/5c73bf4a6896f3696a4e090a3942f71d/raw/0c77e24fe3ded55894b4963799dbc21015bd22bf/telegraf-rpc.json")

# # Replace placeholders with actual values
# updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$hostname/g; s/\$influxdb_uid/$influxdb_uuid/g; s/\$disk_name/$original_disk_name/g; s/\$loki_uid_value/$loki_uid/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ MEM_MAX }}/$MEM_MAX/g; s/{{ DISK_SIZE }}/$DISK_SIZE/g")

# # Save the updated JSON to a file
# echo "$updated_content" > /tmp/new-telegraf-metrics.json

# echo "Dashboard Updated for Telegraf Metrics!"

# echo "Creating Dashboard for Node Metrics..."

# create_telegraf_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_dashboard_response.txt -X POST \
#     -H "Content-Type: application/json" \
#     -d @/tmp/new-telegraf-metrics.json \
#     http://admin:admin@localhost:3000/api/dashboards/db)

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
  echo "Telegraf Metrics Dashboard creation request sent successfully!"
else
  print_error "Failed to create Telegraf Metrics Dashboard. HTTP status: $create_telegraf_dashboard_status"
  echo "Response body: $create_telegraf_dashboard_response_body"
  [ -f /tmp/create_telegraf_dashboard_response.txt ] && rm /tmp/create_telegraf_dashboard_response.txt
  [ -f /tmp/new-telegraf-metrics.json ] && rm /tmp/new-telegraf-metrics.json
  exit 1
fi


echo "Setup complete! You can access Grafana at http://localhost:3000"

echo "Default credentials:"
echo "Username: admin"
echo "Password: admin"