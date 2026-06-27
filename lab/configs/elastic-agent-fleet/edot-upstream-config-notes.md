# EDOT and Upstream Collector Config Notes

Use these notes to keep EDOT and upstream Collector comparisons aligned with the OCB variants.

## EDOT Collector Placeholder

Target shape:

- File log input for the same path set as `LOG_FILE_PATHS`.
- OTLP receiver enabled on `4317` and `4318` only if the scenario needs app-sent logs.
- Resource attributes matching the OCB configs:
  - `service.name`
  - `deployment.environment`
  - `elastic.poc.name`
- Elastic OTLP/HTTP exporter configured from environment variables only.

Expected env vars:

- `ELASTIC_OTLP_ENDPOINT`
- `ELASTIC_API_KEY`
- `LOG_FILE_PATHS`
- `SERVICE_NAME`
- `DEPLOYMENT_ENVIRONMENT`
- `POC_NAME`

## Upstream Collector Contrib Placeholder

Use the same logical pipeline as `lab/configs/collector/logs-min-elastic.yaml`:

```text
filelog + otlp -> memory_limiter -> resource -> attributes -> filter -> batch -> otlphttp/elastic
```

When comparing against the OCB builds, pin the upstream Collector Contrib version to the same Collector version as the manifests in `lab/collector-ocb`.
