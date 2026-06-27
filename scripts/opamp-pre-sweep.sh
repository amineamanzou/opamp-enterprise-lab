#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$root/lab/ansible/inventory/hosts.ini"
duration="${OPAMP_PRE_SWEEP_DURATION_SECONDS:-60}"
rates="${OPAMP_PRE_SWEEP_RATES:-1000 5000 10000}"
out="${OPAMP_PRE_SWEEP_OUT:-$root/tmp/opamp-pre-sweep.csv}"

agent_host="$(awk '$1 == "opamp-poc-agent" { for (i = 1; i <= NF; i++) if ($i ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $i); print $i } }' "$inventory")"
if [ -z "$agent_host" ]; then
  echo "could not resolve host agent from $inventory" >&2
  exit 1
fi

mkdir -p "$(dirname "$out")"
printf 'timestamp_utc,role,target_logs_per_second,duration_seconds,generated_logs,collector_rss_kib,collector_cpu_percent,supervisor_rss_kib,supervisor_cpu_percent,notes\n' > "$out"

for rate in $rates; do
  echo "running pre-sweep rate=${rate} duration=${duration}s" >&2
  result="$(
    ssh -o UserKnownHostsFile=/tmp/opamp_poc_known_hosts -o StrictHostKeyChecking=accept-new "root@$agent_host" \
      "OPAMP_SWEEP_RATE='$rate' OPAMP_SWEEP_DURATION='$duration' python3 -" <<'PY'
import json
import os
import random
import subprocess
import time
from datetime import datetime, timezone

rate = float(os.environ["OPAMP_SWEEP_RATE"])
duration = float(os.environ["OPAMP_SWEEP_DURATION"])
path = "/var/log/opamp-poc/synthetic.log"
env_path = "/etc/otelcol/collector.env"
if os.path.exists(env_path):
    with open(env_path, encoding="utf-8") as env:
        for line in env:
            if line.startswith("LOG_FILE_PATHS="):
                path = line.split("=", 1)[1].strip().split(",", 1)[0]

levels = ["INFO", "WARN", "ERROR"]
services = ["checkout", "billing", "inventory", "edge"]
count = 0
deadline = time.monotonic() + duration
batch_size = max(1, min(1000, int(rate / 10)))
delay = batch_size / rate

with open(path, "a", encoding="utf-8") as stream:
    while time.monotonic() < deadline:
        lines = []
        now = datetime.now(timezone.utc).isoformat()
        for _ in range(batch_size):
            event = {
                "ts": now,
                "level": random.choices(levels, weights=[85, 10, 5])[0],
                "service": random.choice(services),
                "message": "synthetic fleet pre-sweep event",
                "latency_ms": random.randint(5, 1500),
                "opamp_sweep_rate": int(rate),
            }
            lines.append(json.dumps(event, separators=(",", ":")))
        stream.write("\n".join(lines) + "\n")
        stream.flush()
        count += batch_size
        time.sleep(delay)

def proc_stats(pattern):
    try:
        output = subprocess.check_output(["ps", "-eo", "rss=,%cpu=,args="], text=True)
    except Exception:
        return "0,0.00"
    rss = 0
    cpu = 0.0
    for line in output.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) < 3 or pattern not in parts[2]:
            continue
        try:
            rss += int(float(parts[0]))
            cpu += float(parts[1])
        except ValueError:
            continue
    return f"{rss},{cpu:.2f}"

collector = proc_stats("otelcol-logs-opamp")
supervisor = proc_stats("opampsupervisor")
print(f"{count},{collector},{supervisor}")
PY
  )"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s,host-agent,%s,%s,%s,\n' "$timestamp" "$rate" "$duration" "$result" >> "$out"
done

echo "$out"
