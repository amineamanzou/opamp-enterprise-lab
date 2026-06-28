# GitHub CD Runbook

This repository can deploy the smoke lab from a fork with GitHub Actions. The workflow is manual-only and uses the `lab` GitHub Environment so the fork owner controls secrets and approval rules.

## What It Deploys

V1 deploys the minimal smoke topology:

- one Hetzner VM for the OpAMP server
- one Hetzner VM running the host-agent collector through `opampsupervisor`
- Elastic OTLP export using your GitHub Environment secrets

Kubernetes/k3s nodes are intentionally disabled in the GitHub CD path for now. The workflow is meant to prove the lab can be provisioned and exercised from a sanitized fork before adding the larger topology.

## Required GitHub Environment

Create a GitHub Environment named `lab`, then add these environment secrets:

- `HCLOUD_TOKEN`
- `ELASTIC_OTLP_ENDPOINT`
- `ELASTIC_API_KEY`
- `OPAMP_AUTH_TOKEN`
- `LAB_SSH_PRIVATE_KEY`
- `LAB_SSH_PUBLIC_KEY`
- `TF_STATE_S3_BUCKET`
- `TF_STATE_S3_REGION`
- `TF_STATE_S3_ENDPOINT`
- `TF_STATE_S3_ACCESS_KEY_ID`
- `TF_STATE_S3_SECRET_ACCESS_KEY`

Optional:

- `TF_STATE_S3_KEY` defaults to `<owner>/<repo>/hcloud.tfstate`

The S3-compatible bucket must already exist. The workflow writes only Terraform state to it.

## SSH Keypair

Generate a dedicated keypair for GitHub CD:

```bash
ssh-keygen -t ed25519 -f opamp-lab-cd -C opamp-lab-cd
```

Put the private key contents in `LAB_SSH_PRIVATE_KEY` and the public key contents in `LAB_SSH_PUBLIC_KEY`.

## Running CD

Open **Actions -> CD Lab -> Run workflow** and choose:

- `operation=plan` to validate the stack and show Terraform changes
- `operation=apply` to provision infrastructure and deploy runtime services
- `operation=destroy` to tear down the stack

Set `operator_cidr` to the public CIDR that should reach lab application endpoints, for example `203.0.113.10/32`. The workflow also adds current GitHub Actions runner CIDRs to SSH only, so Ansible can connect during deployment.

For `destroy`, set `confirm_destroy=true`; otherwise the workflow exits before Terraform.

## Notes

GitHub Actions logs and Terraform output can include public lab IP addresses and resource names. They should not include client data or secret values.

The CD workflow renders ignored files under `secrets/`, `tmp/`, and `lab/infra/hcloud/*.cd.*` during each run. Those files are intentionally not committed.
