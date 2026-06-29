# Experiment Branches

This repository keeps a clean public `main` branch plus one branch per
reproducible experiment. Clone the repository, checkout the scenario branch you
want, then follow that branch's `SCENARIO.md` and runbook.

```sh
git clone https://github.com/amineamanzou/opamp-enterprise-lab.git
cd opamp-enterprise-lab
git checkout scenario/<name>
```

| Branch | Purpose | Primary runbook |
| --- | --- | --- |
| `scenario/vanilla-opamp-go-experience` | Custom Go OpAMP reference server, embedded HTML UI, and the fixes required to make inventory/config evidence usable. | `docs/study/vanilla-opamp-lab-notes.md` |
| `scenario/elastic-fleet-otel-only-experience` | Elastic Fleet managing an OpenTelemetry Collector through the OTel-only OpAMP path. | `docs/runbooks/elastic-fleet-otel-only.md` |
| `scenario/bindplane-otel-experience` | Bindplane/BDOT collector-management and switching-friction evidence. | `docs/runbooks/bindplane-otel.md` |
| `scenario/exit-drill-secrets-outage` | Exit, secret hygiene, and control-plane outage drills. | `docs/runbooks/exit-drill-secrets-outage.md` |
| `scenario/opamp-server-py-experience` | Python OpAMP server comparison branch; separate from the custom Go vanilla server. | `docs/study/fleet-management-comparison.md` |
| `scenario/openlit-opamp-analysis` | OpenLit Fleet Hub as an OpAMP-facing collector-management surface. | `docs/runbooks/openlit-opamp.md` |

The branches are clean public branches, not preserved copies of the private
working repo history. That keeps commit messages, local paths, ignored runtime
files, and private evidence out of the public repository.

## Shared Setup

Most scenarios use the same high-level setup:

```sh
task ci:local
cp lab/infra/hcloud/terraform.tfvars.example lab/infra/hcloud/terraform.tfvars
$EDITOR lab/infra/hcloud/terraform.tfvars
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
```

After infrastructure exists, run the scenario-specific commands from
`SCENARIO.md` on the checked-out branch.
