#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" agent-scale)"
mkdir -p "$run_dir/artifacts" "$run_dir/logs"

cat > "$run_dir/run.md" <<EOF
# OpAMP Agent Scale Evidence Run

- Created at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Scenario: vanilla custom Go OpAMP server with mock OpAMP agent swarm
- Evidence label: custom-go-opamp-agent-scale
- Branch: $(git -C "$root" branch --show-current 2>/dev/null || echo unknown)
- Commit: $(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)

## Purpose

Measure how many concurrent OpAMP agents the vanilla server can inventory and keep connected on the current lab infra.

## Notes

- Mock agents use real OpAMP WebSocket clients and report description, health, heartbeat, remote config status, and effective config.
- This measures control-plane connection/inventory pressure, not collector CPU, log ingestion, or Elastic throughput.
- Redact public IPs, tokens, Cloud IDs, kubeconfig content, and non-synthetic hostnames before publishing.
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

```sh
task opamp:agent-swarm:build
task opamp:scale:agents
task evidence:agent-scale
```

Override defaults:

```sh
OPAMP_AGENT_SCALE_COUNTS="100 250 500 1000 2000 5000" \
OPAMP_AGENT_SCALE_DURATION=5m \
OPAMP_AGENT_SCALE_RAMP_PER_SECOND=50 \
task opamp:scale:agents
```
EOF

latest_scale_dir="$(find "$root/tmp" -maxdepth 1 -type d -name 'opamp-agent-scale-*' 2>/dev/null | sort | tail -n 1 || true)"
if [ -n "$latest_scale_dir" ]; then
  cp "$latest_scale_dir"/*.csv "$run_dir/artifacts/" 2>/dev/null || true
  cp "$latest_scale_dir"/*.json "$run_dir/artifacts/" 2>/dev/null || true
fi

git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt" 2>&1 || true
git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt" 2>&1 || true

echo "$run_dir"
