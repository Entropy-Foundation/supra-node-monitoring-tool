import re
import time
from datetime import datetime
import sys
import os
import glob

# Path to the log files
log_dir = sys.argv[1]
log_files = glob.glob(os.path.join(log_dir, 'supra_node_logs/supra.log*'))

# Regex patterns to extract the transaction hash and timestamps
transaction_received_pattern = r"mempool::batch_proposer: Received transaction: (\w+)"
transaction_executed_pattern = r"INFO execution: Executed transaction: (\w+), supra status: Success"

# Store the transaction hash and its timestamps
transactions = {}

def parse_timestamp(log_line):
    """Extracts the timestamp from a log line."""
    timestamp_str = log_line.split(']')[0].replace('[', '')
    return datetime.strptime(timestamp_str, "%Y-%m-%dT%H:%M:%S.%fZ+00:00")

def monitor_logs():
    for log_file_path in log_files:
        with open(log_file_path, 'r') as file:
            file.seek(0, 2)  # Move to the end of the file
            while True:
                line = file.readline()
                if not line:
                    time.sleep(0.1)
                    continue

                received_match = re.search(transaction_received_pattern, line)
                if received_match:
                    transaction_hash = received_match.group(1)
                    received_time = parse_timestamp(line)
                    transactions[transaction_hash] = {'received_time': received_time}

                executed_match = re.search(transaction_executed_pattern, line)
                if executed_match:
                    transaction_hash = executed_match.group(1)
                    executed_time = parse_timestamp(line)
                    if transaction_hash in transactions and 'received_time' in transactions[transaction_hash]:
                        received_time = transactions[transaction_hash]['received_time']
                        execution_duration = (executed_time - received_time).total_seconds()
                        
                        # Prepare output in InfluxDB line protocol format
                        influx_output = f"transactions,transaction_hash={transaction_hash} execution_duration={execution_duration},received_time={received_time.timestamp()},executed_time={executed_time.timestamp()} {int(executed_time.timestamp() * 1e9)}"
                        
                        # Output to stdout for Telegraf exec plugin
                        print(influx_output)

                        # Exit after processing the first transaction
                        return

if __name__ == "__main__":
    monitor_logs()
