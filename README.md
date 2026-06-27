# OpAMP Enterprise Lab

Public, anonymized lab repository for studying OpAMP-based fleet management of
logs agents in a large on-premises environment.

The lab uses an Elastic Cloud trial as a common logs backend for comparable
scenarios. Elastic Fleet is also benchmarked as a management-plane scenario; it
is not treated as the default target architecture.

## Scope

- Logs only for V1.
- Fictional organization of about 100k on-premises assets.
- Strong security, network segmentation, audit, and operational governance
  constraints.
- Reproducible evidence over vendor claims. Documents label findings as
  `source-only`, `lab-planned`, or `lab-proven`.
- No real customer names, secrets, private topology, or identifiable data.

## Repository Layout

- `Taskfile.yml`: single entry point for local and CI workflows.
- `docs/study/`: state of the art, sources, matrices, blueprints.
- `docs/articles/`: public anonymized article drafts.
- `docs/evidence/runs/`: evidence outputs and run templates.
- `lab/infra/hcloud/`: standalone Terraform for an optional cloud lab.
- `lab/ansible/`: bootstrap and runtime configuration.
- `lab/opamp-server/`: minimal Go server for inventory/config evidence.
- `lab/collector-ocb/`: OCB manifests and measurement templates.
- `lab/configs/`: OTel, EDOT, Elastic Agent, and Kubernetes configs.

## Quick Start

Install [Task](https://taskfile.dev/) if available, then run:

```sh
task ci:local
```

Without Task, the core checks are still plain scripts:

```sh
./scripts/study-check.sh
./scripts/ocb-build.sh
(cd lab/opamp-server && go test ./...)
```

## Environment Variables

Never commit real values. Use environment variables or local `.env` files:

- `ELASTIC_OTLP_ENDPOINT`
- `ELASTIC_API_KEY`
- `HCLOUD_TOKEN`
- `TF_VAR_hcloud_token`

See component-specific README files under `lab/`.
