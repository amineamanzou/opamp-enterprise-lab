#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" ops-experience)"
mkdir -p "$run_dir/artifacts" "$run_dir/config" "$run_dir/logs" "$run_dir/screenshots"

cat > "$run_dir/run.md" <<EOF
# OpAMP Operations Experience Evidence Run

- Created at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Scenario: vanilla custom Go OpAMP server with opampsupervisor-managed VM collector
- Evidence label: custom-go-opamp-ops
- Branch: $(git -C "$root" branch --show-current 2>/dev/null || echo unknown)
- Commit: $(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)

## Operations Under Test

| Operation | Target | Expected evidence |
| --- | --- | --- |
| Remote config update | VM supervisor ring | desired hash, APPLIED status, ingest phase marker, effective config visibility note |
| Bad config and recovery | VM supervisor ring | FAILED status, operator rollback, APPLIED after recovery |
| Restart command | VM supervisor agent | pending command, disconnect/reconnect, health returns OK |
| Downgrade/upgrade | VM collector binary | version visible changes, ingest continuity notes |
| Pre-sweep volumetry | VM collector path | 1k/5k/10k generated count, CPU/RSS, backpressure notes |

## Friction and Corrections

| Issue | Cause | Correction | Comparative impact |
| --- | --- | --- | --- |
| Sparse capabilities on direct extension agents | Direct collector extension did not expose usable version, hostname, health, config status, or hash in the vanilla server inventory | Use \`opampsupervisor\` for the VM host-agent day-2 scenario | Adds setup work but makes operations evidence measurable |
| Server restart command missing | Vanilla custom Go server had no restart API/UI and did not send \`ServerToAgentCommand\` | Added pending restart state, API/UI actions, and tests in \`server.go\` | Counts as custom maintenance effort for vanilla |
| Supervisor config rejected \`agent.access_dirs\` | \`opampsupervisor\` 0.151.0 rejected the key at startup | Removed the key from the deployed supervisor config | Documented compatibility friction |
| Versioned deploy override brittle | Environment override of the OCB binary path was unreliable in escalated Ansible runs | Added explicit \`task ansible:collector:supervisor:version VERSION=...\` using an Ansible extra var | Makes downgrade/upgrade repeatable |
| Effective config body incomplete | Server path has desired hash/status, but no full effective config body for supervisor-managed agent | Treat as a vanilla visibility limitation and capture hashes/status instead | Penalizes inventory/config observability |

## Redactions

- Redact public IPs, tokens, Cloud IDs, kubeconfig content, tenant identifiers, and non-synthetic hostnames before publishing.
- Keep anonymized roles, versions, hashes, relative timings, command counts, and status transitions.
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

```sh
task opamp:build
task opamp:supervisor:build:linux
task ocb:build
task collector:env
task ansible:collector:supervisor
task evidence:ops-experience
```

Remote config update:

```sh
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/good-remote-config.yaml
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/bad-remote-config.yaml
./scripts/opamp-assign-config.sh dev lab/configs/opamp-ops/good-remote-config.yaml
```

Restart:

```sh
./scripts/opamp-restart-agent.sh opamp-poc-host-agent
```

Version workflow:

```sh
task ocb:build:version VERSION=0.150.0
COLLECTOR_VERSION=0.150.0 task collector:env
task ansible:collector:supervisor:version VERSION=0.150.0
task ocb:build
COLLECTOR_VERSION=0.151.0 task collector:env
task ansible:collector:supervisor
```

Pre-sweep:

```sh
./scripts/opamp-pre-sweep.sh
```
EOF

cp "$root/lab/configs/opamp-ops/good-remote-config.yaml" "$run_dir/config/good-remote-config.yaml"
cp "$root/lab/configs/opamp-ops/bad-remote-config.yaml" "$run_dir/config/bad-remote-config.yaml"
cp "$root/lab/opamp-supervisor/supervisor.yaml" "$run_dir/config/supervisor-reference.yaml"
if [ -f "$root/tmp/opamp-pre-sweep.csv" ]; then
  cp "$root/tmp/opamp-pre-sweep.csv" "$run_dir/artifacts/opamp-pre-sweep.csv"
fi

git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt" 2>&1 || true
git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt" 2>&1 || true

echo "$run_dir"
