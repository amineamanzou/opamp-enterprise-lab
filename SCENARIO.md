# Exit Drill, Secrets, And Outage Scenario

This branch reproduces the exit and outage evidence path across managed and
direct OpAMP collector-management approaches.

## Run

```sh
task ci:local
cp lab/infra/hcloud/terraform.tfvars.example lab/infra/hcloud/terraform.tfvars
$EDITOR lab/infra/hcloud/terraform.tfvars
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
task evidence:exit-drill-secrets-outage
```

Then follow `docs/runbooks/exit-drill-secrets-outage.md`.

## Evidence Goal

Capture what remains after switching control planes: credentials, generated
configs, stale inventory rows, service units, dashboards/data views, local
secret stores, Kubernetes secrets, audit trails, and historical backend data.
