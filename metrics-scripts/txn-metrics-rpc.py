import os
import re
import subprocess
from datetime import datetime
import sys
log_directory = sys.argv[1]
log_files = os.path.join(log_directory, "rpc_node_logs/rpc_node.log")


def extract_timestamp(line, pattern):
    match = re.search(pattern, line)
    if match:
        return match.group(1)
    return None

def process_logs(pattern, log_files, extract_rate=False):
    grep_cmd = f"grep '{pattern}' {log_files}"
    result = subprocess.run(grep_cmd, shell=True, stdout=subprocess.PIPE, text=True)
    
    if result.returncode != 0 or not result.stdout.strip():
        return "0.0"

    lines = result.stdout.strip().split('\n')
    
    counts = {}
    latest_minute = ""
    
    for line in lines:
        timestamp = extract_timestamp(line, r"\[([0-9\-]{10})T([0-9]{2}:[0-9]{2}):[0-9]{2}\.[0-9]+Z")
        if timestamp:
            date_key = f"{timestamp[0]} {timestamp[1]}"
            counts[date_key] = counts.get(date_key, 0) + 1
            latest_minute = max(latest_minute, date_key)
    
    if extract_rate:
        return calculate_rate(lines)
    
    return str(counts.get(latest_minute, 0))

def calculate_rate(lines):
    start_time = end_time = None
    for line in lines:
        timestamp = extract_timestamp(line, r"\[([0-9\-T:.]+)Z")
        if timestamp:
            timestamp_dt = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%S.%f")
            timestamp_seconds = timestamp_dt.timestamp()
            if start_time is None:
                start_time = timestamp_seconds
            end_time = timestamp_seconds

    if start_time and end_time and len(lines) > 0:
        duration = end_time - start_time
        if duration > 0:
            rate = len(lines) / duration
            return f"{rate:.2f}"
    return "0.0"

def get_disk_usage(path):
    """ Get disk usage of a directory. Return '0' if directory doesn't exist. """
    if os.path.isdir(path):
        return subprocess.check_output(['du', '-sb', path]).split()[0].decode('utf-8')
    return "0"  # Return 0 if directory doesn't exist
def main():
    supra_fail_count = process_logs("supra status: Fail", log_files)
    vm_success_count = process_logs("VM status: Keep(Success)", log_files)
    vm_success_rate = process_logs("VM status: Keep(Success)", log_files, extract_rate=True)
    supra_fail_rate = process_logs("supra status: Fail", log_files, extract_rate=True)

    # Disk usage metrics
    rpc_ledger = get_disk_usage(log_directory)
    rpc_store = get_disk_usage(log_directory)
    rpc_archive = get_disk_usage(log_directory)
    smr_storage = get_disk_usage(log_directory)
    ledger_storage = get_disk_usage(log_directory)

    # Output in InfluxDB line protocol format for Telegraf without host
    print(f"metrics Supra_Fail_Count={supra_fail_count},VM_Success_Count={vm_success_count},VM_Success_Rate={vm_success_rate},Supra_Fail_Rate={supra_fail_rate},rpc_ledger={rpc_ledger},rpc_store={rpc_store},rpc_archive={rpc_archive},smr_storage={smr_storage},ledger_storage={ledger_storage}")

if __name__ == "__main__":
    main()