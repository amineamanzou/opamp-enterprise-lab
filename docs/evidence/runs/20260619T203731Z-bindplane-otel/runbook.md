# Bindplane OpenTelemetry Runbook

This scenario evaluates Bindplane as a fleet-management product for OpenTelemetry collectors and compares it with Elastic Fleet OTel-only, custom OpAMP Go, and the lab-modified `opamp-server-py`.

Hard rule: keep the scenario OpenTelemetry-only. Do not install Elastic Agent. Prefer upstream `otelcol-contrib`; if Bindplane requires Bindplane Distribution for OpenTelemetry Collector (BDOT), record it as product coupling and verify whether the generated collector configuration remains portable OpenTelemetry.

## Source Baseline

Capture dated notes from:

- https://docs.bindplane.com/
- https://docs.bindplane.com/configuration/bindplane-otel-collector/opamp
- https://docs.bindplane.com/cli-and-api/api-keys
- https://docs.bindplane.com/cli-and-api/api/agents
- https://docs.bindplane.com/cli-and-api/api/configurations
- https://bindplane.com/pricing

Record whether the docs describe collector onboarding, OpAMP, remote configuration, rollout validation, collector state, upgrade/downgrade, API automation, pricing limits, and self-hosting options.

## Prepare Evidence

```sh
task evidence:bindplane-otel
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
browser-use --headed --profile Default open "https://app.bindplane.com/"
browser-use --headed --profile Default state > artifacts/browser-use/bindplane-home.state.txt
browser-use --headed --profile Default screenshot
```

Inspect:

- organization or project landing page;
- collector onboarding flow;
- API key creation/view flow;
- collector detail page;
- configuration builder;
- rollout, validation, or deployment status page;
- health, error, and last check-in states;
- plan, billing, or usage pages visible in the account.

Do not commit API keys, bearer tokens, tenant IDs, emails, public IPs, private hostnames, or screenshots containing secrets. Store runtime credentials in `/tmp/bindplane-otel.env` or `secrets/bindplane.env`.

## Required Runtime Values

Secret or tenant-specific values must stay outside Git:

```sh
export BINDPLANE_ENDPOINT=<bindplane-server-or-cloud-url>
export BINDPLANE_API_KEY=<bindplane-api-key>
export BINDPLANE_OPAMP_ENDPOINT=<collector-opamp-endpoint-from-ui-or-api>
export BINDPLANE_OPAMP_HEADERS=<redacted-auth-headers-from-ui-or-api>
export ELASTIC_OTLP_ENDPOINT=<elastic-otlp-endpoint>
export ELASTIC_API_KEY=<elastic-api-key>
```

Non-secret lab values:

```sh
export SERVICE_NAME=bindplane-otel-collector
export SERVICE_INSTANCE_ID=bindplane-host-001
export LOG_FILE_PATHS=/var/log/opamp-poc/synthetic.log
export HOST_NAME=asset-000001.example.invalid
export DEPLOYMENT_ENVIRONMENT=lab
export POC_NAME=bindplane-otel
```

## Functional Tests

1. First connection: collector appears in Bindplane without Elastic Agent.
2. Log ingest: synthetic logs arrive in Elastic through OTLP/HTTP with `fleet.scenario.name: bindplane-otel`.
3. Remote config: change a safe processor or resource attribute through Bindplane and verify the effective collector behavior.
4. Bad config: push a safe invalid config and record whether Bindplane blocks rollout, marks an error, or lets the collector fail.
5. Recovery: restore known-good config and measure time to healthy.
6. Restart: restart collector and measure Bindplane status transitions.
7. Disconnect: stop or block collector OpAMP connectivity and measure offline/stale behavior.
8. Upgrade/downgrade: test only if Bindplane exposes collector version lifecycle for the selected collector path.
9. Scale: run `10`, `50`, `100`, then `250/500/1000` only if onboarding and account limits support automation without violating terms.

## Comparison Questions

- Does Bindplane manage upstream `otelcol-contrib`, BDOT only, or both?
- Which generated config blocks are portable OpenTelemetry and which are Bindplane-specific?
- Can configs be exported and reapplied to a custom OpAMP-managed collector?
- Does Bindplane own deployment, restart, upgrade/downgrade, uninstall, and stale collector cleanup?
- Are bad configs blocked before rollout or detected after collector failure?
- Is onboarding reusable at scale, or does it require per-collector manual/API work?
- Which pricing limits matter first: connected collectors, telemetry volume, users, support tier, or self-hosting?

## Verdict Format

End the evidence run with:

- replaceable by OpAMP: yes, no, or partial;
- exit work required;
- at-scale risks;
- UX/maintainer friction;
- pricing and plan-limit impact;
- missing Bindplane capabilities compared with OpAMP Go/Python;
- missing OpAMP Go/Python capabilities compared with Bindplane.
