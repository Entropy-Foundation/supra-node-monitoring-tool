# Supra Node Monitoring Tool

## Overview
This tool assists node operators in setting up monitoring for their nodes. It automates the process of installing and configuring Promtail, a log shipper, and creating a dashboard in Grafana to visualize the logs.

## Prerequisites
- Ensure your email is invited into the Grafana Dashboard. If not, request the Supra team to add your email to access your dashboard.
- Download the script with the following command:

    ```bash
     wget https://raw.githubusercontent.com/Entropy-Foundation/supra-node-monitoring-tool/master/nodeops-monitoring-telegraf.sh
    ```

- Change permission for the script file to be executable using the below command:

    ```bash
     chmod +x nodeops-monitoring-telegraf.sh
    ```

## Usage
- Run the script file with sudo privileges. While running the script, you may be prompted to enter the log path. Please enter the whole log path as a value, which is `[Local Full Path To store configs]/supra.log`. An example output for a successful run:

    ```bash
     sudo ./nodeops-monitoring-telegraf.sh
    ```

- The script will install Promtail, read the provided log path, and create a dashboard in Grafana for visualizing the logs.

## After Installation
- Once the script runs successfully, inform Supra team’s Operations member through the Supra Testnet Communication Channel. They will grant you the corresponding role in Grafana to visualize your logs dashboard.

## Note
- Ensure to replace `/home/ubuntu/supra_configs/supra.log` with the correct log path for your setup.
