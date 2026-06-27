#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=elastic-lib.sh
source "$root/scripts/elastic-lib.sh"

elastic_load_env

echo "Elasticsearch URL: $ELASTICSEARCH_URL"
if ! elastic_es_api GET "_cluster/health?filter_path=status,cluster_name" | jq .; then
  echo "Cluster health is unavailable; falling back to root endpoint. This is expected on Elastic Serverless." >&2
  elastic_es_api GET "" | jq '{name, cluster_name, version: .version.number, flavor: .version.build_flavor}'
fi

privileges='{
  "cluster": ["monitor", "manage_index_templates"],
  "index": [
    {
      "names": ["logs-opamp.*-*", "metrics-opamp.*-*"],
      "privileges": ["create_index", "create_doc", "view_index_metadata"]
    }
  ]
}'

if elastic_es_api POST "_security/user/_has_privileges" "$privileges" >/tmp/opamp-elastic-privileges.json 2>/tmp/opamp-elastic-privileges.err; then
  jq . /tmp/opamp-elastic-privileges.json
else
  echo "Could not check Elasticsearch privileges with _security/user/_has_privileges." >&2
  cat /tmp/opamp-elastic-privileges.err >&2 || true
fi

if [[ -n "$KIBANA_URL" ]]; then
  echo "Kibana URL: $KIBANA_URL (space: $KIBANA_SPACE)"
  elastic_kibana_api GET "api/status" | jq '{overall: .status.overall}'
else
  echo "KIBANA_URL is not set; Kibana saved objects and Security rules cannot be installed." >&2
fi

echo "elastic visibility preflight completed"
