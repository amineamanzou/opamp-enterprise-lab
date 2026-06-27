#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" bindplane-otel)"

mkdir -p "$run_dir/artifacts/browser-use" "$run_dir/config" "$run_dir/screenshots"

git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt"
git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt"

cp "$root/docs/runbooks/bindplane-otel.md" "$run_dir/runbook.md"
cp "$root/lab/configs/bindplane-otel/otelcol-contrib-bindplane-opamp.yaml" "$run_dir/config/otelcol-contrib-bindplane-opamp.yaml"

access_date="$(date -u +%Y-%m-%d)"

cat > "$run_dir/source-baseline.md" <<EOF
# Source Baseline

Access date: ${access_date}

This run is OpenTelemetry-only. Do not install, enroll, or test Elastic Agent.

## Official Bindplane Sources To Capture

| Source | Claim to verify before lab execution | Evidence status |
| --- | --- | --- |
| https://docs.bindplane.com/ | Bindplane is an OpenTelemetry-native telemetry pipeline product and manages collectors through OpAMP. | source-only |
| https://docs.bindplane.com/configuration/bindplane-otel-collector/opamp | Bindplane documents OpAMP configuration for its OTel collector path. | source-only |
| https://docs.bindplane.com/cli-and-api/api-keys | Bindplane API keys can be used for API automation. | source-only |
| https://docs.bindplane.com/cli-and-api/api/agents | Agent/collector inventory is available through API. | source-only |
| https://docs.bindplane.com/cli-and-api/api/configurations | Configurations are available through API. | source-only |
| https://bindplane.com/pricing | Bindplane has Free, Growth, and Enterprise pricing surfaces with telemetry and collector limits. | source-only |

Copy dated notes from these pages here. Keep quotes minimal and prefer paraphrase.
EOF

cat > "$run_dir/browser-use-ui-notes.md" <<'EOF'
# Browser-Use UI Notes

Use the local Chrome profile and capture only sanitized state.

```sh
browser-use --headed --profile Default open "https://app.bindplane.com/"
browser-use --headed --profile Default state > artifacts/browser-use/bindplane-home.state.txt
browser-use --headed --profile Default screenshot
```

Required pages:

- Bindplane home/project page.
- Collector onboarding flow.
- API key flow.
- Collector list and collector detail page.
- Configuration builder and rollout page.
- Health, status, error, and last check-in panels.
- Billing, usage, or plan page if visible.

Capture:

- number of UI actions to onboard the first collector;
- whether upstream `otelcol-contrib` is supported or BDOT is required;
- fields required before Bindplane can generate config;
- whether Bindplane deploys/restarts/upgrades collectors or only configures them;
- whether bad config is blocked before rollout;
- visible plan limits for collectors, volume, users, support, and self-hosting;
- friction caused by Bindplane-specific generated blocks, credentials, or APIs.

Do not commit API keys, tokens, tenant IDs, emails, public IPs, private hostnames, or raw account screenshots.
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

Fill with exact commands run during the lab. Redact tokens, public IPs, tenant IDs, and private hostnames.

## UI Baseline

```sh
browser-use --headed --profile Default open "https://app.bindplane.com/"
browser-use --headed --profile Default state > artifacts/browser-use/bindplane-home.state.txt
```

## Runtime Secret Handling

```sh
umask 077
$EDITOR /tmp/bindplane-otel.env
set -a
. /tmp/bindplane-otel.env
set +a
```

## Collector Startup

```sh
otelcol-contrib --config config/otelcol-contrib-bindplane-opamp.yaml
```

## Validation

```sh
curl -fsS "${OTEL_HEALTH_CHECK_URL}"
```
EOF

cat > "$run_dir/collector-scenarios.md" <<'EOF'
# Collector Functional Scenarios

All scenarios use OpenTelemetry collector binaries only. If BDOT is required, record why upstream `otelcol-contrib` was not enough.

| Scenario | Expected evidence | Result |
| --- | --- | --- |
| First connection | Collector appears in Bindplane without Elastic Agent. | pending |
| Log ingest | Synthetic logs arrive in Elastic through OTLP/HTTP. | pending |
| Remote config | Bindplane changes collector behavior and exposes rollout state. | pending |
| Bad config | Bindplane blocks, reports, or safely recovers from invalid config. | pending |
| Recovery | Collector returns healthy after restoring config. | pending |
| Restart | Status transitions are visible and stable. | pending |
| Disconnect | Offline/stale behavior is visible and understandable. | pending |
| Upgrade | Bindplane owns version change or documents external ownership. | pending |
| Downgrade | Bindplane owns rollback or documents external ownership. | pending |
EOF

cat > "$run_dir/scale-scenarios.md" <<'EOF'
# Collector Scale Scenarios

Run progressive paliers only when onboarding can be automated without violating plan limits.

| Collector count | Expected evidence | UI/API metrics | Result |
| --- | --- | --- | --- |
| 10 | All collectors visible or account limit is explicit. | pending | pending |
| 50 | Inventory and config pages remain usable. | pending | pending |
| 100 | API/UI latency and stale collector behavior recorded. | pending | pending |
| 250 | Optional; run only if plan and automation allow. | pending | pending |
| 500 | Optional; run only if plan and automation allow. | pending | pending |
| 1000 | Optional; run only if plan and automation allow. | pending | pending |
EOF

cat > "$run_dir/switching-frictions.md" <<'EOF'
# Bindplane To OpAMP Switching Frictions

| Area | What to inspect | Friction level | Evidence |
| --- | --- | --- | --- |
| Collector binary | Upstream `otelcol-contrib` versus BDOT requirement. | pending | pending |
| OpAMP endpoint | Endpoint, auth headers, TLS, tenancy, and generated config shape. | pending | pending |
| Remote config | Exportability and portability of generated configs. | pending | pending |
| Rollout safety | Validation, staged rollout, rollback, and bad config behavior. | pending | pending |
| Identity | Stable collector IDs across restart/reinstall/scale. | pending | pending |
| Health | Component health, last check-in, error text, and stale state. | pending | pending |
| Lifecycle | Deploy, restart, upgrade, downgrade, uninstall ownership. | pending | pending |
| Data model | Bindplane-specific attributes, metadata, labels, and API entities. | pending | pending |
| Pricing | Collector, telemetry volume, user, support, and self-hosting limits. | pending | pending |
| Scale operations | API/UI usability and onboarding model at paliers. | pending | pending |

Verdict format:

- Replaceable by OpAMP: yes/no/partial.
- Exit work required: config export, endpoint/auth replacement, identity mapping, dashboards, deploy tooling.
- At-scale risk: plan limits, credential lifecycle, rollout blast radius, stale inventory, API rate limits, and support dependency.
EOF

cat > "$run_dir/bindplane-otel-results.csv" <<'EOF'
scenario,result,collector_count,ui_actions,visible_status,remote_config_editable,logs_visible,recovery_seconds,pricing_limit,notes
first_connection,pending,,,,,,,,
remote_config,pending,,,,,,,,
bad_config,pending,,,,,,,,
restart,pending,,,,,,,,
disconnect,pending,,,,,,,,
upgrade,pending,,,,,,,,
downgrade,pending,,,,,,,,
scale,pending,,,,,,,,
EOF

cat > "$run_dir/run.md" <<'EOF'
# Bindplane OpenTelemetry Evidence Run

This run evaluates Bindplane as a fleet-management control plane for OpenTelemetry collectors only.

Hard rule: do not install or enroll Elastic Agent.

## Summary

- Branch: `scenario/bindplane-otel-experience`
- Collector: upstream `otelcol-contrib` preferred; BDOT only if required
- Elastic Agent used: no
- Bindplane role: OTel collector onboarding, config, health, lifecycle, and scale-management candidate

## Notes

Populate after the lab run with dated observations, screenshots, and redacted command outputs.
EOF

echo "$run_dir"
