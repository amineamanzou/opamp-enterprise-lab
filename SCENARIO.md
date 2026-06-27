# Vanilla OpAMP Go Scenario

This branch reproduces the custom Go OpAMP reference server experiment: the
minimal OpAMP server, its embedded HTML UI, and the fixes required before the UI
and APIs produced useful operator evidence.

## What This Branch Covers

- `lab/opamp-server/`: custom Go OpAMP server and mock-agent tools.
- `lab/opamp-server/internal/server/server.go`: embedded HTML inventory/detail UI.
- `docs/study/vanilla-opamp-lab-notes.md`: defects found and corrections applied.
- `scripts/evidence-vanilla-ui.sh`: retained evidence template for the HTML UI.
- `scripts/evidence-ops-experience.sh`: day-2 operations evidence template.
- `scripts/evidence-agent-scale.sh`: mock-agent scale evidence template.

## Run

```sh
task ci:local
cp lab/infra/hcloud/terraform.tfvars.example lab/infra/hcloud/terraform.tfvars
$EDITOR lab/infra/hcloud/terraform.tfvars
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
task opamp:build
task opamp:supervisor:build
task evidence:vanilla-ui
task evidence:ops-experience
task evidence:agent-scale
```

Then follow:

- `docs/runbooks/opamp-cloud-lab.md`
- `docs/runbooks/opamp-ops-experience.md`
- `docs/runbooks/opamp-agent-scale.md`
- `docs/study/vanilla-opamp-lab-notes.md`

## Evidence Goal

Prove that the vanilla Go server can inventory OpAMP agents, expose status in a
simple HTML frontend, assign remote config, and support restart/scale evidence
after the lab fixes. The important conclusion is not that the UI is complete;
it is that a protocol-level OpAMP server needs product work around identity,
metadata, config visibility, validation, restart commands, stale cleanup, and
operator-facing UX.
