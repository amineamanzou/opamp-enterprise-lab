#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" elastic-fleet-otel-only)"

mkdir -p "$run_dir/artifacts/browser-use" "$run_dir/config" "$run_dir/screenshots"

git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt"
git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt"

cp "$root/docs/runbooks/elastic-fleet-otel-only.md" "$run_dir/runbook.md"
cp "$root/lab/configs/elastic-fleet-otel-only/otelcol-contrib-fleet-opamp.yaml" "$run_dir/config/otelcol-contrib-fleet-opamp.yaml"

access_date="$(date -u +%Y-%m-%d)"

cat > "$run_dir/source-baseline.md" <<EOF
# Source Baseline

Access date: ${access_date}

This run is OTel-only. Do not install, enroll, or test Elastic Agent.

## Official Elastic Sources To Capture

| Source | Claim to verify before lab execution | Evidence status |
| --- | --- | --- |
| https://www.elastic.co/docs/reference/fleet/monitor-otel-collectors | Fleet can monitor OpenTelemetry Collectors through OpAMP. | source-only |
| https://www.elastic.co/docs/reference/fleet/add-otel-collector | Kibana/Fleet provides an add-collector flow that generates OpenTelemetry Collector configuration. | source-only |
| https://www.elastic.co/docs/reference/fleet/view-otel-collectors | OTel collectors can be viewed in Fleet with status/config visibility, subject to documented limitations. | source-only |

Copy short dated notes from these pages here. Keep quotes minimal and prefer paraphrase.
EOF

cat > "$run_dir/browser-use-ui-notes.md" <<'EOF'
# Browser-Use UI Notes

Use the local Chrome profile and capture only sanitized state.

```sh
browser-use --headed --profile Default open "<kibana-url>/app/fleet"
browser-use --headed --profile Default state > artifacts/browser-use/fleet-home.state.txt
browser-use --headed --profile Default screenshot
```

Required pages:

- Fleet agents list filtered to OpenTelemetry collectors.
- Add Collector / OpAMP flow.
- Generated collector configuration page.
- Collector detail page.
- Any status, health, effective config, or error panels.

Capture:

- number of UI actions to find the OTel collector flow;
- fields required before Fleet can generate config;
- whether the UI clearly says Fleet does not deploy the collector;
- whether remote config is editable from Fleet for OTel collectors;
- labels for Healthy, Unhealthy, Offline, and config errors;
- friction caused by Elastic-specific names, tokens, or integrations.
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

Fill with exact commands run during the lab. Redact tokens, public IPs, tenant IDs, and private hostnames.

## Source/UI Baseline

```sh
browser-use --headed --profile Default open "<kibana-url>/app/fleet"
browser-use --headed --profile Default state > artifacts/browser-use/fleet-home.state.txt
```

## Collector Startup

```sh
otelcol-contrib --config config/otelcol-contrib-fleet-opamp.yaml
```

## Validation

```sh
curl -fsS "${OTEL_HEALTH_CHECK_URL}"
```
EOF

cat > "$run_dir/collector-scenarios.md" <<'EOF'
# Collector Scenarios

All scenarios use OpenTelemetry Collector binaries only.

| Scenario | Expected evidence | Result |
| --- | --- | --- |
| First connection | Collector appears in Fleet without Elastic Agent enrollment. | pending |
| Log ingest | Synthetic logs continue to arrive in Elastic through OTLP/HTTP. | pending |
| Bad config | Fleet exposes a useful component or config error. | pending |
| Recovery | Collector returns healthy after restoring config. | pending |
| Restart | Fleet status transitions and returns healthy. | pending |
| Disconnect | Fleet reports stale/offline state after OpAMP connectivity loss. | pending |
| Scale step | UI/API remains usable at the selected collector count. | pending |
EOF

cat > "$run_dir/switching-frictions.md" <<'EOF'
# Fleet OTel-Only To OpAMP Switching Frictions

| Area | What to inspect | Friction level | Evidence |
| --- | --- | --- | --- |
| Collector binary | Confirm whether upstream `otelcol-contrib` is enough or EDOT is required. | pending | pending |
| OpAMP endpoint | Identify Fleet Server endpoint, auth header, TLS requirements, and config shape. | pending | pending |
| Remote config | Verify whether Fleet can push editable remote config to OTel collectors or only view generated/effective config. | pending | pending |
| Identity | Compare Fleet collector identity with OpAMP instance UID/resource attributes. | pending | pending |
| Health | Compare component-level health, delays, and error text with custom OpAMP evidence. | pending | pending |
| Data model | List Elastic-specific data streams, attributes, dashboards, and alerts introduced by the Fleet flow. | pending | pending |
| Lifecycle | Confirm Fleet does not deploy, restart, upgrade, or uninstall OTel collectors without another tool. | pending | pending |
| Scale operations | Measure UI/API usability under collector count growth. | pending | pending |

Verdict format:

- Replaceable by OpAMP: yes/no/partial.
- Exit work required: config edits, token rotation, dashboards/data view changes, deployment tooling changes.
- At-scale risk: operational ownership, policy drift, status gaps, and rollout/recovery limits.
EOF

cat > "$run_dir/fleet-otel-only-results.csv" <<'EOF'
scenario,result,collector_count,ui_actions,visible_status,remote_config_editable,logs_visible,recovery_seconds,notes
first_connection,pending,,,,,,,
bad_config,pending,,,,,,,
restart,pending,,,,,,,
disconnect,pending,,,,,,,
scale,pending,,,,,,,
EOF

cat > "$run_dir/run.md" <<'EOF'
# Elastic Fleet OTel-Only Evidence Run

This run evaluates Fleet as an OpAMP-facing UI/control-plane surface for OpenTelemetry Collectors only.

Hard rule: do not install or enroll Elastic Agent.

## Summary

- Branch: `scenario/elastic-fleet-otel-only-experience`
- Collector: upstream `otelcol-contrib` unless explicitly noted
- Elastic Agent used: no
- Fleet role: OpAMP endpoint/UI for OTel collector visibility

## Notes

Populate after the lab run with dated observations, screenshots, and redacted command outputs.
EOF

echo "$run_dir"
