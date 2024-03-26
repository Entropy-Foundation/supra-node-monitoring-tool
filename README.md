# supra-node-monitoring-tool
Prerequisites:
Respective node-operator’s mail should be invited into the Grafana Dashboard. If not, please request the Supra team to add your respective email into the Grafana Dashboard to access your dashboard.
Download the script with the following command. 

$ wget https://gist.githubusercontent.com/sjadiya-supra/0b1dab57d27daa4422913794e0c61375/raw/22e0d58ed015f70c5ff1473fba51ca3175d4bce8/nodeops-monitoring.sh

Change permission for the script file to be executable using the below command.

$ chmod +x nodeops-monitoring.sh

Run the script file with sudo privileges. While running the script you may be prompted to enter the log path. Please enter the whole log path as a value, which is `[Local Full Path To store configs]/supra.log`. An example output for a successful run:

$ sudo ./nodeops-monitoring.sh

Installing promtail...
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following NEW packages will be installed:
  promtail
0 upgraded, 1 newly installed, 0 to remove and 3 not upgraded.
Need to get 27.3 MB of archives.
After this operation, 93.0 MB of additional disk space will be used.
Get:1 https://apt.grafana.com stable/main amd64 promtail amd64 2.9.5 [27.3 MB]
Fetched 27.3 MB in 11s (2,528 kB/s)                                                                                                                                                                               
Selecting previously unselected package promtail.
(Reading database ... 307313 files and directories currently installed.)
Preparing to unpack .../promtail_2.9.5_amd64.deb ...
Unpacking promtail (2.9.5) ...
Setting up promtail (2.9.5) ...
 Post Install of a clean install
Adding system user `promtail' (UID 131) ...
Adding new user `promtail' (UID 131) with group `nogroup' ...
Not creating home directory `/home/promtail'.
 Reload the service unit from disk
 Unmask the service
 Set the preset flag for the service unit
Created symlink /etc/systemd/system/multi-user.target.wants/promtail.service → /etc/systemd/system/promtail.service.
 Set the enabled flag for the service unit
promtail installation completed.
Copying promtail service configuration...
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
Restarting promtail service...
Done!
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    12  100    12    0     0     39      0 --:--:-- --:--:-- --:--:--    39
Job name is, webclues-Vostro-5620-27.109.9.122
Title name is Logs-webclues-Vostro-5620-27.109.9.122
Please enter the log file path: /home/ubuntu/supra_configs/supra.log
You entered: /home/ubuntu/supra_configs/supra.log
Is this correct? (y/n) y
Log file path confirmed: /home/ubuntu/supra_configs/supra.log
Updating Dashboard!
Dashboard Updated!
Creating Dashboard
{"folderUid":"ac9d8682-faa8-4454-ab33-d7b5f47375ae","id":83,"slug":"logs-webclues-vostro-5620-27-109-9-122","status":"success","uid":"c9a166ba-e283-4a23-9ce5-dd63ccd86174","url":"/d/c9a166ba-e283-4a23-9ce5-dd63ccd86174/logs-webclues-vostro-5620-27-109-9-122","version":1}


This script will configure the Promtail agent to push logs to the newly created dashboard on https://monitoring.services.supra.com/ for the respective node operators. Once it runs successfully, please inform Supra team’s Operations member through the Supra Testnet Communication Channel, so that we can grant you the corresponding role in Grafana to visualize your logs dashboard.
