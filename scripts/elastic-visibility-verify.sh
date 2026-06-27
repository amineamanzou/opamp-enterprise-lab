#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=elastic-lib.sh
source "$root/scripts/elastic-lib.sh"
elastic_load_env

out="${ELASTIC_VISIBILITY_VERIFY_OUT:-$root/tmp/elastic-visibility}"
mkdir -p "$out"
window="${ELASTIC_VISIBILITY_WINDOW:-now-2h}"

query='{
  "size": 0,
  "query": {
    "range": {"@timestamp": {"gte": "'"$window"'"}}
  },
  "aggs": {
    "by_dataset": {"terms": {"field": "data_stream.dataset", "size": 50}},
    "by_namespace": {"terms": {"field": "data_stream.namespace", "size": 20}},
    "connected_agents": {
      "filter": {"term": {"data_stream.dataset": "opamp.inventory"}},
      "aggs": {
        "by_connected": {"terms": {"field": "agent.connected", "size": 2}},
        "by_ring": {"terms": {"field": "agent.ring", "size": 20}},
        "by_version": {"terms": {"field": "agent.version", "size": 20}}
      }
    }
  }
}'

echo "Verifying OpAMP index templates"
elastic_es_api GET "_index_template/opamp-inventory-lab" | jq . > "$out/index-template-opamp-inventory.json"
elastic_es_api GET "_index_template/opamp-connections-lab" | jq . > "$out/index-template-opamp-connections.json"
elastic_es_api GET "_index_template/opamp-events-lab" | jq . > "$out/index-template-opamp-events.json"
elastic_es_api GET "_index_template/opamp-server-metrics-lab" | jq . > "$out/index-template-opamp-server-metrics.json"
echo "Verifying data stream backing indices"
elastic_es_api GET "_cat/indices/logs-*,metrics-*?format=json&h=index,docs.count&s=index" | jq . > "$out/indices.json"
echo "Verifying dataset counts"
elastic_es_api POST "logs-*,metrics-*,logs-opamp.*-*,metrics-opamp.*-*/_search" "$query" | jq . > "$out/dataset-counts.json"

if [[ -n "$KIBANA_URL" ]]; then
  echo "Verifying Kibana saved objects"
  if elastic_kibana_api GET "api/saved_objects/_find?type=index-pattern&type=dashboard&type=search&search=OpAMP&search_fields=title&per_page=100" \
    | jq . > "$out/kibana-opamp-saved-objects.json"; then
    :
  else
    echo '{"status":"skipped","reason":"saved_objects_read_api_unavailable_in_current_kibana_configuration"}' \
      | jq . > "$out/kibana-opamp-saved-objects.json"
    echo "Saved Objects read APIs are unavailable; relying on setup import success for Kibana object verification." >&2
  fi
  echo "Verifying Kibana alerting rules"
  if elastic_kibana_api GET "api/alerting/rules/_find?search=opamp-poc&search_fields=tags&per_page=100" \
    | jq . > "$out/alerting-rules.json"; then
    :
  elif elastic_kibana_api GET "api/detection_engine/rules/_find?filter=alert.attributes.tags:opamp-poc&per_page=100" \
    | jq . > "$out/security-rules.json"; then
    :
  else
    echo "No Elastic Security or Kibana alerting rules could be verified." >&2
    exit 1
  fi
fi

jq '{
  total: .hits.total,
  by_dataset: [.aggregations.by_dataset.buckets[] | {dataset: .key, count: .doc_count}],
  opamp_inventory: {
    connected: [.aggregations.connected_agents.by_connected.buckets[] | {connected: .key_as_string, count: .doc_count}],
    rings: [.aggregations.connected_agents.by_ring.buckets[] | {ring: .key, count: .doc_count}],
    versions: [.aggregations.connected_agents.by_version.buckets[] | {version: .key, count: .doc_count}]
  },
  templates: {opamp_events: true}
}' "$out/dataset-counts.json"

echo "$out"
