# Elastic Fleet OTel-Only Evidence Run

This run evaluates Fleet as an OpAMP-facing UI/control-plane surface for OpenTelemetry Collectors only.

Hard rule: do not install or enroll Elastic Agent.

## Summary

- Branch: `scenario/elastic-fleet-otel-only-experience`
- Collector: upstream `otelcol-contrib` unless explicitly noted
- Elastic Agent used: no
- Fleet role: OpAMP endpoint/UI for OTel collector visibility

## Notes

## Result Summary

- Single upstream `otelcol-contrib` 0.151.0 connected to Fleet through OpAMP without Elastic Agent.
- Fleet UI confirmed the connection and displayed the collector in the Agents list as healthy.
- Elastic ingest was confirmed through `logs-generic.otel-*` with `resource.attributes.fleet.scenario.name=elastic-fleet-otel-only`.
- Effective config and component health were visible in Fleet.
- Fleet did not provide an editable remote policy path for the OTel collector.
- Restart revealed an identity requirement: without stable `instance_uid`, Fleet created duplicate stale rows. The scenario template now requires `FLEET_OPAMP_INSTANCE_UID`.
- Stop/reconnect behavior was visible: the stable collector became offline after the service was stopped and returned healthy after start.
- Bad config handling is external: `otelcol-contrib validate` and systemd catch failures; Fleet observes the resulting connectivity/health, but does not own rollout.
- Scale-10 was blocked by credential/onboarding friction: after fixing collector config and telemetry port conflicts, extra collectors received OpAMP `401` when reusing the generated credential.

## Verdict

Replaceability by OpAMP: partial.

Fleet OTel-only is closer to a monitoring UI for OpAMP-enabled collectors than a full fleet management plane. Replacing it with another OpAMP server is plausible for inventory, health, and effective config visibility, but the team must own deployment, restart, config validation, upgrade, token lifecycle, stable instance IDs, dashboards, and scale onboarding.
