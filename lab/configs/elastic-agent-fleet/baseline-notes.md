# Elastic Agent / Fleet Baseline

Purpose: provide a comparison baseline for the custom OCB logs-only collectors in `lab/collector-ocb`.

## Elastic Cloud Trial Setup

- Create a temporary Elastic Cloud deployment for the POC.
- Enable Fleet Server and collect the Fleet URL and enrollment token out-of-band.
- Store enrollment tokens, API keys, and Cloud IDs only in the operator environment or a local ignored secret store.
- Use Elastic Observability's OTLP ingest endpoint for the OCB collectors with:
  - `ELASTIC_OTLP_ENDPOINT`
  - `ELASTIC_API_KEY`

## Elastic Agent Baseline

Recommended baseline scenarios:

1. Elastic Agent managed by Fleet, logs integration enabled.
2. Elastic Agent standalone with equivalent file log input if Fleet control-plane overhead must be isolated.
3. EDOT Collector, if available in the trial account, configured for the same source paths and Elastic destination.
4. Upstream OpenTelemetry Collector Contrib with the same filelog and OTLP/HTTP pipeline.

Capture the same measurements for every variant:

- Binary size or installed package size.
- Container image size.
- RSS after idle stabilization.
- RSS during sustained log load.
- CPU during sustained log load.
- Startup time until health endpoint is ready.
- Throughput before first loss, queue saturation, or exporter backpressure.
- Notes on remote management capabilities and config drift behavior.

## No-Secret Policy

Do not commit:

- Fleet enrollment tokens.
- Elastic API keys.
- Cloud IDs if they identify a real deployment.
- Agent diagnostics bundles containing credentials or host identifiers.
