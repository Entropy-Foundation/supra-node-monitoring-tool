import os
import json
import requests
import subprocess
import re
from datetime import datetime
import glob
import sys

# Use /tmp directory to avoid permission issues
CACHE_FILE = "/tmp/ip_location_cache.json"  # File to store the cached IP and location data
log_directory = sys.argv[1]
log_dir = os.path.join(log_directory, "log")

def save_to_cache(data):
    """Save IP and location data to a JSON file."""
    try:
        with open(CACHE_FILE, "w") as file:
            json.dump(data, file)
    except Exception as e:
        print(f"Error saving to cache: {e}")

def load_from_cache():
    """Load IP and location data from a JSON file."""
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as file:
                return json.load(file)
        except Exception as e:
            print(f"Error loading cache: {e}")
    return None

def get_ip_and_location():
    """Fetch or retrieve the IP and location data."""
    # Try loading from cache
    cached_data = load_from_cache()
    if cached_data:
        return cached_data  # Return cached data without printing anything

    # Fetch new data if not found in cache
    ip_address = None
    location = {}
    try:
        # Fetch public IP
        response = requests.get('https://api64.ipify.org?format=json', timeout=5).json()
        ip_address = response.get("ip")
    except Exception as e:
        print(f"Error fetching IP: {e}")
    
    if ip_address:
        try:
            # Fetch location based on IP using ipinfo.io
            response = requests.get(f'https://ipinfo.io/{ip_address}/json', timeout=5).json()

            # Parse the location data
            location = {
                "latitude": response.get("loc", "").split(",")[0] if "loc" in response else None,
                "longitude": response.get("loc", "").split(",")[1] if "loc" in response else None,
                "region": response.get("region"),
            }

            # Check if any of the values are None and log it
            if location["latitude"] is None or location["longitude"] is None or location["region"] is None:
                print(f"Warning: Incomplete location data for IP {ip_address}: {location}")

        except Exception as e:
            print(f"Error fetching location: {e}")
    
    # Combine and save data to cache
    data = {
        "ip": ip_address,
        "latitude": location.get("latitude", 0),  # Default to 0 if None
        "longitude": location.get("longitude", 0),  # Default to 0 if None
        "region": location.get("region", "Unknown"),  # Default to "Unknown" if None
    }
    save_to_cache(data)
    return data

# def get_version_tag():
#     """Get the version tag from the binary."""
#     command = ["/home/ubuntu/supra", "--version"]
#     try:
#         result = subprocess.run(command, capture_output=True, text=True, check=True)
#         tag_line = next((line for line in result.stdout.splitlines() if 'tag:' in line), None)
#         if tag_line:
#             match = re.search(r'tag:\s*(\S+)', tag_line)
#             return match.group(1) if match else None
#     except subprocess.CalledProcessError as e:
#         print(f"Error fetching version tag: {e}")
#     return None

def get_latest_log_file(log_dir):
    """Find the latest log file."""
    log_files = glob.glob(os.path.join(log_dir, '*.log*'))
    return max(log_files, key=os.path.getmtime) if log_files else None

def extract_latest_metrics(log_file):
    """Extract block metrics from the log file."""
    metrics = {'height': 0, 'epoch': 0, 'round': 0}
    block_pattern = r"INFO execution: Executed Block hash: \([a-f0-9]+\), Block height: \((\d+)\), Block round: \((\d+)\), Block epoch: \((\d+)\)"
    try:
        with open(log_file, 'r') as file:
            for line in reversed(file.readlines()):
                match = re.search(block_pattern, line)
                if match:
                    metrics['height'] = int(match.group(1))
                    metrics['round'] = int(match.group(2))
                    metrics['epoch'] = int(match.group(3))
                    break
    except Exception as e:
        print(f"Error reading log file: {e}")
    return metrics

def fetch_api_block_metrics():
    """Fetch current block metrics from the API."""
    url = 'https://rpc-testnet.supra.com/rpc/v1/block'
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()
        return {
            'height': int(data['height']),
            'epoch': int(data['view']['epoch_id']['epoch']),
        }
    except Exception as e:
        print(f"Error fetching API metrics: {e}")
        return None

def format_uptime(uptime_seconds):
    """Format uptime as months, weeks, days, and hours."""
    days, remainder = divmod(uptime_seconds, 86400)
    hours = remainder // 3600
    weeks = days // 7
    months = days // 30
    remaining_days = days % 30

    parts = []
    if months > 0:
        parts.append(f"{months} month{'s' if months > 1 else ''}")
    if weeks > 0:
        parts.append(f"{weeks} week{'s' if weeks > 1 else ''}")
    if remaining_days > 0:
        parts.append(f"{remaining_days} day{'s' if remaining_days > 1 else ''}")
    if hours > 0:
        parts.append(f"{hours} hour{'s' if hours > 1 else ''}")
    return ", ".join(parts)

def get_service_uptime(service_name):
    """Get the uptime of the service."""
    try:
        result = subprocess.run(
            ['systemctl', 'status', service_name],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        match = re.search(r'Active: active \(running\) since (.+?);', result.stdout)
        if match:
            uptime_str = match.group(1)
            # Remove timezone (e.g., "UTC") if present
            uptime_str = uptime_str.replace(" UTC", "")
            # Parse the date string and calculate the uptime
            uptime = datetime.strptime(uptime_str, "%a %Y-%m-%d %H:%M:%S")
            now = datetime.utcnow()
            delta = now - uptime
            return format_uptime(delta.total_seconds())
        else:
            print("Service is not active or unable to parse uptime.")
            return "Unknown uptime"
    except Exception as e:
        print(f"Error getting service uptime: {e}")
        return "Error retrieving uptime"

def main():
    service_name = "supra-fullnode.service"
    ip_location_data = get_ip_and_location()
    # version_tag = get_version_tag()
    latest_log = get_latest_log_file(log_dir)
    log_metrics = extract_latest_metrics(latest_log) if latest_log else {}
    api_metrics = fetch_api_block_metrics()
    uptime = get_service_uptime(service_name)

    # Initialize sync status as None (no status yet)
    sync_status = None

    # If both log metrics and API metrics are available
    if log_metrics and api_metrics:
        height_diff = api_metrics['height'] - log_metrics['height']
        epoch_diff = api_metrics['epoch'] - log_metrics['epoch']
        
        # If block height and epoch are within acceptable limits, node is synced
        if height_diff <= 200 and epoch_diff <= 5:
            sync_status = 200
        # If there's a mismatch in either height or epoch, node is out of sync
        elif height_diff > 200 or epoch_diff > 5:
            sync_status = 503

    # Output in Telegraf-readable format, sync_status is now default to 500 if not determined
    print(f"ip=\"{ip_location_data['ip']}\",latitude={ip_location_data.get('latitude', 0)},"
          f"longitude={ip_location_data.get('longitude', 0)},region=\"{ip_location_data.get('region', '')}\" "
          f"uptime=\"{uptime}\",sync_status={sync_status if sync_status is not None else 500}")

if __name__ == "__main__":
    main()