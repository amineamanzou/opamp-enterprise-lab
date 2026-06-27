#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" openlit-opamp)"

mkdir -p "$run_dir/artifacts/browser-use" "$run_dir/config" "$run_dir/screenshots"

git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt"
git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt"

cp "$root/docs/runbooks/openlit-opamp.md" "$run_dir/runbook.md"
cp "$root/lab/configs/openlit-opamp/otelcol-contrib-openlit-opamp.yaml" "$run_dir/config/otelcol-contrib-openlit-opamp.yaml"

access_date="$(date -u +%Y-%m-%d)"

cat > "$run_dir/source-baseline.md" <<EOF
# Source Baseline

Access date: ${access_date}

This run evaluates OpenLit as an OpAMP control-plane candidate for OpenTelemetry collectors. Keep OpenLit Controller/eBPF observations separate from Fleet Hub collector-management observations.

## Official OpenLit Sources To Capture

| Source | Claim to verify before lab execution | Evidence status |
| --- | --- | --- |
| https://docs.openlit.io/latest/overview | OpenLit describes an open-source observability platform focused on AI engineering and OpenTelemetry. | source-only |
| https://docs.openlit.io/latest/openlit/observability/fleet-hub | Fleet Hub is OpenLit's OpenTelemetry Collector fleet-management surface using OpAMP. | source-only |
| https://docs.openlit.io/latest/openlit/installation | OpenLit can be self-hosted, including Docker and Kubernetes deployment paths. | source-only |
| https://docs.openlit.io/latest/controller/overview | OpenLit Controller is a separate runtime/agent surface and must not be conflated with Fleet Hub collector management. | source-only |
| https://github.com/openlit/openlit/blob/main/OPAMP_DEPLOYMENT.md | OpenLit's repository includes an OpAMP deployment guide with TLS/mTLS and collector connection details. | source-only |
| https://openlit.io/pricing | OpenLit has a pricing surface that must be recorded as a dated input, not a permanent procurement claim. | source-only |

Copy dated notes from these pages here. Keep quotes minimal and prefer paraphrase.
EOF

cat > "$run_dir/browser-use-ui-notes.md" <<'EOF'
# Browser-Use UI Notes

Use the local Chrome profile and capture only sanitized state.

```sh
browser-use --headed --profile Default open "<openlit-url>"
browser-use --headed --profile Default state > artifacts/browser-use/openlit-home.state.txt
browser-use --headed --profile Default screenshot
```

Required pages:

- OpenLit home or workspace page.
- Fleet Hub collector list.
- OpAMP endpoint or collector onboarding page.
- Collector detail page.
- Configuration, status, health, and error panels.
- TLS/mTLS or security settings page if visible.
- Pricing, usage, or plan page if visible in the account.

Capture:

- number of UI actions to find Fleet Hub and onboard the first collector;
- whether upstream `otelcol-contrib` is supported or a specific OpenLit distribution is required;
- fields required before OpenLit can generate an OpAMP config;
- whether remote config is editable from Fleet Hub;
- labels for healthy, unhealthy, disconnected, and config-error states;
- whether TLS/mTLS is required, optional, or self-host-only;
- friction caused by OpenLit-specific generated blocks, credentials, Controller concepts, or APIs.

Do not commit API keys, tokens, tenant IDs, emails, public IPs, private hostnames, raw account screenshots, or TLS private keys.
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

Fill with exact commands run during the lab. Redact tokens, public IPs, tenant IDs, private hostnames, and certificate material.

## Source/UI Baseline

```sh
browser-use --headed --profile Default open "<openlit-url>"
browser-use --headed --profile Default state > artifacts/browser-use/openlit-home.state.txt
```

## Runtime Secret Handling

```sh
umask 077
$EDITOR /tmp/openlit-opamp.env
set -a
. /tmp/openlit-opamp.env
set +a
```

## Optional Self-Host Smoke

```sh
docker compose -f <openlit-compose-file> up -d
```

## Collector Startup

```sh
otelcol-contrib --config config/otelcol-contrib-openlit-opamp.yaml
```

## Validation

```sh
curl -fsS "${OTEL_HEALTH_CHECK_URL}"
```
EOF

cat > "$run_dir/collector-scenarios.md" <<'EOF'
# Collector Functional Scenarios

All scenarios use OpenTelemetry collector binaries only. If OpenLit requires a specific distribution or Controller path, record why upstream `otelcol-contrib` was not enough.

| Scenario | Expected evidence | Result |
| --- | --- | --- |
| First connection | Collector appears in OpenLit Fleet Hub without Elastic Agent. | pending |
| Log ingest | Synthetic logs arrive in Elastic through OTLP/HTTP. | pending |
| Remote config | OpenLit changes collector behavior and exposes desired/effective state. | pending |
| Bad config | OpenLit blocks, reports, or safely recovers from invalid config. | pending |
| Recovery | Collector returns healthy after restoring config. | pending |
| Restart | Status transitions are visible and stable. | pending |
| Disconnect | Offline/stale behavior is visible and understandable. | pending |
| TLS/mTLS | TLS or mTLS setup works, or the limitation is documented. | pending |
| Controller boundary | Controller capabilities are documented separately from Fleet Hub. | pending |
EOF

cat > "$run_dir/maintainability-scenarios.md" <<'EOF'
# Functional And Maintainability Scenarios

Do not run OpenLit volumetry paliers in this scenario. OpenLit Fleet Hub uses an OpAMP server implementation underneath; this pass evaluates product completeness, maintainability, and day-2 operator workflow rather than protocol fan-out.

| Area | What to inspect | Result |
| --- | --- | --- |
| Local deployment | Image size, port conflicts, required overrides, startup friction, and health checks. | pending |
| Authentication | First local account flow, session reuse, and whether screenshots can be sanitized. | pending |
| Fleet inventory | Collector list fields, stable identity, version, OS, started time, and health status. | pending |
| Collector detail | Detail fields, show-more data, component health, effective config, and custom config editor. | pending |
| Remote config safety | YAML validation, non-map rejection, save behavior, timeout behavior, and rollback affordance. | pending |
| TLS operations | Development TLS, mTLS production mode, certificate extraction, TLS min-version offer, and reconnect behavior. | pending |
| API/UI alignment | Whether API data and UI panels expose the same effective/custom config information. | pending |
| Exit friction | Endpoint replacement, certificate replacement, config export, and lifecycle ownership outside OpenLit. | pending |
EOF

cat > "$run_dir/switching-frictions.md" <<'EOF'
# OpenLit To OpAMP Switching Frictions

| Area | What to inspect | Friction level | Evidence |
| --- | --- | --- | --- |
| Collector binary | Upstream `otelcol-contrib` versus OpenLit-specific distribution requirement. | pending | pending |
| OpAMP endpoint | Endpoint, auth headers, TLS/mTLS, tenancy, and generated config shape. | pending | pending |
| Remote config | Exportability and portability of generated configs. | pending | pending |
| Rollout safety | Validation, staged rollout, rollback, and bad config behavior. | pending | pending |
| Identity | Stable collector IDs across restart/reinstall/scale. | pending | pending |
| Health | Component health, last check-in, error text, and stale state. | pending | pending |
| Lifecycle | Deploy, restart, upgrade, downgrade, uninstall ownership. | pending | pending |
| Controller coupling | Whether OpenLit Controller concepts are required for collector fleet management. | pending | pending |
| Data model | OpenLit-specific attributes, metadata, labels, and API entities. | pending | pending |
| Pricing | Collector, telemetry volume, user, support, cloud, and self-hosting limits. | pending | pending |
| Scale operations | API/UI usability and onboarding model at paliers. | pending | pending |

Verdict format:

- Replaceable by OpAMP: yes/no/partial.
- Exit work required: config export, endpoint/auth replacement, identity mapping, dashboards, deploy tooling.
- At-scale risk: plan limits, credential lifecycle, TLS/mTLS operations, rollout blast radius, stale inventory, API rate limits, and support dependency.
EOF

cat > "$run_dir/openlit-opamp-results.csv" <<'EOF'
scenario,result,collector_count,ui_actions,visible_status,remote_config_editable,logs_visible,recovery_seconds,pricing_limit,notes
first_connection,pending,,,,,,,,
remote_config,pending,,,,,,,,
bad_config,pending,,,,,,,,
restart,pending,,,,,,,,
disconnect,pending,,,,,,,,
tls_mtls,pending,,,,,,,,
controller_boundary,pending,,,,,,,,
EOF

cat > "$run_dir/run.md" <<'EOF'
# OpenLit OpAMP Evidence Run

This run evaluates OpenLit Fleet Hub as a fleet-management control plane for OpenTelemetry collectors.

Hard rule: keep Fleet Hub and OpenLit Controller findings separate.

## Summary

- Branch: `scenario/openlit-opamp-analysis`
- Collector: upstream `otelcol-contrib` preferred; OpenLit-specific distribution only if required
- Elastic Agent used: no
- OpenLit role: OpAMP collector onboarding, config, health, lifecycle, TLS/mTLS, and scale-management candidate

## Notes

Populate after the lab run with dated observations, screenshots, and redacted command outputs.
EOF

echo "$run_dir"
