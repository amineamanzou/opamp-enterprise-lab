#!/usr/bin/env bash
set -euo pipefail

kind="${1:-smoke}"
case "$kind" in
  smoke|scale|opamp-extension|opamp-supervisor|opamp-cloud|log-export|vanilla-ui|ops-experience|agent-scale|regulated-observability|elastic-fleet-otel-only|bindplane-otel|openlit-opamp|exit-drill-secrets-outage) ;;
  *) echo "usage: $0 smoke|scale|opamp-extension|opamp-supervisor|opamp-cloud|log-export|vanilla-ui|ops-experience|agent-scale|regulated-observability|elastic-fleet-otel-only|bindplane-otel|openlit-opamp|exit-drill-secrets-outage" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="$root/docs/evidence/runs/$timestamp-$kind"

mkdir -p "$run_dir"
cp "$root/docs/evidence/runs/template/README.md" "$run_dir/README.md"
cp "$root/docs/evidence/runs/template/results.csv" "$run_dir/results.csv"
echo "$run_dir"
