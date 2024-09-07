# Supra Node Monitoring Tool

## Overview
This tool assists node operators in setting up monitoring for their nodes. It automates the process of installing and configuring Promtail, a log shipper, and creating a dashboard in Grafana to visualize the logs.

## Dashboard with list of Metrics
- You can also view the ongoing metrics setup by visiting and contributing to our monitoring dashboard [project](https://github.com/orgs/Entropy-Foundation/projects/13)
  
![supra-monitoring-dashboard](https://github.com/Entropy-Foundation/supra-node-monitoring-tool/assets/90824946/dd86df57-529a-4490-94b9-1fdb2ec3dc0d)

## Prerequisites
- Ensure your email is invited into the Grafana Dashboard. If not, request the Supra team to add your email to access your dashboard.
- Download the script with the following command:

     For Ubuntu
    ```bash
     wget -O  https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/master/nodeops-monitoring-telegraf.sh
    ```
     For Centos
    ```bash
     wget -O  https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/master/nodeops-monitoring-telegraf-centos.sh
    ```

- Change permission for the script file to be executable using the below command:

    For ubuntu
    ```bash
     chmod +x nodeops-monitoring-telegraf.sh
    ```
    For Centos
    ```bash
     chmod +x nodeops-monitoring-telegraf-centos.sh
    ```

## Usage
- Run the script file with sudo privileges. While running the script, you may be prompted to enter the log path. Please enter the whole log path as a value, which is `[Local Full Path To store configs]/supra.log`. An example output for a successful run:
    
    For ubuntu
    ```bash
     sudo ./nodeops-monitoring-telegraf.sh
    ```
    For Centos
    ```bash
     sudo ./nodeops-monitoring-telegraf-centos.sh
    ```

- The script will install Promtail, read the provided log path, and create a dashboard in Grafana for visualizing the logs.

## After Installation
- Once the script runs successfully, inform Supra team’s Operations member through the Supra Testnet Communication Channel. They will grant you the corresponding role in Grafana to visualize your logs dashboard.

## Note
- Ensure to replace `/home/ubuntu/supra_configs/supra.log` with the correct log path for your setup.





