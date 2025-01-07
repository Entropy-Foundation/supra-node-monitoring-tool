#!/bin/bash
read -r -p "Please enter the log path: " log_path


# Print the log path to confirm it was saved
echo "The log path you entered is: $log_path"


public_ip=$(curl -s ifconfig.me)


# Create necessary directories
print_message "Creating directories..."
# mkdir -p grafana/provisioning/datasources
# mkdir -p grafana/provisioning/dashboards
# mkdir -p grafana/dashboards
mkdir -p telegraf
# mkdir -p loki
mkdir -p promtail
# mkdir -p influxdb/config


# First ensure all required files exist
print_message "Creating necessary files if they don't exist..."
# touch grafana/provisioning/datasources/datasources.yaml
# touch grafana/provisioning/dashboards/local.yaml
# touch loki/local-config.yaml
touch promtail/config.yaml
touch telegraf/telegraf.conf
# touch influxdb/config/config.yml

# Set proper permissions
print_message "Setting permissions..."
# Set directory permissions
# find grafana promtail loki telegraf influxdb -type d -exec chmod 755 {} \;
find promtail telegraf -type d -exec chmod 755 {} \;

# Set file permissions for configuration files
# find grafana/provisioning -type f -exec chmod 644 {} \;
# chmod 644 loki/local-config.yaml
chmod 644 promtail/config.yaml
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

# cat > loki/local-config.yaml << EOF
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
#       index:
#         prefix: index_
#         period: 24h
# EOF
curl -o telegraf/check_port.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/131f56b49ea294d320b159a379775f7d63b50acb/check_port.sh
chmod +x telegraf/check_port.sh

curl -o telegraf/total_transactions.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/total_transaction_2.sh
chmod +x telegraf/total_transactions.sh

curl -o telegraf/epoch.py https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/epoch.py
chmod +x telegraf/epoch.py

curl -o telegraf/vals_participate.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/vals_count.sh
chmod +x telegraf/vals_participate.sh

curl -o telegraf/block_rate.py https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/block_rate.py
chmod +x telegraf/block_rate.py

curl -o telegraf/vals_count.sh https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/671ecc535adb594d771029d44b6f2d58cd9c9106/vals_participate.sh
chmod +x telegraf/vals_count.sh

curl -o telegraf/sync.py https://gist.githubusercontent.com/skadam-supra/32dd5597728051d367c11615718fbab8/raw/cbfd759658976d40ea12459a3684c0d1dbe6d7fb/sync.py
chmod +x telegraf/sync.py

curl -o telegraf/blocks.py https://gist.githubusercontent.com/skadam-supra/116f04566dd44991b17e7fd760d32e84/raw/e75c13d228fd9aed8311df7667d0d7c1544a7e50/blocks.py
chmod +x telegraf/blocks.py

curl -o telegraf/txn-metrics.py https://gist.githubusercontent.com/skadam-supra/0cd7183523db2482859fbed2dd333ab7/raw/587c127d8aa89d5dd25d3043f26463779acc4915/txn-metrics.py
chmod +x telegraf/txn-metrics.py

curl -o telegraf/consensus_latency.py https://gist.githubusercontent.com/skadam-supra/f4b28c06f0aa16aab5c9c06862c9c1dd/raw/5352a842adad63973fa56006f0fd0c9a09c93f9a/consensus_latency.py
chmod +x telegraf/consensus_latency.py

# curl -o telegraf/mainnet_validator.py https://gist.githubusercontent.com/skadam-supra/21cbb2264ddb3839258a074ab9b25b8f/raw/ef35801bb1cd0cec120e568c69406de42b802765/mainnet_validator.py
# chmod +x telegraf/mainnet_validator.py

curl -o telegraf/mainnet_rpc.sh https://gist.githubusercontent.com/skadam-supra/71f5784e5f40640dc5a207550d524b7c/raw/0efea95a879692070e4ce41dc46dba5e3bc5843a/mainnet_rpc.sh
chmod +x telegraf/mainnet_rpc.sh

# Update Telegraf configuration to send data to InfluxDB
cat > telegraf/telegraf.conf << EOF


[agent]
  interval = "30s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "5s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = "${hostname}"
  debug = true



# Read metrics about cpu usage
[[inputs.cpu]]
  ## Whether to report per-cpu stats or not
  percpu = false
  ## Whether to report total system cpu stats or not
  totalcpu = true
  ## If true, collect raw CPU time metrics
  collect_cpu_time = false
  ## If true, compute and report the sum of all non-idle CPU states
  report_active = false

[[inputs.mem]]

[[inputs.system]]

[[inputs.disk]]
  mount_points = ["/"]
[[inputs.diskio]]
[[inputs.processes]]
# Sysstat metrics collector
# Sysstat metrics collector
# This plugin ONLY supports Linux
[[inputs.sysstat]]
  ## Path to the sadc command.
  #
  ## Common Defaults:
  ##   Debian/Ubuntu: /usr/lib/sysstat/sadc
  ##   Arch:          /usr/lib/sa/sadc
  ##   RHEL/CentOS:   /usr/lib64/sa/sadc
  sadc_path = "/usr/lib/sysstat/sadc" # required

  ## Path to the sadf command, if it is not in PATH
  # sadf_path = "/usr/bin/sadf"

  ## Activities is a list of activities, that are passed as argument to the
  ## sadc collector utility (e.g: DISK, SNMP etc...)
  ## The more activities that are added, the more data is collected.
   activities = ["DISK"]

  ## Group metrics to measurements.
  ##
  ## If group is false each metric will be prefixed with a description
  ## and represents itself a measurement.
  ##
  ## If Group is true, corresponding metrics are grouped to a single measurement.
  # group = true

  ## Options for the sadf command. The values on the left represent the sadf options and
  ## the values on the right their description (which are used for grouping and prefixing metrics).
  ##
  ## Run 'sar -h' or 'man sar' to find out the supported options for your sysstat version.
  [inputs.sysstat.options]
    -C = "cpu"
    -B = "paging"
    -b = "io"
    -d = "disk"             # requires DISK activity
    "-n ALL" = "network"
    "-P ALL" = "per_cpu"
    -q = "queue"
#    -R = "mem"
    -r = "mem_util"
    -S = "swap_util"
    -u = "cpu_util"
    -v = "inode"
    -W = "swap"
    -w = "task"
  # -H = "hugepages"        # only available for newer linux distributions
  # "-I ALL" = "interrupts" # requires INT activity

  ## Device tags can be used to add additional tags for devices. For example the configuration below
  ## adds a tag vg with value rootvg for all metrics with sda devices.
  # [[inputs.sysstat.device_tags.sda]]
  #  vg = "rootvg"
[[inputs.procstat]]
  pattern = ".*"
[[inputs.nstat]]
[[inputs.net]]

# [[inputs.exec]]
#   commands = ["/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/131f56b49ea294d320b159a379775f7d63b50acb/check_port.sh | bash -s 25000 26000'"]
#   timeout = "5s"
#   data_format = "influx"


# [[inputs.exec]]
#   commands = ["sh -c \"docker ps --format '{{.Image}}' | grep 'asia-docker.pkg.dev/supra-devnet-misc/supra-mainnet/rpc-node' | sed 's/.*:\\(.*\\)/\\1/'\""]
#   timeout = "5s"
#   data_format = "value"
#   data_type = "string"
#   name_override = "supra_version"

[[inputs.exec]]
  commands = ["/etc/telegraf/check_port.sh 25000 26000"]
  timeout = "5s"
  data_format = "influx"

[[inputs.exec]]
  commands = ["/etc/telegraf/total_transactions.sh"]
  timeout = "600s"
  data_format = "influx"
  name_override = "total_transactions" 
  interval = "300s"

# Epoch Metrics
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/epoch.py"]
  timeout = "600s"
  data_format = "influx"
  name_override = "epoch_metrics" 
  interval = "300s"

# Validators Participation Count
[[inputs.exec]]
  commands = ["/etc/telegraf/vals_participate.sh"]
  timeout = "600s"
  data_format = "value"
  data_type ="string"
  name_override = "count_vals"
  interval = "300s"

# Block Rate
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/block_rate.py"]
  timeout = "15s"
  data_format = "influx"
  name_override = "block_rate"

# Validators Count
[[inputs.exec]]
  commands = ["/etc/telegraf/vals_count.sh"]
  timeout = "600s"
  data_format = "value"
  data_type = "integer"
  name_override = "vals_participated" 
  interval = "300s"

# Sync Status
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/sync.py"]
  data_format = "influx"
  name_override = "sync_status"
  interval = "300s"

# Blocks Values
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/blocks.py"]
  timeout = "15s"
  data_format = "influx"
  name_override = "block_values"

# Transaction Metrics
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/txn-metrics.py"]
  timeout = "15s"
  data_format = "influx"
  name_override = "metrics_txn"

# Consensus Latency
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/consensus_latency.py"]
  timeout = "30s"
  data_format = "influx"
  name_override = "consensus_latency"

# Mainnet Validator
# [[inputs.exec]]
#   commands = ["python3 /etc/telegraf/mainnet_validator.py"]
#   data_format = "influx"
#   name_override = "mainnet_validator"
#   timeout = "60s"

# Mainnet RPC
[[inputs.exec]]
  commands = ["python3 /etc/telegraf/mainnet_rpc.sh"]
  data_format = "influx"
  name_override = "mainnet_rpc"
  timeout = "60s"

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/26c293ea22ab8f98c99b98dcd0a07b7e36bbdd70/total_transactions.sh | bash -s'"
#   timeout = "600s"
#   data_format = "influx"
#  # data_type = "string"
#   name_override = "total_transactions" 
#   interval = "300s"


# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/1d10ed093bc404162f6da21a05d1e248c7b91c39/epoch.py | python3 -'"
#   timeout = "600s"
#   data_format = "influx"
#   name_override = "epoch_metrics" 
#   interval = "300s"

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/26c293ea22ab8f98c99b98dcd0a07b7e36bbdd70/vals_participate.sh | bash -s'"
#   timeout = "600s"
#   data_format = "value"
#   data_type ="string"
#   name_override = "count_vals"
#   interval = "300s"


# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/1d10ed093bc404162f6da21a05d1e248c7b91c39/block_rate.py | python3 -'"
#   timeout = "15s"
#   data_format = "influx"
#   name_override = "block_rate"
 

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/26c293ea22ab8f98c99b98dcd0a07b7e36bbdd70/vals_count.sh | bash -s'"
#   timeout = "600s"
#   data_format = "value"
#   data_type = "integer"
#   name_override = "vals_participated" 
#   interval = "300s"

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Jayanth-Supra/55c12cc843e0741ad89c044a63b3dd6d/raw/9320b3c691303cf7d1c80c2706d5778bf75945c4/sync.py | python3 -'"
#   data_format = "influx"
#   name_override = "sync_status"
#   interval = "300s"

[[inputs.file]]
  files = ["/tmp/geo.json"]
  data_format = "json"                
  json_string_fields = [] 
  name_override = "node_geolocation"      

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/1d10ed093bc404162f6da21a05d1e248c7b91c39/blocks.py | python3 -'"
#   timeout = "15s"
#   data_format = "influx"
#   name_override = "block_values"

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/b917d211917ac8afa2cf9f1d4aa29b0e6f445f98/txn-metrics.py | python3 -'"
#   timeout = "15s"
#   data_format = "influx"
#   name_override = "metrics_txn"

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/1d10ed093bc404162f6da21a05d1e248c7b91c39/consensus_latency.py | python3 -'"
#   timeout = "30s"
#   data_format = "influx"
#   name_override = "consensus_latency"

# # [[inputs.docker]]
# #   endpoint = "unix:///var/run/docker.sock"
# #   # container_names = []
# #   timeout = "5s"
# #   # perdevice = true
# #   total = false

#   [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Jayanth-Supra/3036e2ab2980d2980ace96f0b4cb1d36/raw/0e0737f98869268bde9bba4dd5d74e0845a2a1f3/mainnet_validator.py | python3 -'"
#   data_format = "influx"
#   name_override = "mainnet_validator"
#   # interval = "300s"
#   timeout = "60s"

# [[inputs.exec]]
#   command = "/bin/bash -c 'curl -s https://gist.githubusercontent.com/Jayanth-Supra/33643f09091a27abaa66865580f07d0b/raw/ddad940dcd3b1017cf90c61567d491b263fe1eea/rpc_mainnet.sh | python3 -'"
#   data_format = "influx"
#   name_override = "mainnet_rpc"
#   # interval = "300s"
#   timeout = "60s"


[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "${INFLUXDB_ADMIN_TOKEN}"
  organization = "myorg"
  bucket = "supra-metrics"
  timeout = "30s"

[[outputs.prometheus_client]]
  listen = ":9273"
  metric_version = 2


EOF


cat > promtail/config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

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
  grafana:
    image: grafana/grafana:11.2.2-security-01
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/etc/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/node-logs.json
    networks:
      - monitoring
    restart: unless-stopped

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    volumes:
#      - influxdb-data:/var/lib/influxdb2
      - ./influxdb/config:/etc/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=${INFLUXDB_PASSWORD}
      - DOCKER_INFLUXDB_INIT_ORG=myorg
      - DOCKER_INFLUXDB_INIT_BUCKET=supra-metrics
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${INFLUXDB_ADMIN_TOKEN}
    ports:
      - "8086:8086"  # Added explicit port mapping
    networks:
      - monitoring
    restart: unless-stopped

  loki:
    image: grafana/loki:2.9.2
    container_name: loki    
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki
      - ./loki/local-config.yaml:/etc/loki/local-config.yaml      
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:2.9.2
    container_name: promtail
    volumes:
      - ./promtail/config.yml:/etc/promtail/config.yml
      # - /var/log:/var/log
      - $log_path:/var/log/user_logs/user_logs.log

    command: -config.file=/etc/promtail/config.yml
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
      apt-get install -y sysstat python3 python3-pip jq && pip3 install requests python-dateutil --break-system-packages && curl -s https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/0ee36e564761e803268edfac7487ccc83da84cc8/geo.sh | bash -s > /tmp/geo.json &&
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
# print_message "Setting permissions..."
# chmod -R 644 grafana/provisioning/datasources/* grafana/provisioning/dashboards/* loki/* promtail/* telegraf/* influxdb/config/*
# chmod 755 grafana/provisioning/{datasources,dashboards} grafana loki promtail telegraf influxdb/config

# Start the stack
print_message "Starting the monitoring stack..."
# docker-compose down -v
docker compose up -d

# Wait for services to be healthy
print_message "Waiting for services to start..."
sleep 15

# Check services status
print_message "Checking services status..."
docker compose ps


# Save InfluxDB credentials to a secure file
print_message "Saving InfluxDB credentials to .env.influxdb..."
cat > .env.influxdb << EOF
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=${INFLUXDB_PASSWORD}
INFLUXDB_ADMIN_TOKEN=${INFLUXDB_ADMIN_TOKEN}
EOF
chmod 666 .env.influxdb

print_message "InfluxDB credentials have been saved to .env.influxdb"

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



print_message "Updating Dashboard for Loki..."
file_content=$(curl -sL "https://gist.githubusercontent.com/skadam-supra/a1aa1f037abe8c6e36993a7c7037ddff/raw/7c6d13ff0ed8266125ca8de4368cd9b2bf00a09e/node-logs.json")

# Update the JSON content with the desired values
updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/\"uid\": \"\$uuid\"/\"uid\": \"$uuid\"/g; s/job=\$job_name/job=\`$title\`/g; s/\$folder_uid/$folder_uuid/g; s/\$loki_uid_value/$loki_uid/g")

# Save the updated JSON to a file
echo "$updated_content" > new-dashboard.json

print_message "Dashboard Updated!"  

print_message "Creating Dashboard FOR LOKI IN GRAFANA..."
create_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_dashboard_response.txt -X POST \
    -H "Content-Type: application/json" \
    -d @new-dashboard.json \
    http://admin:admin@localhost:3000/api/dashboards/db)

create_dashboard_status=$(tail -n1 <<< "$create_dashboard_response")
create_dashboard_response_body=$(head -n -1 <<< "$create_dashboard_response")

if [ "$create_dashboard_status" -eq 200 ]; then
  print_message "Dashboard creation request sent successfully!"
else
  print_error "Failed to create dashboard. HTTP status: $create_dashboard_status"
  echo "Response body: $create_dashboard_response_body"
  rm /tmp/create_dashboard_response.txt
  exit 1
fi



print_message "Updating Dashboard for Telegraf Metrics..."
file_content=$(curl -sL "https://gist.githubusercontent.com/skadam-supra/5c73bf4a6896f3696a4e090a3942f71d/raw/0c77e24fe3ded55894b4963799dbc21015bd22bf/telegraf-rpc.json")

# Replace placeholders with actual values
updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$hostname/g; s/\$influxdb_uid/$influxdb_uuid/g; s/\$disk_name/$original_disk_name/g; s/\$loki_uid_value/$loki_uid/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g; s/{{ CPU_MAX }}/$CPU_MAX/g; s/{{ MEM_MAX }}/$MEM_MAX/g; s/{{ DISK_SIZE }}/$DISK_SIZE/g")

# Save the updated JSON to a file
echo "$updated_content" > /tmp/new-telegraf-metrics.json

print_message "Dashboard Updated for Telegraf Metrics!"

print_message "Creating Dashboard for Node Metrics..."

create_telegraf_dashboard_response=$(curl -s -w "%{http_code}" -o /tmp/create_dashboard_response.txt -X POST \
    -H "Content-Type: application/json" \
    -d @/tmp/new-telegraf-metrics.json \
    http://admin:admin@localhost:3000/api/dashboards/db)

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


print_message "Setup complete! You can access Grafana at http://localhost:3000"

print_message "Default credentials:"
print_message "Username: admin"
print_message "Password: admin"