# Bindplane OTel Scenario

This branch reproduces the Bindplane/BDOT collector-management experiment and
captures switching friction back to the lab OpAMP path.

## Run

```sh
task ci:local
cp lab/infra/hcloud/terraform.tfvars.example lab/infra/hcloud/terraform.tfvars
$EDITOR lab/infra/hcloud/terraform.tfvars
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
task evidence:bindplane-otel
```

Then follow `docs/runbooks/bindplane-otel.md`.

## Evidence Goal

Capture onboarding, inventory, source/destination configuration, connection
health, restart/disconnect behavior, generated command friction, and what must
be rebuilt when exiting Bindplane for a direct OpAMP collector path.
