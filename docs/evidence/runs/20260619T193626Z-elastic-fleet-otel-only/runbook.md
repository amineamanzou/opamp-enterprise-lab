# Elastic Fleet OTel-Only Runbook

This scenario evaluates Elastic Fleet only as an OpAMP-facing UI and control-plane surface for OpenTelemetry Collectors.

Hard rule: do not install, enroll, or test Elastic Agent. If a Kibana flow switches to Elastic Agent enrollment, stop and record it as friction.

## Scope

- Target collector: upstream `otelcol-contrib`.
- Optional secondary collector: EDOT Collector, only if the upstream path is blocked.
- Backend: existing Elastic Cloud OTLP endpoint.
- UI evidence: Kibana Fleet inspected with `browser-use`.
- Management question: can this Fleet component be replaced by the lab OpAMP server without reworking the collector fleet?

## Source Baseline

Before lab execution, capture dated notes from:

- https://www.elastic.co/docs/reference/fleet/monitor-otel-collectors
- https://www.elastic.co/docs/reference/fleet/add-otel-collector
- https://www.elastic.co/docs/reference/fleet/view-otel-collectors

Record whether the docs describe monitoring only, generated collector config, effective config visibility, remote config editing, health/status, and deployment lifecycle.

## Prepare Evidence

```sh
task evidence:elastic-fleet-otel-only
```

The task creates a run folder with:

- source baseline template;
- browser-use notes;
- OTel collector config template;
- switching-friction matrix;
- scenario results CSV.

## Browser-Use UI Pass

Use the local Chrome profile and capture sanitized state only:

```sh
browser-use --headed --profile Default open "<kibana-url>/app/fleet"
browser-use --headed --profile Default state > artifacts/browser-use/fleet-home.state.txt
browser-use --headed --profile Default screenshot
```

Inspect:

- Fleet agents list and filters for OpenTelemetry collectors;
- Add OpenTelemetry Collector / OpAMP flow;
- generated YAML;
- collector detail page;
- health, effective config, component status, and errors;
- whether any action requires Elastic Agent.

## Collector Startup

Use `lab/configs/elastic-fleet-otel-only/otelcol-contrib-fleet-opamp.yaml`.

Required non-secret environment values:

```sh
export OTEL_HEALTH_CHECK_ENDPOINT=127.0.0.1:13133
export OTEL_OTLP_GRPC_ENDPOINT=127.0.0.1:4317
export OTEL_OTLP_HTTP_ENDPOINT=127.0.0.1:4318
export LOG_FILE_PATHS=/var/log/opamp-poc/synthetic.log
export SERVICE_INSTANCE_ID=otel-fleet-host-001
export SERVICE_NAME=otelcol-contrib-fleet
export COLLECTOR_VERSION=<otelcol-version>
export HOST_NAME=asset-000001.example.invalid
export DEPLOYMENT_ENVIRONMENT=lab
export OPAMP_RING=dev
export POC_NAME=elastic-fleet-otel-only
```

Required secret or tenant-specific values must stay outside Git:

```sh
export FLEET_OPAMP_HTTP_ENDPOINT=<from-kibana-fleet-otel-flow>
export FLEET_OPAMP_AUTH_HEADER=<from-kibana-fleet-otel-flow>
export FLEET_OPAMP_INSTANCE_UID=<stable-collector-uuid>
export ELASTIC_OTLP_ENDPOINT=<elastic-otlp-endpoint>
export ELASTIC_API_KEY=<elastic-api-key>
```

Run:

```sh
otelcol-contrib --config lab/configs/elastic-fleet-otel-only/otelcol-contrib-fleet-opamp.yaml
```

## Functional Tests

1. First connection: collector appears in Fleet without Elastic Agent enrollment.
2. Log ingest: synthetic logs arrive through OTLP/HTTP with `fleet.scenario.name: elastic-fleet-otel-only`.
3. Bad config: break a safe component, then capture Fleet and collector error surfaces.
4. Recovery: restore config and measure time to healthy.
5. Restart: restart collector and measure Fleet status transitions.
6. Disconnect: block or stop the OpAMP connection and measure offline/stale behavior.
7. Scale: repeat at the same collector-count paliers used for OpAMP where the lab can provision enough OTel collectors.

## Switching Frictions To Capture

- Does Fleet push remote config, or only generate/view collector config?
- Is `otelcol-contrib` sufficient, or does the flow require EDOT-specific behavior?
- Which config blocks are Elastic-specific and must be removed to move to another OpAMP server?
- Are identity, health, effective config, and component errors portable to our OpAMP evidence model?
- Which dashboards, data streams, attributes, and alerts become Elastic-specific coupling?
- Does Fleet provide deploy/restart/upgrade/uninstall for OTel collectors, or is external automation still required?

## Verdict Format

End the evidence run with:

- replaceable by OpAMP: yes, no, or partial;
- exit work required;
- at-scale risks;
- UX/maintainer friction;
- missing Fleet capabilities compared with the lab OpAMP server;
- missing lab OpAMP capabilities compared with Fleet UI.
