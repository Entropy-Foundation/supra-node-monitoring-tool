import os
import glob
import re
from datetime import datetime
import sys
# Directory where the logs are stored
parent_dir = sys.argv[1]

log_dir = os.path.join(parent_dir, "log")

def get_latest_log_file(log_dir):
    """Finds the latest log file based on modification time."""
    log_files = glob.glob(os.path.join(log_dir, 'supra-fullnode.log*'))
    if log_files:
        return max(log_files, key=os.path.getmtime)
    return None

def extract_latest_metrics(log_file):
    """Extracts the latest block metrics from the log file."""
    # Initialize metrics
    metrics = {
        'height': '0',
        'epoch': '0',
        'round': '0'
    }
    
    try:
        # Main pattern to match the entire block execution log line
        block_pattern = r"INFO .*?Executed Block hash: \([a-f0-9]+\), Block height: \((\d+)\), Block round: \((\d+)\), Block epoch: \((\d+)\)"
        
        with open(log_file, 'r') as file:
            # Read all lines and reverse them to start from the end
            lines = file.readlines()
            
            # Search through lines in reverse
            for line in reversed(lines):
                match = re.search(block_pattern, line)
                if match:
                    metrics['height'] = match.group(1)
                    metrics['round'] = match.group(2)
                    metrics['epoch'] = match.group(3)
                    break
                    
        return metrics
        
    except Exception as e:
        print(f"Error reading log file: {e}")
        return metrics

def main():
    latest_log = get_latest_log_file(log_dir)
    
    if latest_log:
        # print(f"Processing log file: {latest_log}")
        
        # Extract metrics
        metrics = extract_latest_metrics(latest_log)
        
        # Current timestamp in nanoseconds for InfluxDB Line Protocol
        timestamp_ns = int(datetime.utcnow().timestamp() * 1e9)

        # Output in InfluxDB Line Protocol format
        influx_line = (
            f"block_metrics "
            f"block_height={metrics['height']},"
            f"block_epoch={metrics['epoch']},"
            f"block_round={metrics['round']} "
            f"{timestamp_ns}"
        )
        print(influx_line)
        
        # # Debug output
        # print("\nDebug Values:")
        # print(f"Height: {metrics['height']}")
        # print(f"Epoch: {metrics['epoch']}")
        # print(f"Round: {metrics['round']}")
    else:
        print("No log files found in directory:", log_dir)

if __name__ == "__main__":
    main()