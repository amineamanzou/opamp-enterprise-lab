#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" opamp-cloud)"
mkdir -p "$run_dir/config" "$run_dir/logs" "$run_dir/artifacts"

cat > "$run_dir/run.md" <<RUN
# OpAMP Cloud Evidence Run

- Created at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Backend: Elastic Cloud trial
- Lab: Hetzner Cloud
- Scope: logs only

## Evidence To Attach

- Terraform outputs redacted to host roles and public IPs.
- Ansible run logs for bootstrap, OpAMP server, collectors, and synthetic logs.
- OpAMP inventory snapshots from \`GET /v1/agents\` and \`GET /v1/opamp/connections\`.
- Remote config assignment request and resulting remote config status.
- Elastic Discover or API proof that lab logs arrived.
- Collector binary checksums and measurement CSVs.

## Redaction Rules

- Remove API keys, bearer tokens, private keys, hostnames tied to real clients, and exact private network topology.
- Keep product versions, timestamps, scenario names, and anonymized host roles.
RUN

cp "$root/lab/configs/collector/logs-opamp-elastic.yaml" "$run_dir/config/logs-opamp-elastic.yaml"
cp "$root/lab/opamp-supervisor/supervisor.yaml" "$run_dir/config/supervisor.yaml"

echo "$run_dir"
