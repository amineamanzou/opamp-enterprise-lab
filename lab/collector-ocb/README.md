# Logs-Only OCB Distributions

This directory contains OpenTelemetry Collector Builder manifests for the logs POC.

## Manifests

- `otelcol-logs-min.yaml`: filelog and OTLP receivers, memory limiter, batch, resource, attributes, filter, OTLP/HTTP and Kafka exporters, and health check.
- `otelcol-logs-opamp.yaml`: same component set plus the OpAMP extension.

## Build

Use a pinned Collector Builder matching the manifest version. The lab build targets Linux AMD64 hosts:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 ocb --config lab/collector-ocb/otelcol-logs-min.yaml
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 ocb --config lab/collector-ocb/otelcol-logs-opamp.yaml
```

The manifests currently pin Collector modules to `v0.151.0`. Update all module versions together when changing the target Collector version.
