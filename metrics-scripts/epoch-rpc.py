import os
import re
import glob
import gzip
from datetime import datetime, timedelta
import sys

# Directory where the logs are stored
parent_dir = sys.argv[1]
log_dir = os.path.join(parent_dir, "log")
epoch_file_pattern = "supra-fullnode.log*"

def add_seconds_to_timestamp(timestamp_str, seconds):
    # Replace "Z+00:00" or "Z" with "+00:00" for compatibility with fromisoformat
    cleaned_timestamp_str = timestamp_str.replace("Z+00:00", "+00:00").replace("Z", "+00:00")
    timestamp_dt = datetime.fromisoformat(cleaned_timestamp_str)
    new_timestamp_dt = timestamp_dt + timedelta(seconds=seconds)
    return new_timestamp_dt.isoformat() + "Z"

def open_log_file(log_file):
    """Open plain text or .gz compressed log files."""
    if log_file.endswith(".gz"):
        return gzip.open(log_file, "rt", encoding="utf-8")
    else:
        return open(log_file, "r", encoding="utf-8")

def find_latest_epoch_info():
    epoch_starts = {}
    max_epoch = None

    for log_file in sorted(glob.glob(f"{log_dir}/{epoch_file_pattern}")):
        try:
            with open_log_file(log_file) as f:
                for line in f:
                    if "Block epoch:" in line:
                        epoch_match = re.search(r"Block epoch: \((\d+)\)", line)
                        if not epoch_match:
                            continue
                        epoch = int(epoch_match.group(1))

                        timestamp_match = re.search(r"\[([^\]]+)\]", line)
                        if not timestamp_match:
                            continue
                        timestamp = timestamp_match.group(1)

                        if epoch not in epoch_starts or timestamp < epoch_starts[epoch]:
                            epoch_starts[epoch] = timestamp

                        if max_epoch is None or epoch > max_epoch:
                            max_epoch = epoch
        except (UnicodeDecodeError, IOError) as e:
            print(f"Skipping file {log_file}: {e}")
            continue

    if max_epoch is not None:
        return max_epoch, epoch_starts[max_epoch]
    return None, None

def output_epoch_times():
    current_epoch, current_start_time = find_latest_epoch_info()

    if current_epoch is None or current_start_time is None:
        print("epoch_metrics,host=hostname status=\"No epoch information found\"")
        return

    current_end_time = add_seconds_to_timestamp(current_start_time, 7200)

    # Generate InfluxDB-compatible output
    print(f"epoch_metrics current_epoch={current_epoch}i,end_time=\"{current_end_time}\"")

if __name__ == "__main__":
    output_epoch_times()
