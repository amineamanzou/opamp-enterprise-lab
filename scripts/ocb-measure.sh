#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="$root/docs/evidence/runs/$timestamp-ocb-measure"

mkdir -p "$run_dir"
cp "$root/lab/configs/measurements/measurement-plan.md" "$run_dir/README.md"
cat > "$run_dir/measurements.csv" <<'CSV'
scenario,binary_size_bytes,image_size_bytes,rss_idle_mb,rss_load_mb,cpu_load_pct,startup_ms,throughput_lps,loss_or_backpressure
otelcol-logs-min,,,,,,,,
otelcol-logs-opamp,,,,,,,,
otelcol-contrib,,,,,,,,
edot-collector,,,,,,,,
elastic-agent,,,,,,,,
CSV

echo "$run_dir"
