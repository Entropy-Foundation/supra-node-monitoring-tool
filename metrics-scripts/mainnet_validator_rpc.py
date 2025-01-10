import os
import json
import requests
import subprocess
import re
import unicodedata
from datetime import datetime
import glob
import urllib.parse
import sys
# Constants
CACHE_FILE = "/tmp/ip_location_cache.json"  # Cache file for IP location data
log_directory = sys.argv[1]
log_dir = os.path.join(log_directory, "rpc_node_logs/")
GRAFANA_URL = "https://monitoring.services.supra.com"
API_KEY = ""

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

def sanitize_string(value):
    """Convert special characters in a string to Telegraf-friendly alphabets."""
    if isinstance(value, str):
        value = unicodedata.normalize('NFKD', value).encode('ASCII', 'ignore').decode('utf-8')
        value = value.replace(" ", "_")
        value = re.sub(r"[^a-zA-Z0-9_\-]", "_", value)
    return value

def get_ip_and_location():
    """Fetch or retrieve IP and location data."""
    cached_data = load_from_cache()
    if cached_data:
        return cached_data

    ip_address = None
    location = {}
    try:
        response = requests.get('https://api64.ipify.org?format=json', timeout=5).json()
        ip_address = response.get("ip")
    except Exception as e:
        print(f"Error fetching IP: {e}")

    if ip_address:
        try:
            response = requests.get(f'https://ipinfo.io/{ip_address}/json', timeout=5).json()
            region = response.get("region", "Unknown")
            location = {
                "latitude": response.get("loc", "").split(",")[0] if "loc" in response else 0,
                "longitude": response.get("loc", "").split(",")[1] if "loc" in response else 0,
                "region": sanitize_string(region),
            }
        except Exception as e:
            print(f"Error fetching location: {e}")

    data = {
        "ip": ip_address,
        "latitude": location.get("latitude", 0),
        "longitude": location.get("longitude", 0),
        "region": location.get("region", "Unknown"),
    }
    save_to_cache(data)
    return data

# def get_version_tag():
#     """Fetch the version tag from the binary."""
#     command = ["/home/ubuntu/supra", "--version"]
#     try:
#         result = subprocess.run(command, capture_output=True, text=True, check=True)
#         tag_line = next((line for line in result.stdout.splitlines() if 'tag:' in line), None)
#         if tag_line:
#             match = re.search(r'tag:\s*(\S+)', tag_line)
#             return match.group(1) if match else "Unknown"
#     except subprocess.CalledProcessError as e:
#         print(f"Error fetching version tag: {e}")
#     return "Unknown"

def get_latest_log_file(log_dir):
    """Find the latest log file."""
    log_files = glob.glob(os.path.join(log_dir, 'rpc_node.log*'))  # Match rpc_node.log files with timestamps
    if log_files:
        # Return the latest log file based on modification time
        latest_log = max(log_files, key=os.path.getmtime)
        return latest_log
    return None

def extract_latest_metrics(log_file):
    """Extract block metrics from the log file."""
    metrics = {'height': 0, 'epoch': 0, 'round': 0}
    block_pattern = r"INFO .*?Executed Block hash: \([a-f0-9]+\), Block height: \((\d+)\), Block round: \((\d+)\), Block epoch: \((\d+)\)"
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
    url = 'https://rpc-mainnet.supra.com/rpc/v1/block'
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
    """Format uptime as total days and hours."""
    days = uptime_seconds // 86400
    hours = (uptime_seconds % 86400) // 3600
    return f"{days}d {hours}h"

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
            uptime_str = match.group(1).replace(" UTC", "")
            uptime = datetime.strptime(uptime_str, "%a %Y-%m-%d %H:%M:%S")
            delta = datetime.utcnow() - uptime
            return format_uptime(delta.total_seconds())
    except Exception as e:
        print(f"Error getting service uptime: {e}")
    return "Unknown"

def check_proposing_status():
    """Check if the node is proposing blocks."""
    log_command = (
        f"awk '/Proposing.*SmrBlock/ {{ print $0 }}' $(ls -t {log_dir}* | head -n 2) "
        "| sort -k1,2 -r | head -n 1"
    )
    current_time_str = subprocess.check_output(
        ["date", "--utc", "+%Y-%m-%dT%H:%M:%S.%6NZ+00:00"], text=True
    ).strip()
    current_time = datetime.strptime(current_time_str[:-6], "%Y-%m-%dT%H:%M:%S.%fZ")

    try:
        latest_log = subprocess.check_output(log_command, shell=True, text=True).strip()
        if latest_log:
            log_timestamp_str = latest_log.split("]")[0][1:]
            log_time = datetime.strptime(log_timestamp_str[:-6], "%Y-%m-%dT%H:%M:%S.%fZ")
            time_diff = abs((current_time - log_time).total_seconds())
            return "proposing" if time_diff <= 600 else "not_proposing"
    except Exception as e:
        print(f"Error processing proposing status: {e}")
    return "not_proposing"

def get_instance_zone():
    """Fetch the instance zone from Google Cloud metadata."""
    try:
        response = subprocess.run(
            ['curl', '-s', 'http://metadata.google.internal/computeMetadata/v1/instance/zone',
             '-H', 'Metadata-Flavor: Google'],
            capture_output=True, text=True, check=True
        )
        zone = response.stdout.split('/')[-1]
        return sanitize_string(zone)
    except subprocess.CalledProcessError as e:
        print(f"Error fetching instance zone: {e}")
        return "Unknown_zone"

def fetch_dashboards(grafana_url, api_key, public_ip):
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    try:
        response = requests.get(f"{grafana_url}/api/search", headers=headers)
        if response.status_code == 200:
            dashboards = response.json()
            matched = [
                f"{grafana_url}{urllib.parse.quote(d['url'])}" 
                for d in dashboards if public_ip in d['title'] or public_ip in d['url']
            ]
            return matched
        else:
            print(f"Error fetching dashboards: {response.status_code}")
    except Exception as e:
        print(f"Exception occurred: {str(e)}")
    return []

def main():
    service_name = "supra-smr.service"  # Updated service name
    ip_location_data = get_ip_and_location()
    # version_tag = get_version_tag()
    latest_log = get_latest_log_file(log_dir)
    log_metrics = extract_latest_metrics(latest_log) if latest_log else {}
    api_metrics = fetch_api_block_metrics()
    uptime = get_service_uptime(service_name)
    proposing_status = check_proposing_status()
    zone = get_instance_zone()

    sync_status = 500
    if log_metrics and api_metrics:
        height_diff = api_metrics['height'] - log_metrics['height']
        epoch_diff = api_metrics['epoch'] - log_metrics['epoch']
        if height_diff <= 1500 and epoch_diff <= 5:
            sync_status = 200
        elif height_diff > 1500 or epoch_diff > 5:
            sync_status = 503

    public_ip = ip_location_data['ip']
    dashboards = fetch_dashboards(GRAFANA_URL, API_KEY, public_ip)
    dashboards_output = ";".join(dashboards) if dashboards else "None"

    print(f"ip=\"{sanitize_string(ip_location_data['ip'])}\",latitude={ip_location_data['latitude']},"
          f"longitude={ip_location_data['longitude']},region=\"{sanitize_string(ip_location_data['region'])}\" "
          f"uptime=\"{sanitize_string(uptime)}\","
          f"sync_status={sync_status},proposing_status=\"{sanitize_string(proposing_status)}\","
          f"zone=\"{sanitize_string(zone)}\",dashboards=\"{dashboards_output}\"")

if __name__ == "__main__":
    main()