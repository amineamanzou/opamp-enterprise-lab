#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "$root/scripts/elastic-lib.sh"
  "$root/scripts/elastic-visibility-check.sh"
  "$root/scripts/elastic-visibility-setup.sh"
  "$root/scripts/elastic-opamp-snapshot.sh"
  "$root/scripts/elastic-opamp-watch.sh"
  "$root/scripts/elastic-visibility-verify.sh"
  "$root/scripts/generate-opamp-kibana.mjs"
  "$root/scripts/k8s-app-otel-install.sh"
  "$root/lab/configs/elastic/opamp-visibility-es.json"
  "$root/lab/configs/elastic/opamp-visibility-kibana.ndjson"
  "$root/lab/configs/elastic/opamp-visibility-queries.json"
  "$root/lab/configs/elastic/opamp-visibility-security-rules.json"
  "$root/lab/configs/kubernetes/otelcol-app-opamp.yaml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing required file: $file" >&2
    exit 1
  fi
done

for script in \
  "$root/scripts/elastic-visibility-check.sh" \
  "$root/scripts/elastic-visibility-setup.sh" \
  "$root/scripts/elastic-opamp-snapshot.sh" \
  "$root/scripts/elastic-opamp-watch.sh" \
  "$root/scripts/elastic-visibility-verify.sh"; do
  if [[ ! -x "$script" ]]; then
    echo "script is not executable: $script" >&2
    exit 1
  fi
done

for script in "$root/scripts/generate-opamp-kibana.mjs" "$root/scripts/k8s-app-otel-install.sh"; do
  if [[ ! -x "$script" ]]; then
    echo "script is not executable: $script" >&2
    exit 1
  fi
done

jq -e '
  (.index_templates | length) == 4 and
  ([.index_templates[].name] | sort) == [
  "opamp-connections-lab",
  "opamp-events-lab",
  "opamp-inventory-lab",
  "opamp-server-metrics-lab"
  ] and
  (.component_templates | length) >= 1
' "$root/lab/configs/elastic/opamp-visibility-es.json" >/dev/null

jq -e '
  (.rules | length) >= 4 and
  ([.rules[].rule_id] | unique | length) == (.rules | length) and
  all(.rules[]; .enabled == true and .actions == [] and .type == "query")
' "$root/lab/configs/elastic/opamp-visibility-security-rules.json" >/dev/null

jq -e '
  (.data_views | length) == 3 and
  (.suggested_panels | length) >= 6 and
  (.kql.opamp_inventory | contains("opamp.inventory"))
' "$root/lab/configs/elastic/opamp-visibility-queries.json" >/dev/null

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  printf '%s\n' "$line" | jq -e '.type and .id and .attributes' >/dev/null
done < "$root/lab/configs/elastic/opamp-visibility-kibana.ndjson"

if jq -Rs '
  split("\n")
  | map(select(length > 0) | fromjson)
  | map(select(.type == "dashboard"))
  | any(.attributes.panelsJSON | contains("\"type\":\"search\""))
' "$root/lab/configs/elastic/opamp-visibility-kibana.ndjson" | grep -q true; then
  echo "opamp dashboards must use visualization panels, not saved-search panels" >&2
  exit 1
fi

jq -Rs '
  split("\n")
  | map(select(length > 0) | fromjson)
  | map(select(.type == "visualization"))
  | length >= 8
' "$root/lab/configs/elastic/opamp-visibility-kibana.ndjson" | grep -q true

for script in "$root"/scripts/elastic-*.sh; do
  bash -n "$script"
done

for task in \
  "elastic:visibility:check" \
  "elastic:visibility:setup" \
  "elastic:opamp:snapshot" \
  "elastic:visibility:verify"; do
  if ! rg -q "^  ${task}:" "$root/Taskfile.yml"; then
    echo "missing task: $task" >&2
    exit 1
  fi
done

if rg -n -g 'elastic-*' "(ApiKey [A-Za-z0-9+/=]{20,}|elastic-cloud\\.com|cloud_id|password=|token=)" \
  "$root/lab/configs/elastic" "$root/scripts" >/dev/null; then
  echo "possible committed Elastic secret in visibility files" >&2
  exit 1
fi

echo "elastic visibility checks passed"
