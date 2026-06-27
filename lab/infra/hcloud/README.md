# Hetzner OpAMP Lab Terraform

Minimal Terraform scaffold for a frugal Hetzner Cloud lab used by the OpAMP / fleet management logs POC.

This directory is intentionally safe to review offline:

- No tokens, SSH private keys, state files, or `*.tfvars` files are committed.
- The provider token is read from a variable, normally via `TF_VAR_hcloud_token`.
- Commands shown here do not require real cloud calls until `terraform plan` or `terraform apply`.
- Firewall source CIDRs are explicit variables for SSH, HTTP/HTTPS, OpAMP, admin API, and OTLP.
- Lab VMs default to public IPv4 and IPv6 for simpler package downloads, Kubernetes networking, and SaaS connectivity. IPv6-only can be enabled explicitly when cost or quota pressure matters.

## Topology

Default VM design uses 4 Linux servers plus one optional load host:

| Name suffix | Role | Default type | Purpose |
| --- | --- | --- | --- |
| `opamp` | `opamp_server` | `cx23` | OpAMP server and evidence/log sink host |
| `agent` | `host_agents` | `cx23` | Host agent and synthetic load source |
| `k3s-server` | `k3s_server` | `cx23` | Lightweight Kubernetes control-plane candidate |
| `k3s-worker` | `k3s_worker` | `cx23` | Lightweight Kubernetes worker candidate |
| `load` | `optional_load` | `cx23` | Optional extra synthetic log/load host |

For quota-constrained smoke runs, set `enable_host_agent_vm = false` and `enable_kubernetes_vms = false` to deploy only the `opamp` VM.

## Files

- `versions.tf`: Terraform and provider version constraints.
- `variables.tf`: Inputs, validation, and secret handling conventions.
- `locals.tf`: VM role catalog and merged labels.
- `main.tf`: SSH key lookup/import, firewall, and server resources.
- `outputs.tf`: Non-secret inventory-oriented outputs.
- `terraform.tfvars.example`: Copy-only example values with no secrets.

## Secret Conventions

Do not commit these files or values:

- `terraform.tfvars`
- `*.auto.tfvars`
- `*.tfstate`
- Hetzner API tokens
- SSH private keys
- kubeconfig files
- OpAMP auth tokens or enrollment secrets

Use environment variables for secrets:

```sh
export TF_VAR_hcloud_token="..."
```

Before applying, narrow these variables in `terraform.tfvars`:

- `allowed_ssh_cidrs` for port `22`.
- `allowed_http_cidrs` for ports `80` and `443`.
- `allowed_opamp_cidrs` for port `4320` and `/v1/opamp`; include lab agents that must report to the OpAMP server.
- `allowed_admin_api_cidrs` for port `4321` and evidence/admin APIs.
- `allowed_otlp_cidrs` for ports `4317-4318`.
- `allowed_k3s_api_cidrs` for k3s API port `6443`; include the k3s pod CIDR when Kubernetes workloads need to call the public API endpoint.
- `allowed_k3s_peer_cidrs` for k3s node peer ports `10250/tcp` and `8472/udp`.

If using an existing SSH key already registered in Hetzner Cloud, set `ssh_key_name`. If importing a public key, set `ssh_public_key_path` to a public key file such as `~/.ssh/id_ed25519.pub`.

## Local Review Commands

These commands are local formatting and static checks:

```sh
terraform fmt -check
terraform validate
```

Provider installation may be required before validation:

```sh
terraform init -backend=false
```

Do not run `terraform plan` or `terraform apply` for offline review. Those commands contact Hetzner Cloud.

## Example Use

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
export TF_VAR_hcloud_token="..."
terraform init -backend=false
terraform plan
```
