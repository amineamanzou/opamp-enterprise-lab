#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
es_manifest="$root/lab/configs/elastic/opamp-visibility-es.json"
kibana_ndjson="$root/lab/configs/elastic/opamp-visibility-kibana.ndjson"
security_rules="$root/lab/configs/elastic/opamp-visibility-security-rules.json"

# shellcheck source=elastic-lib.sh
source "$root/scripts/elastic-lib.sh"
elastic_load_env
elastic_require_kibana

echo "Installing Elasticsearch component templates"
jq -c '.component_templates[]' "$es_manifest" | while IFS= read -r item; do
  name="$(jq -r '.name' <<<"$item")"
  body="$(jq -c '.body' <<<"$item")"
  elastic_es_api PUT "_component_template/$name" "$body" >/dev/null
  echo "  installed component template: $name"
done

echo "Installing Elasticsearch index templates"
jq -c '.index_templates[]' "$es_manifest" | while IFS= read -r item; do
  name="$(jq -r '.name' <<<"$item")"
  body="$(jq -c '.body' <<<"$item")"
  elastic_es_api PUT "_index_template/$name" "$body" >/dev/null
  echo "  installed index template: $name"
done

if jq -e '.compat_mappings // empty' "$es_manifest" >/dev/null; then
  echo "Installing Elasticsearch compatibility mappings"
  jq -c '.compat_mappings[]' "$es_manifest" | while IFS= read -r item; do
    index="$(jq -r '.index' <<<"$item")"
    body="$(jq -c '.body' <<<"$item")"
    elastic_es_api PUT "$index/_mapping?allow_no_indices=true&ignore_unavailable=true" "$body" >/dev/null
    echo "  installed compatibility mapping: $index"
  done
fi

echo "Importing Kibana saved objects"
key="$(elastic_api_key)"
base="$(elastic_kibana_prefix)"
curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -fsS \
  -H "Authorization: ApiKey $key" \
  -H "kbn-xsrf: opamp-poc" \
  -F "file=@$kibana_ndjson" \
  "$base/api/saved_objects/_import?overwrite=true" \
  | jq .

echo "Installing Elastic Security detection rules"
security_api_available=1
while IFS= read -r rule; do
  if [[ "$security_api_available" -eq 0 ]]; then
    continue
  fi

  rule_id="$(jq -r '.rule_id' <<<"$rule")"
  tmp_body="$(mktemp)"
  tmp_err="$(mktemp)"
  printf '%s' "$rule" > "$tmp_body"

  status="$(curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -sS \
    -o "$tmp_err" \
    -w '%{http_code}' \
    -X POST \
    -H "Authorization: ApiKey $key" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: opamp-poc" \
    "$base/api/detection_engine/rules" \
    --data-binary "@$tmp_body")"

  if [[ "$status" == "200" || "$status" == "201" ]]; then
    echo "  created security rule: $rule_id"
  elif [[ "$status" == "409" ]]; then
    update_status="$(curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -sS \
      -o "$tmp_err" \
      -w '%{http_code}' \
      -X PUT \
      -H "Authorization: ApiKey $key" \
      -H "Content-Type: application/json" \
      -H "kbn-xsrf: opamp-poc" \
      "$base/api/detection_engine/rules" \
      --data-binary "@$tmp_body")"
    if [[ "$update_status" == "200" ]]; then
      echo "  updated security rule: $rule_id"
    else
      echo "failed to update security rule $rule_id: HTTP $update_status" >&2
      cat "$tmp_err" >&2
      exit 1
    fi
  elif [[ "$status" == "404" ]]; then
    echo "Elastic Security detection API is unavailable; installing Kibana alerting rules instead."
    security_api_available=0
    rm -f "$tmp_body" "$tmp_err"
    break
  else
    echo "failed to create security rule $rule_id: HTTP $status" >&2
    cat "$tmp_err" >&2
    exit 1
  fi

  rm -f "$tmp_body" "$tmp_err"
done < <(jq -c '.rules[]' "$security_rules")

if [[ "$security_api_available" -eq 0 ]]; then
  while IFS= read -r rule; do
    rule_id="$(jq -r '.rule_id' <<<"$rule")"
    name="$(jq -r '.name' <<<"$rule")"
    interval="$(jq -r '.interval' <<<"$rule")"
    from="$(jq -r '.from' <<<"$rule")"
    query="$(jq -r '.query' <<<"$rule")"
    first_index="$(jq -r '.index[0]' <<<"$rule")"
    window_value="${from#now-}"
    window_unit="${window_value: -1}"
    window_size="${window_value%?}"
    case "$window_unit" in
      m) window_unit="m" ;;
      h) window_unit="h" ;;
      d) window_unit="d" ;;
      *) window_unit="m"; window_size="10" ;;
    esac

    payload="$(jq -n \
      --arg name "$name" \
      --arg rule_id "$rule_id" \
      --arg interval "$interval" \
      --arg index "$first_index" \
      --arg query "$query" \
      --arg window_size "$window_size" \
      --arg window_unit "$window_unit" \
      '{
        name: $name,
        tags: ["opamp-poc", "elastic-visibility-as-code", $rule_id],
        rule_type_id: ".index-threshold",
        consumer: "stackAlerts",
        enabled: true,
        schedule: {interval: $interval},
        params: {
          index: [$index],
          timeField: "@timestamp",
          aggType: "count",
          groupBy: "all",
          thresholdComparator: ">",
          threshold: [0],
          timeWindowSize: ($window_size | tonumber),
          timeWindowUnit: $window_unit,
          filterKuery: $query
        },
        actions: []
      }')"

    existing_id="$(elastic_kibana_api GET "api/alerting/rules/_find?search=$(printf '%s' "$rule_id" | jq -sRr @uri)&search_fields=tags&per_page=1" \
      | jq -r '.data[0].id // empty')"

    if [[ -n "$existing_id" ]]; then
      echo "  alerting rule already exists: $rule_id"
    else
      elastic_kibana_api POST "api/alerting/rule" "$payload" >/dev/null
      echo "  created alerting rule: $rule_id"
    fi
  done < <(jq -c '.rules[]' "$security_rules")
fi

echo "elastic visibility setup completed"
