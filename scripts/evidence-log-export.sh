#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" log-export)"
mkdir -p "$run_dir/artifacts"

for env_file in "$root/secrets/elastic-cloud.env" "$root/secrets/opamp.env"; do
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [ -z "${ELASTIC_OTLP_ENDPOINT:-}" ] || [ -z "${ELASTIC_API_KEY:-}" ]; then
  echo "ELASTIC_OTLP_ENDPOINT and ELASTIC_API_KEY are required" >&2
  exit 1
fi

case "$ELASTIC_OTLP_ENDPOINT" in
  http://*|https://*) endpoint="$ELASTIC_OTLP_ENDPOINT" ;;
  *) endpoint="https://$ELASTIC_OTLP_ENDPOINT" ;;
esac

case "$ELASTIC_API_KEY" in
  "ApiKey "*) key="${ELASTIC_API_KEY#ApiKey }" ;;
  *:*) key="$(printf '%s' "$ELASTIC_API_KEY" | base64 | tr -d '\n')" ;;
  *) key="$ELASTIC_API_KEY" ;;
esac

opamp_host="$(
  cd "$root/lab/infra/hcloud"
  terraform output -json servers | jq -r '.opamp.public_host'
)"
agent_host="$(
  cd "$root/lab/infra/hcloud"
  terraform output -json servers | jq -r '.agent.public_host'
)"

es_endpoint="${endpoint/.ingest./.es.}"
kubeconfig="${KUBECONFIG:-$root/secrets/kubeconfig-opamp-poc.yaml}"
if [ ! -f "$kubeconfig" ] && [ -f "$root/secrets/kubeconfig-opamp-poc.yaml" ]; then
  kubeconfig="$root/secrets/kubeconfig-opamp-poc.yaml"
fi

curl -fsS "http://$opamp_host:4321/v1/opamp/connections" \
  | jq . > "$run_dir/artifacts/opamp-connections.json"
curl -fsS "http://$opamp_host:4321/v1/inventory" \
  | jq . > "$run_dir/artifacts/opamp-inventory.json"

curl --connect-timeout 10 --max-time 30 -fsS \
  -H "Authorization: ApiKey $key" \
  "$es_endpoint/_cat/indices/logs-*?format=json&h=index,docs.count&s=index" \
  | jq . > "$run_dir/artifacts/elastic-log-indices.json"

curl --connect-timeout 10 --max-time 30 -fsS \
  -H "Authorization: ApiKey $key" \
  -H "Content-Type: application/json" \
  "$es_endpoint/logs-*/_search" \
  -d '{"size":0,"query":{"bool":{"filter":[{"range":{"@timestamp":{"gte":"now-15m"}}},{"terms":{"service.name":["opamp-poc-host-logs","opamp-poc-k8s-logs"]}}]}},"aggs":{"by_service":{"terms":{"field":"service.name","size":10}},"by_path":{"terms":{"field":"elastic.poc.path","size":10}}}}' \
  | jq '{total: .hits.total, by_service: [.aggregations.by_service.buckets[] | {key, doc_count}], by_path: (.aggregations.by_path.buckets // [] | map({key, doc_count}))}' \
  > "$run_dir/artifacts/elastic-log-export-counts.json"

if [ -f "$kubeconfig" ]; then
  KUBECONFIG="$kubeconfig" kubectl -n opamp-logs-poc get pods -o wide \
    > "$run_dir/artifacts/k8s-pods.txt"
fi

if [ -n "$agent_host" ] && [ "$agent_host" != "null" ]; then
  ssh -o StrictHostKeyChecking=accept-new "root@$agent_host" \
    'systemctl is-active otelcol-logs-opamp synthetic-log-generator' \
    > "$run_dir/artifacts/host-services.txt"
fi

cat > "$run_dir/run.md" <<EOF
# Log Export Evidence

- Scenario: VM classic via OpAMP and Kubernetes DaemonSet via OpAMP.
- Backend: Elastic Cloud OTLP ingest.
- Window: last 15 minutes at collection time.

## Artifacts

- \`artifacts/opamp-connections.json\`
- \`artifacts/opamp-inventory.json\`
- \`artifacts/elastic-log-indices.json\`
- \`artifacts/elastic-log-export-counts.json\`
- \`artifacts/k8s-pods.txt\`
- \`artifacts/host-services.txt\`
EOF

echo "$run_dir"
