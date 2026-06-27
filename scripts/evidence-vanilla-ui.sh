#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" vanilla-ui)"
mkdir -p "$run_dir/artifacts" "$run_dir/screenshots" "$run_dir/logs"

base_url="${OPAMP_VANILLA_UI_URL:-http://127.0.0.1:4321}"

cat > "$run_dir/run.md" <<EOF
# Vanilla OpAMP UI Evidence Run

- Created at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Scenario: custom Go OpAMP vanilla server
- Evidence label: custom-go-opamp
- UI base URL: \`$base_url\`

## Screenshots To Attach

- \`screenshots/vanilla-root.png\`: root Agents page.
- \`screenshots/vanilla-agent-detail.png\`: agent detail page after redaction.

## API/HTML Artifacts

- \`artifacts/root.html\`
- \`artifacts/inventory.json\`
- \`artifacts/connections.json\`

## Feature Notes

- Implemented: agent list, agent detail, effective config display, remote config form, links to JSON inventory/connections.
- Not implemented in vanilla POC V1: client certificate rotation, OpAMP connection settings offers, and custom messages from the upstream example UI.

## Redaction Rules

- Remove public IP addresses, private hostnames, tokens, Cloud IDs, kubeconfig content, and tenant identifiers before publishing screenshots or copied logs.
- Keep product versions, scenario labels, command counts, anonymized host roles, and relative timestamps.
EOF

cat > "$run_dir/operator-notes.md" <<'EOF'
# Operator Notes

## UI Walkthrough

- Root Agents page:
- Agent detail page:
- Remote config form:
- JSON inventory/connections links:

## Redactions Applied

- Screenshots:
- HTML:
- JSON:

## Comparison Notes

- Setup effort:
- UI actions:
- Failure or missing feature notes:
EOF

if command -v curl >/dev/null 2>&1; then
  curl -fsS "$base_url/" > "$run_dir/artifacts/root.html" 2>/dev/null || true
  curl -fsS "$base_url/v1/inventory" > "$run_dir/artifacts/inventory.json" 2>/dev/null || true
  curl -fsS "$base_url/v1/opamp/connections" > "$run_dir/artifacts/connections.json" 2>/dev/null || true
fi

if command -v git >/dev/null 2>&1; then
  git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt" 2>&1 || true
  git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt" 2>&1 || true
fi

echo "$run_dir"
