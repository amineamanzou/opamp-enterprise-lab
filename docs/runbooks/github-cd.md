# GitHub CD Runbook

This repository can deploy the smoke lab from a fork with GitHub Actions. The workflow is manual-only and uses the `lab` GitHub Environment so the fork owner controls secrets and approval rules.

## What It Deploys

V1 deploys the minimal smoke topology:

- one Hetzner VM for the OpAMP server
- one Hetzner VM running the host-agent collector through `opampsupervisor`
- Elastic OTLP export using your GitHub Environment secrets

Kubernetes/k3s nodes are intentionally disabled in the GitHub CD path for now. The workflow is meant to prove the lab can be provisioned and exercised from a sanitized fork before adding the larger topology.

## GitHub Workflow Secret Setup

CI does not require secrets. CD does require secrets because it provisions
Hetzner infrastructure, writes Terraform state to S3-compatible object storage,
and deploys runtime services through SSH.

Create a GitHub Environment named `lab`, then add these environment secrets:

| Secret | Required | Used by | How to get it |
| --- | --- | --- | --- |
| `HCLOUD_TOKEN` | yes | Terraform Hetzner provider | Hetzner Cloud Console project API token with read/write access for servers, firewalls, and SSH keys. |
| `ELASTIC_OTLP_ENDPOINT` | yes | Collector runtime | Elastic Cloud OTLP endpoint, including `https://` when available. |
| `ELASTIC_API_KEY` | yes | Collector runtime | Elastic API key for OTLP ingest. |
| `OPAMP_AUTH_TOKEN` | yes | OpAMP server and collectors | Generate a lab token, for example `openssl rand -hex 32`. |
| `LAB_SSH_PRIVATE_KEY` | yes | Ansible SSH from GitHub runner | Private half of a dedicated deploy keypair generated for this lab. |
| `LAB_SSH_PUBLIC_KEY` | yes | Terraform SSH key import | Public half of the same dedicated deploy keypair. |
| `TF_STATE_S3_BUCKET` | yes | Terraform backend | Existing S3-compatible bucket name, without endpoint host suffix. |
| `TF_STATE_S3_REGION` | yes | Terraform backend | Hetzner Object Storage location, for example `fsn1`, `nbg1`, or `hel1`. |
| `TF_STATE_S3_ENDPOINT` | yes | Terraform backend | S3 endpoint URL, for example `https://fsn1.your-objectstorage.com`. |
| `TF_STATE_S3_ACCESS_KEY_ID` | yes | Terraform backend | S3-compatible access key ID for the state bucket. |
| `TF_STATE_S3_SECRET_ACCESS_KEY` | yes | Terraform backend | Matching S3-compatible secret access key. |
| `TF_STATE_S3_KEY` | no | Terraform backend | State object key; defaults to `<owner>/<repo>/hcloud.tfstate`. |

Do not add a separate `TF_VAR_hcloud_token` GitHub secret. The workflow reads
`HCLOUD_TOKEN` and exports it as `TF_VAR_hcloud_token` for Terraform:

```yaml
TF_VAR_hcloud_token: ${{ secrets.HCLOUD_TOKEN }}
```

The S3-compatible bucket must already exist. The workflow writes only Terraform state to it.

## Retrieving Existing Hetzner S3 Backend Values

If an existing bucket endpoint looks like this:

```text
my-tfstate-bucket.fsn1.your-objectstorage.com
```

use:

```text
TF_STATE_S3_BUCKET=my-tfstate-bucket
TF_STATE_S3_REGION=fsn1
TF_STATE_S3_ENDPOINT=https://fsn1.your-objectstorage.com
```

If you configured the bucket through AWS CLI profiles:

```bash
aws configure list-profiles
aws configure get endpoint_url --profile <profile>
aws configure get region --profile <profile>
aws configure get aws_access_key_id --profile <profile>
aws configure get aws_secret_access_key --profile <profile>
```

If you configured it through `rclone`:

```bash
cat ~/.config/rclone/rclone.conf
```

Look for `endpoint`, `region`, `access_key_id`, and `secret_access_key`.

If you configured it through MinIO client:

```bash
jq '.aliases' ~/.mc/config.json
```

Hetzner S3 secret keys are shown only when created. If the secret access key is
lost, create a new S3 credential pair in the Hetzner Console and update the
GitHub Environment secrets.

## Local Terraform Difference

Local Terraform runs are different from GitHub CD. In a local shell, export
`TF_VAR_hcloud_token="$HCLOUD_TOKEN"` yourself before running `terraform plan`:

```bash
export HCLOUD_TOKEN="..."
export TF_VAR_hcloud_token="$HCLOUD_TOKEN"
```

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
