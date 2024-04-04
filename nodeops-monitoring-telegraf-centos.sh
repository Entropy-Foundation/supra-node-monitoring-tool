#!/bin/bash
# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

echo "_____Updating packeges_____"

yum update

yum install unzip -y

curl -LO https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip

unzip promtail-linux-amd64.zip

chmod a+x promtail-linux-amd64
mv promtail-linux-amd64 /usr/bin/promtail

mkdir /etc/promtail

curl -L https://raw.githubusercontent.com/grafana/loki/master/docs/clients/aws/ec2/promtail-ec2.yaml -o /etc/promtail/promtail.yaml


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

uuid=$(uuidgen)
uuid_2=$(uuidgen)
title="Logs-$hostname-$public_ip"
job=$hostname-$public_ip
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
          job: $hostname-$public_ip
          __path__: "$log_path"
EOF

service promtail restart

systemctl enable promtail.service


curl -X POST \
  'https://monitoring.services.supra.com/api/folders' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer glsa_RL9Ld2zAHE2aM5MUwGjOWoMmRAgxprHP_91dd26c9' \
  -d "{ \"title\": \"$folder_name\", \"uid\": \"$folder_uuid\" }"

echo "Updating Dashboard!"

# file_content=$(<dashboard.json)
file_content=$(curl -sL "https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/3433ad66515ad5c4dba1f3e1cba8006c76d3004b/node-logs.json")


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

yum update && yum install telegraf sysstat -y

rm /etc/telegraf/telegraf.conf*

curl -L  https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/498762912d9aad53cbf2aa3b269c87b321eaccde/telegraf.conf  -o  /etc/telegraf/telegraf.conf

systemctl restart telegraf.service
systemctl enable telegraf.service

echo "updating dashboard"

sleep 2


file_content=$(curl -sL "https://gist.githubusercontent.com/Supra-RaghulRajeshR/33d027b21be6f190c0c66e34fee3a9a1/raw/d142575d1c89e135c32817baeeaa28bdafc396f3/telegraf-metrics.json")


updated_content=$(echo "$file_content" | sed "s/{{ uuid_2 }}/$uuid_2/g; s/{{ job_name }}/$hostname/g; s/{{ folder_uuid }}/$folder_uuid/g; s/{{ metric_name }}/$metric_name/g")
# Write the updated content back to the file
echo "$updated_content" > new-telegraf-metrics.json

# sed "s/{{ job_name }}/$job/g"  


echo "Dashboard Updated!"

echo "Creating Dashboard"

curl -X POST   https://monitoring.services.supra.com/api/dashboards/db   -H 'Authorization: Bearer glsa_RL9Ld2zAHE2aM5MUwGjOWoMmRAgxprHP_91dd26c9'  -H 'Content-Type: application/json'   -d @new-telegraf-metrics.json

rm new-telegraf-metrics.json
