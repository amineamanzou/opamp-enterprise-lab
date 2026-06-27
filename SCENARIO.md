# OpenLit OpAMP Scenario

This branch evaluates OpenLit Fleet Hub as an OpAMP-facing
OpenTelemetry Collector management surface.

## Run

```sh
task ci:local
cp lab/infra/hcloud/terraform.tfvars.example lab/infra/hcloud/terraform.tfvars
$EDITOR lab/infra/hcloud/terraform.tfvars
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
task evidence:openlit-opamp
```

Then follow `docs/runbooks/openlit-opamp.md`.

## Evidence Goal

Capture first connection, Fleet Hub inventory, effective config, remote config
guardrails, restart/disconnect behavior, TLS/mTLS operations, Controller
boundary, browser asset/CSP maintainability, and switching friction back to a
direct OpAMP collector-management path.

OpenLit volumetry paliers are deliberately out of scope on this branch; protocol
fan-out belongs to the lower-level OpAMP implementation tests.
