# Elastic Fleet OTel-Only Scenario

This directory is for the Fleet/OpenTelemetry scenario where the managed process is an OpenTelemetry Collector, not Elastic Agent.

Rules:

- Do not install or enroll Elastic Agent.
- Start with upstream `otelcol-contrib`.
- Treat EDOT Collector as a secondary comparison only if the upstream collector path is blocked.
- Keep Fleet-generated tokens and tenant identifiers outside the repository.

The operator should use Kibana Fleet's OpenTelemetry Collector / OpAMP flow to obtain the Fleet Server endpoint and auth header, then provide them as environment variables to the collector.
