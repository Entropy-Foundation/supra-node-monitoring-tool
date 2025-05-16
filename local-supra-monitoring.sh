#!/bin/bash

echo "The script assume, you already run the supra team monitoring \
script to send the logs to the Supra Team. If you haven't done that, \
please run their script first"

read -r -p "Have you already run the Supra Team monitoring script? (yes/no): " response
if [[ "$response" != "yes" ]]; then
  echo "Please run the Supra Team monitoring script first before proceeding."
  exit 1
fi

if [ -f .env.local ]; then
  echo "Sourcing .env.local file..."
  source .env.local
else
  echo ".env.local file not found. Using default InfluxDB API key."
  local_influxdb_api_key="myinfluxdbapikey"
fi

read -r -p "Please confirm this node is validator-node or rpc-node: " node_type

if [[ "$node_type" != "validator-node" && "$node_type" != "rpc-node" ]]; then
  echo "Invalid input. Please enter 'validator-node' or 'rpc-node'."
  exit 1
fi

# define the log path based on the node type
read -r -p "Please enter the ${node_type} (full path) to the supra config folder: " cfg_dir
if [ "$node_type" == "validator-node" ]; then
  log_path="$cfg_dir/supra_node_logs/supra.log"
  echo "The ${node_type} log path is: $log_path"
else [ "$node_type" == "rpc-node" ];
  log_path="$cfg_dir/rpc_node_logs/rpc_node.log"
  echo "The ${node_type} log path is: $log_path"
fi

# define vars for all dashboards
public_ip=$(curl -s -4 ifconfig.me)
echo "The public IPv4 address of this server is: $public_ip"
hostname=$(hostname)
job="$hostname-$public_ip" # job name used by influxDB, telegraf and grafana alert rules
title="Logs-$hostname-$public_ip" # title for log dashboard
metric_name="Metric-$hostname-$public_ip" # title for telegraf dashboard

total_mem=$(grep MemTotal /proc/meminfo | awk '{sub(/^[ \t]+/, "", $2); sub(/ kB$/, "", $2); print $2 * 1024}')
total_disk=$(df -B1 / | awk 'NR==2 {print $2}')
disk_type_1=$(ls /dev | grep -E '^(sda|nvme0n1)' | head -n 1)
disk_type=$(ls /dev | grep -E '^(sda1|nvme0n1p1)' | head -n 1)

# Download telegraf configuration file
if [ "$node_type" == "validator-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-vals.conf"
elif [ "$node_type" == "rpc-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-rpc.conf"
else
  echo "Invalid input. Please enter 'validator-node' or 'rpc-node'."
  exit 1
fi
file_content=$(curl -sL "$file_url")
updated_content=$(echo "$file_content" | sed "s|{{ agent_name }}|$job|g; s|{{ LOG_PATH }}|$cfg_dir|g")

# Define InfluxDB output configuration for local usage
influxdb_output="

[[outputs.influxdb_v2]]
  urls = [\"http://supra-influxdb:8086\"]
  token = \"$local_influxdb_api_key\"
  timeout = \"15s\"
  organization = \"Entropy Foundation\"
  bucket = \"supra-metrics\"
"
# Append the InfluxDB output telegraf configuration to the existing content
updated_content="${updated_content}${influxdb_output}"

# backup original telegraf config
if [ -f telegraf/telegraf.conf ]; then
  cp telegraf/telegraf.conf telegraf/telegraf.conf.bak
  echo "Backup of original telegraf configuration created as telegraf/telegraf.conf.bak"
else
  echo "No existing telegraf configuration found to back up."
fi

# overwrite the telegraf config
echo "$updated_content" | tee telegraf/telegraf.conf > /dev/null


# backup original promtail config
if [ -f promtail/config.yml ]; then
  cp promtail/config.yml promtail/config.yml.bak
  echo "Backup of original promtail configuration created as promtail/config.yml.bak"
else
  echo "No existing promtail configuration found to back up."
fi

# overwrite the promtail config
cat > promtail/config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yml

clients:
  - url: http://loki:3100/loki/api/v1/push
    batchsize: 10000
    batchwait: 60s
  - url: https://loki.services.supra.com/loki/api/v1/push
    batchsize: 10000
    batchwait: 60s

scrape_configs:
  - job_name: ${title}
    static_configs:
      - targets:
          - localhost
        labels:
          job: ${job}
          __path__: "/var/log/user_logs/user_logs.log"
EOF

# backup original docker-compose file
if [ -f docker-compose.yml ]; then
  cp docker-compose.yml docker-compose.yml.bak
  echo "Backup of original docker-compose file created as docker-compose.yml.bak"
else
  echo "No existing docker-compose.yml configuration found to back up."
fi

# Generate updated docker compose file
cat > docker-compose.yml << EOF
services:
  promtail:
    image: grafana/promtail:3.5.0
    container_name: supra-central-promtail
    volumes:
      - ./promtail:/promtail
      - ./promtail/config.yml:/etc/promtail/config.yml
      # - /var/log:/var/log
      - $log_path:/var/log/user_logs/user_logs.log
    command: -config.file=/promtail/config.yml
    networks:
      - monitoring
    depends_on:
      - loki

  telegraf:
    image: telegraf:1.32.2
    container_name: supra-central-telegraf
    user: root:root
    volumes:
      - ./telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro
      - $cfg_dir:/$cfg_dir
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

  influxdb:
    image: influxdb:2.7
    container_name: supra-influxdb
    ports:
      - "8086:8086"
    volumes:
      - influxdb-data:/var/lib/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=supra
      - DOCKER_INFLUXDB_INIT_PASSWORD=suprasupra
      - DOCKER_INFLUXDB_INIT_ORG=Entropy Foundation
      - DOCKER_INFLUXDB_INIT_BUCKET=supra-metrics
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$local_influxdb_api_key
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: supra-grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana-provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    networks:
      - monitoring
    depends_on:
      - influxdb

  loki:
    container_name: loki
    image: grafana/loki:3.5.0
    ports:
      - 3100:3100
    networks:
      - monitoring
    volumes:
      - loki-data:/mnt/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: always

networks:
  monitoring:
    driver: bridge

volumes:
  grafana-data:
  influxdb-data:
  loki-data:

EOF

# Prep the grafana provisioning datasource config
mkdir -p grafana-provisioning/datasources
# Generate updated influxDB datasource config
cat > grafana-provisioning/datasources/influxDB.yaml << EOF
apiVersion: 1
datasources:
  - name: InfluxDB
    uid: edhfdvk2zkb28f
    type: influxdb
    url: http://supra-influxdb:8086
    access: proxy
    orgId: 1
    isDefault: true
    version: 1
    editable: false
    jsonData:
      version: Flux
      organization: Entropy Foundation
      defaultBucket: supra-metrics
      timeInterval: "15s"
    secureJsonData:
      token: $local_influxdb_api_key
EOF

# Generate updated loki datasource config
cat > grafana-provisioning/datasources/loki.yaml << EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    uid: c69b28f5-dda7-40bf-b513-85d1c1670511
    url: http://loki:3100
    jsonData:
      maxLines: 1000
EOF

# Prep the grafana provisioning dashboards config
mkdir -p grafana-provisioning/dashboards

# create the default provider dashboard.yaml
cat > grafana-provisioning/dashboards/dashboard.yaml << EOF
apiVersion: 1

providers:
  # <string> an unique provider name
  - name: 'Supra'
    # <int> org id. will default to orgId 1 if not specified
    orgId: 1
    # <string, required> name of the dashboard folder. Required
    folder: ''
    # <string> folder UID. will be automatically generated if not specified
    folderUid: ''
    # <string, required> provider type. Required
    type: file
    # <bool> disable dashboard deletion
    disableDeletion: false
    # <bool> enable dashboard editing
    editable: true
    # <int> how often Grafana will scan for changed dashboards
    updateIntervalSeconds: 10
    # <bool> allow updating provisioned dashboards from the UI
    allowUiUpdates: true
    options:
      # <string, required> path to dashboard files on disk. Required
      path: /etc/grafana/provisioning/dashboards
      # <bool> use folder names from filesystem to create folders in Grafana
      foldersFromFilesStructure: true
EOF

# Update the Dashboard for Loki log dashboard
echo "Updating Dashboard for Loki..."
file_content=$(curl -sL "https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/node-logs.json")

# remove "uid": "$uuid",
# Update the JSON content with the desired values
updated_content=$(echo "$file_content" | sed "s/\"title\": \"\$title\"/\"title\": \"$title\"/g; s/job=\$job_name/job=\`$job\`/g;")

# remove  "folderUid": "{{ folder_uuid }}", from the dashboard as not required in the local setup
updated_content=${updated_content//'"folderUid": "{{ folder_uuid }}",'/}

# remove "uid": "$uuid", from the dashboard as not required in the local setup
updated_content=${updated_content//'"uid": "$uuid",'/}

# Save the updated JSON to a file
echo "$updated_content" | jq .dashboard > grafana-provisioning/dashboards/supra-logs.json

echo "Loki logs Dashboard Updated!"

# update grafana provisioning alerting configs
mkdir -p grafana-provisioning/alerting

if [[ -n "$pdkey" ]]; then
  setup_grafana_contact=true
else
  setup_grafana_contact=false
fi

if [[ "$setup_grafana_contact" == true ]]; then
  # Create pagerduty contact point
  cat > grafana-provisioning/alerting/pagerduty.yaml << EOF
apiVersion: 1
contactPoints:
    - orgId: 1
      name: Pagerduty
      receivers:
        - uid: first_contact_uid
          type: pagerduty
          settings:
            integrationKey: $pdkey
          disableResolveMessage: false
EOF
fi

file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/grafana-provisioning/alerting/node-stuck.yaml.j2"
# download node-stuck alert config file
file_content=$(curl -sL "$file_url")
# temp only for local testing
#file_content=$(cat grafana-provisioning/alerting/node-stuck.yaml.j2)
# update the query
updated_content=${file_content//'{{ node_name }}'/$job}

if [[ "$setup_grafana_contact" == false ]]; then
  # remove notification_settings receiver: Pagerduty
  updated_content=${updated_content//'receiver: Pagerduty'/}
fi

echo "$updated_content" > grafana-provisioning/alerting/node-stuck.yaml

# Creating telegraf dashboard
echo "Creating Dashboard for Telegraf Metrics..."

# Download the telegraf grafana dashboard
if [ "$node_type" == "validator-node" ]; then
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-vals.json"
else [ "$node_type" == "rpc-node" ];
  file_url="https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/refs/heads/master/metrics-scripts/telegraf-rpc.json"
fi
#Download the selected configuration file
file_content=$(curl -sL "$file_url")

# Replace placeholders with actual values
updated_content=$(echo "$file_content" | sed "s/{{ job_name }}/$job/g; s/{{ metric_name }}/$metric_name/g; s/{{ total_mem }}/$total_mem/g; s/{{ total_disk }}/$total_disk/g; s/{{ disk_type }}/$disk_type/g; s/{{ disk_type_1 }}/$disk_type_1/g")

# remove  "folderUid": "{{ folder_uuid }}", from the dashboard as not required in the local setup
updated_content=${updated_content//'"folderUid": "{{ folder_uuid }}",'/}

# remove  "uid": "{{ uuid_2 }}", from the dashboard as not required in the local setup
updated_content=${updated_content//'"uid": "{{ uuid_2 }}",'/}

# Save the updated JSON to a file
echo "$updated_content" | jq .dashboard > grafana-provisioning/dashboards/supra-metrics.json

echo "Local Dashboard Updated for Telegraf Metrics!"


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

exit 0
