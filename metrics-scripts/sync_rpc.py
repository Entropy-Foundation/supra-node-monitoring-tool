
import os
import glob
import re
import requests
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
    # Initialize metrics as integers for proper comparison
    metrics = {
        'height': 0,
        'epoch': 0,
        'round': 0
    }
    
    try:
        # Main pattern to match the entire block execution log line
        block_pattern = r"INFO execution: Executed Block hash: \([a-f0-9]+\), Block height: \((\d+)\), Block round: \((\d+)\), Block epoch: \((\d+)\)"
        
        with open(log_file, 'r') as file:
            # Read all lines and reverse them to start from the end
            lines = file.readlines()
            
            # Search through lines in reverse
            for line in reversed(lines):
                match = re.search(block_pattern, line)
                if match:
                    metrics['height'] = int(match.group(1))  # Convert to integer
                    metrics['round'] = int(match.group(2))   # Convert to integer
                    metrics['epoch'] = int(match.group(3))   # Convert to integer
                    break
                    
        return metrics
        
    except Exception as e:
        print(f"Error reading log file: {e}")
        return metrics

def fetch_api_block_metrics():
    """Fetches the current block metrics from the API."""
    url = 'https://rpc-testnet.supra.com/rpc/v1/block'
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        
        # Extract height and epoch from the API response
        height = int(data['height'])  # Convert height to integer
        epoch = int(data['view']['epoch_id']['epoch'])  # Convert epoch to integer
        
        return {
            'height': height,
            'epoch': epoch
        }
        
    except Exception as e:
        print(f"Error fetching block data from API: {e}")
        return None

def main():
    latest_log = get_latest_log_file(log_dir)
    
    if latest_log:
        # Extract metrics from the latest log file
        metrics = extract_latest_metrics(latest_log)
        
        # Fetch current metrics from the API
        api_metrics = fetch_api_block_metrics()
        
        if api_metrics:
            height_diff = api_metrics['height'] - metrics['height']
            epoch_diff = api_metrics['epoch'] - metrics['epoch']
            
            if height_diff <= 100 and epoch_diff <= 5:
                status_code = 200  # In sync
            else:
                status_code = 503  # Behind by threshold
        else:
            status_code = 500  # Error fetching API data
    else:
        status_code = 500  # No log file found

    print(f"sync_status status={status_code}")

if __name__ == "__main__":
    main()