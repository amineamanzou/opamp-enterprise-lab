#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${REGULATED_VERIFY_OUT:-$root/tmp/regulated-observability-elastic}"
mkdir -p "$out"

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

es_endpoint="${endpoint/.ingest./.es.}"
window="${REGULATED_VERIFY_WINDOW:-now-30m}"

query='{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        {"range": {"@timestamp": {"gte": "'"$window"'"}}},
        {"terms": {"data_stream.dataset": [
          "infra.host.otel",
          "security.host.otel",
          "observability.collector.otel",
          "infra.kubernetes.otel",
          "security.kubernetes_audit.otel",
          "hostmetricsreceiver.otel",
          "kubeletstatsreceiver.otel",
          "k8sclusterreceiver.otel",
          "metrics.host.otel",
          "metrics.kubernetes_node.otel",
          "metrics.collector.otel"
        ]}}
      ]
    }
  },
  "aggs": {
    "by_dataset": {"terms": {"field": "data_stream.dataset", "size": 20}},
    "by_service": {"terms": {"field": "resource.attributes.service.name", "size": 20}},
    "audit_verbs": {
      "filter": {"term": {"data_stream.dataset": "security.kubernetes_audit.otel"}},
      "aggs": {"verbs": {"terms": {"field": "attributes.verb", "size": 20}}}
    }
  }
}'

curl --connect-timeout 10 --max-time 60 -fsS \
  -H "Authorization: ApiKey $key" \
  -H "Content-Type: application/json" \
  "$es_endpoint/logs-*,metrics-*/_search" \
  -d "$query" \
  | jq . > "$out/regulated-observability-counts.json"

curl --connect-timeout 10 --max-time 60 -fsS \
  -H "Authorization: ApiKey $key" \
  "$es_endpoint/_cat/indices/logs-*,metrics-*?format=json&h=index,docs.count&s=index" \
  | jq . > "$out/regulated-observability-indices.json"

jq '{
  total: .hits.total,
  by_dataset: [.aggregations.by_dataset.buckets[] | {dataset: (.key | sub("\\.otel$"; "")), count: .doc_count}],
  by_service: [.aggregations.by_service.buckets[] | {service: .key, count: .doc_count}],
  audit_verbs: [.aggregations.audit_verbs.verbs.buckets[] | {verb: .key, count: .doc_count}]
}' "$out/regulated-observability-counts.json"

echo "$out"
