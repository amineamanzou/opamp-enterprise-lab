# Elastic Fleet OTel-Only Scenario

This branch reproduces the Elastic Fleet OpenTelemetry Collector path without
Elastic Agent enrollment.

## Run

```sh
task ci:local
cp lab/infra/hcloud/terraform.tfvars.example lab/infra/hcloud/terraform.tfvars
$EDITOR lab/infra/hcloud/terraform.tfvars
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
task evidence:elastic-fleet-otel-only
```

Then follow `docs/runbooks/elastic-fleet-otel-only.md`.

## Evidence Goal

Capture whether an upstream `otelcol-contrib` process can appear in Elastic
Fleet through OpAMP, what status/effective-config data is visible, and which
lifecycle operations remain outside Fleet.
