#!/usr/bin/env bash
set -euo pipefail

scenario="${1:-}"
case "$scenario" in
  extension|supervisor) ;;
  *) echo "usage: $0 extension|supervisor" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" "opamp-$scenario")"

mkdir -p "$run_dir/config" "$run_dir/logs"
{
  echo "# OpAMP $scenario smoke"
  echo
  echo "- scenario: $scenario"
  echo "- created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- opamp_endpoint: ${OPAMP_SERVER_WS_ENDPOINT:-ws://127.0.0.1:4320/v1/opamp}"
  echo "- elastic_endpoint_set: $([ -n "${ELASTIC_OTLP_ENDPOINT:-}" ] && echo yes || echo no)"
  echo
  echo "## Expected checks"
  echo
  echo "- Agent appears in \`GET /v1/agents\`."
  echo "- Agent reports health and effective config."
  echo "- Remote config assignment changes remote config status."
  echo "- Logs arrive in the Elastic Cloud trial when Elastic variables are set."
} > "$run_dir/README.md"

case "$scenario" in
  extension)
    cp "$root/lab/configs/collector/logs-opamp-elastic.yaml" "$run_dir/config/logs-opamp-elastic.yaml"
    ;;
  supervisor)
    cp "$root/lab/opamp-supervisor/supervisor.yaml" "$run_dir/config/supervisor.yaml"
    ;;
esac

echo "$run_dir"
