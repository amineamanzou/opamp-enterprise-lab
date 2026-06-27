# OpAMP Cloud Lab Runbook

This runbook wires the OpAMP lab server, cloud VMs, OCB collectors, `opampsupervisor`, and an Elastic Cloud trial backend.

## Preconditions

Install the required local tools, then verify:

```sh
task --version
terraform version
ansible --version
go version
```

Required secrets for cloud execution are stored locally and must not be committed.

Create local plaintext env files under gitignored `secrets/`. If you use SOPS locally, encrypted files should remain local under `secrets.encrypted/` and are ignored by git.

```sh
mkdir -p secrets
cp secrets.encrypted/hcloud.env.example secrets/hcloud.env
cp secrets.encrypted/elastic-cloud.env.example secrets/elastic-cloud.env
cp secrets.encrypted/opamp.env.example secrets/opamp.env
$EDITOR secrets/hcloud.env
$EDITOR secrets/elastic-cloud.env
$EDITOR secrets/opamp.env
task secrets:encrypt:hcloud
task secrets:encrypt:elastic
task secrets:encrypt:opamp
task secrets:render
source scripts/load-cloud-secrets.sh
```

Put the Hetzner API token in `secrets/hcloud.env` as `HCLOUD_TOKEN` and `TF_VAR_hcloud_token`. Put the Elastic endpoint and API key in `secrets/elastic-cloud.env` as `ELASTIC_OTLP_ENDPOINT` and `ELASTIC_API_KEY`. Put the lab OpAMP enrollment token in `secrets/opamp.env` as `OPAMP_AUTH_TOKEN`.

`task secrets:render` looks for an age private key in `secrets/age/operator.txt`, or uses `SOPS_AGE_KEY_FILE` when set.

Validate:

```sh
task secrets:check
```

## Provision Hetzner

Create `lab/infra/hcloud/terraform.tfvars` from the example and narrow all allowed CIDRs.

```sh
task infra:validate
task infra:plan
task infra:apply
task infra:inventory
```

The generated inventory is written to `lab/ansible/inventory/hosts.ini`.

## Deploy Runtime

```sh
task opamp:build
task opamp:supervisor:build
ansible-playbook -i lab/ansible/inventory/hosts.ini lab/ansible/playbooks/bootstrap.yml
ansible-playbook -i lab/ansible/inventory/hosts.ini lab/ansible/playbooks/opamp_server.yml
```

The OpAMP HTTP/WebSocket endpoint is:

```text
ws://<opamp-host>:4320/v1/opamp
```

The admin API is:

```text
http://<opamp-host>:4321/v1/agents
http://<opamp-host>:4321/v1/opamp/connections
```

## Smoke Scenarios

Collector OpAMP extension:

```sh
task opamp:smoke:extension
```

Supervisor-managed collector:

```sh
task opamp:smoke:supervisor
```

Create cloud evidence folder:

```sh
task evidence:opamp-cloud
```

## Remote Config Exercise

Assign a ring config:

```sh
curl -X PUT "http://<opamp-host>:4321/v1/rings/canary/config" \
  -H "content-type: application/json" \
  -d '{"config":{"collector.yaml":"receivers: {}\nprocessors: {}\nexporters: {}\nservice: {}\n"}}'
```

Expected proof:

- matching agent appears in `GET /v1/agents`;
- `remote_config_status` changes after the collector/supervisor reports status;
- `effective_config` is visible when the client reports it;
- Elastic Cloud receives logs from the same host role.
