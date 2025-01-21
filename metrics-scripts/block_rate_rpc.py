import os
import re
import glob
from dateutil import parser
import sys
parent_dir = sys.argv[1]

log_dir = os.path.join(parent_dir, "log")

epoch_file_pattern = "supra-fullnode.log*"

def find_latest_log_file():
    files = sorted(glob.glob(f"{log_dir}/{epoch_file_pattern}"), key=os.path.getmtime, reverse=True)
    return files[0] if files else None

def parse_timestamp_ns(line):
    match = re.search(r"\[([^\]]+)\]", line)
    if match:
        timestamp_str = match.group(1).replace("Z+00:00", "")  # Strip the "Z+00:00" part
        try:
            timestamp_dt = parser.isoparse(timestamp_str)  # Parse as ISO 8601
            return int(timestamp_dt.timestamp() * 1e9)
        except ValueError:
            print(f"Could not parse timestamp: {timestamp_str}")
    return None

def block_round_time_rate():
    latest_log_file = find_latest_log_file()
    last_block_round, last_ts, second_last_block_round, second_last_ts = None, None, None, None

    with open(latest_log_file, "r") as f:
        for line in f:
            if "Block round" in line:
                ts = parse_timestamp_ns(line)
                match = re.search(r"Block round: \((\d+)\)", line)
                if match:
                    block_round = int(match.group(1))
                    if last_block_round is not None:
                        second_last_block_round, second_last_ts = last_block_round, last_ts
                    last_block_round, last_ts = block_round, ts

    if second_last_block_round is not None and last_block_round != second_last_block_round:
        time_diff_sec = (last_ts - second_last_ts) / 1e9
        return time_diff_sec
    return None

def block_height_time_rate():
    latest_log_file = find_latest_log_file()
    last_block_height, last_ts, second_last_block_height, second_last_ts = None, None, None, None

    with open(latest_log_file, "r") as f:
        for line in f:
            if "Block height" in line:
                ts = parse_timestamp_ns(line)
                match = re.search(r"Block height: \((\d+)\)", line)
                if match:
                    block_height = int(match.group(1))
                    if last_block_height is not None:
                        second_last_block_height, second_last_ts = last_block_height, last_ts
                    last_block_height, last_ts = block_height, ts

    if second_last_block_height is not None and last_block_height != second_last_block_height:
        time_diff_sec = (last_ts - second_last_ts) / 1e9
        return time_diff_sec
    return None

def output_metrics():
    block_round_rate = block_round_time_rate()
    height_time_rate = block_height_time_rate()
    # Output results in InfluxDB line protocol format
    # print(f"block_round_rate value={block_round_rate}")
    # print(f"block_height_time_rate value={height_time_rate}")
    influx_line = (
            f"block_time_rate "
            f"block_round_rate={block_round_rate},"
            f"block_height_rate={height_time_rate}"
    )
    print(influx_line)


if __name__ == "__main__":
    output_metrics()