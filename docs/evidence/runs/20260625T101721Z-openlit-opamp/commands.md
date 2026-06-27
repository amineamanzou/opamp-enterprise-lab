# Commands

Fill with exact commands run during the lab. Redact tokens, public IPs, tenant IDs, private hostnames, and certificate material.

## Source/UI Baseline

```sh
browser-use --headed --profile Default open "<openlit-url>"
browser-use --headed --profile Default state > artifacts/browser-use/openlit-home.state.txt
```

## Runtime Secret Handling

```sh
umask 077
$EDITOR /tmp/openlit-opamp.env
set -a
. /tmp/openlit-opamp.env
set +a
```

## Optional Self-Host Smoke

```sh
docker compose -f <openlit-compose-file> up -d
```

## Hetzner Smoke

```sh
source ../../../scripts/load-cloud-secrets.sh
terraform init
terraform apply -auto-approve \
  -var="enable_host_agent_vm=false" \
  -var="enable_kubernetes_vms=false" \
  -var="enable_optional_load_host=false"

ssh root@<hetzner-openlit-host> 'cloud-init status --wait'
ssh root@<hetzner-openlit-host> 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2 git curl ca-certificates'
ssh root@<hetzner-openlit-host> 'git clone --depth 1 https://github.com/openlit/openlit.git /opt/openlit'
ssh root@<hetzner-openlit-host> 'cd /opt/openlit && docker compose -p openlit-cloud -f docker-compose.yml -f docker-compose.codex-cloud.yml up -d'
```

## Hetzner Bridge And Kubernetes

```sh
terraform apply -auto-approve
task infra:inventory
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml
task collector:env
ansible-playbook -i inventory/hosts.ini playbooks/synthetic_logs.yml
ansible-playbook -i inventory/hosts.ini playbooks/opamp_supervisor_host.yml \
  -e ocb_collector_binary_local_path=../../../dist/otelcol-logs-opamp-0.151.0/otelcol-logs-opamp-0.151.0

task ansible:k3s
KUBECONFIG=secrets/kubeconfig-opamp-poc.yaml kubectl get nodes -o wide
task k8s:logs:install
task k8s:app:install
```

## Collector Startup

```sh
otelcol-contrib --config config/otelcol-contrib-openlit-opamp.yaml
```

## Validation

```sh
curl -fsS "${OTEL_HEALTH_CHECK_URL}"
browser-use --headed --profile Default --session openlit-hetzner open "<hetzner-openlit-url>/fleet-hub"
browser-use --headed --profile Default --session openlit-hetzner screenshot docs/evidence/runs/<run-id>/screenshots/openlit-hetzner-fleet-hub-sanitized.png
browser-use --headed --profile Default --session openlit-hetzner screenshot docs/evidence/runs/<run-id>/screenshots/openlit-hetzner-collector-detail-loading-config-sanitized.png
browser-use --headed --profile Default --session openlit-hetzner screenshot docs/evidence/runs/<run-id>/screenshots/openlit-hetzner-fleet-hub-bridge-k8s-sanitized.png
```
