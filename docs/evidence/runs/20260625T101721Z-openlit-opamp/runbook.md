# OpenLit OpAMP Runbook

This scenario evaluates OpenLit Fleet Hub as an OpAMP-facing control-plane surface for OpenTelemetry Collectors and compares it with Elastic Fleet OTel-only, Bindplane, custom OpAMP Go, and the lab-modified `opamp-server-py`.

Hard rule: keep OpenLit Fleet Hub evidence separate from OpenLit Controller evidence. Fleet Hub is the collector-management candidate. Controller may be useful context, but it is not the same management surface.

## Source Baseline

Capture dated notes from:

- https://docs.openlit.io/latest/overview
- https://docs.openlit.io/latest/openlit/observability/fleet-hub
- https://docs.openlit.io/latest/openlit/installation
- https://docs.openlit.io/latest/controller/overview
- https://github.com/openlit/openlit/blob/main/OPAMP_DEPLOYMENT.md
- https://openlit.io/pricing

Record whether the docs describe collector onboarding, OpAMP endpoint shape, TLS/mTLS, remote configuration, rollout validation, collector state, upgrade/downgrade, API automation, pricing limits, and self-hosting options.

## Prepare Evidence

```sh
task evidence:openlit-opamp
```

The task creates a run folder with:

- source baseline template;
- browser-use notes;
- sanitized config template;
- functional scenario matrix;
- scale scenario matrix;
- switching-friction matrix.

## Browser-Use UI Pass

Use the local Chrome profile and capture sanitized state only:

```sh
browser-use --headed --profile Default open "<openlit-url>"
browser-use --headed --profile Default state > artifacts/browser-use/openlit-home.state.txt
browser-use --headed --profile Default screenshot
```

Inspect:

- workspace or project landing page;
- Fleet Hub collector list;
- collector onboarding flow;
- OpAMP endpoint, auth, and TLS/mTLS instructions;
- collector detail page;
- configuration editor or generated config view;
- rollout, validation, health, error, and last check-in states;
- plan, billing, or usage pages visible in the account.

Do not commit API keys, bearer tokens, tenant IDs, emails, public IPs, private hostnames, TLS private keys, or screenshots containing secrets. Store runtime credentials in `/tmp/openlit-opamp.env` or a local ignored secret file.

## Required Runtime Values

Secret or tenant-specific values must stay outside Git:

```sh
export OPENLIT_OPAMP_ENDPOINT=<openlit-opamp-endpoint>
export OPENLIT_OPAMP_AUTH_HEADER=<redacted-auth-header-if-required>
export OPENLIT_OPAMP_INSTANCE_UID=<stable-collector-uuid>
export OPENLIT_OPAMP_CA_FILE=<optional-ca-file-outside-git>
export OPENLIT_OPAMP_CERT_FILE=<optional-client-cert-outside-git>
export OPENLIT_OPAMP_KEY_FILE=<optional-client-key-outside-git>
export ELASTIC_OTLP_ENDPOINT=<elastic-otlp-endpoint>
export ELASTIC_API_KEY=<elastic-api-key>
```

Non-secret lab values:

```sh
export OTEL_HEALTH_CHECK_ENDPOINT=localhost:13133
export OTEL_OTLP_GRPC_ENDPOINT=localhost:4317
export OTEL_OTLP_HTTP_ENDPOINT=localhost:4318
export LOG_FILE_PATHS=/var/log/opamp-poc/synthetic.log
export SERVICE_INSTANCE_ID=openlit-host-001
export SERVICE_NAME=otelcol-contrib-openlit
export COLLECTOR_VERSION=<otelcol-version>
export HOST_NAME=asset-000001.example.invalid
export DEPLOYMENT_ENVIRONMENT=lab
export OPAMP_RING=dev
export POC_NAME=openlit-opamp
```

Run:

```sh
otelcol-contrib --config lab/configs/openlit-opamp/otelcol-contrib-openlit-opamp.yaml
```

## Functional Tests

1. First connection: collector appears in OpenLit Fleet Hub without Elastic Agent.
2. Log ingest: synthetic logs arrive through OTLP/HTTP with `fleet.scenario.name: openlit-opamp`.
3. Remote config: change a safe processor or resource attribute through OpenLit and verify desired/effective behavior.
4. Bad config: push a safe invalid config and record whether OpenLit blocks rollout, marks an error, or lets the collector fail.
5. Recovery: restore known-good config and measure time to healthy.
6. Restart: restart collector and measure OpenLit status transitions.
7. Disconnect: block or stop the OpAMP connection and measure offline/stale behavior.
8. TLS/mTLS: test only after secret and certificate redaction paths are clear.
9. Scale: run `10`, `50`, `100`, then `250/500/1000` only if onboarding and account/resource limits support automation without violating terms.

## Comparison Questions

- Does OpenLit manage upstream `otelcol-contrib`, require an OpenLit distribution, or depend on Controller?
- Which generated config blocks are portable OpenTelemetry and which are OpenLit-specific?
- Can configs be exported and reapplied to a custom OpAMP-managed collector?
- Does OpenLit own deployment, restart, upgrade/downgrade, uninstall, and stale collector cleanup?
- Are bad configs blocked before rollout or detected after collector failure?
- Is onboarding reusable at scale, or does it require per-collector manual/API work?
- Which TLS/mTLS operations become day-2 work: certificate issuance, rotation, revocation, and debugging?
- Which pricing limits matter first: connected collectors, telemetry volume, users, cloud tier, support tier, or self-hosting?

## Verdict Format

End the evidence run with:

- replaceable by OpAMP: yes, no, or partial;
- exit work required;
- at-scale risks;
- UX/maintainer friction;
- pricing and plan-limit impact;
- missing OpenLit capabilities compared with OpAMP Go/Python;
- missing OpAMP Go/Python capabilities compared with OpenLit.
