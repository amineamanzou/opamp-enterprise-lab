#!/usr/bin/env bash
set -euo pipefail

elastic_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

elastic_load_env() {
  for env_file in "$elastic_root/secrets/elastic-cloud.env" "$elastic_root/secrets/opamp.env"; do
    if [[ -f "$env_file" ]]; then
      # shellcheck disable=SC1090
      source "$env_file"
    fi
  done

  if [[ -z "${ELASTIC_API_KEY:-}" ]]; then
    echo "ELASTIC_API_KEY is required; render or update secrets/elastic-cloud.env" >&2
    return 1
  fi

  if [[ -z "${ELASTICSEARCH_URL:-}" ]]; then
    if [[ -z "${ELASTIC_OTLP_ENDPOINT:-}" ]]; then
      echo "Set ELASTICSEARCH_URL or ELASTIC_OTLP_ENDPOINT" >&2
      return 1
    fi
    case "$ELASTIC_OTLP_ENDPOINT" in
      http://*|https://*) ELASTICSEARCH_URL="$ELASTIC_OTLP_ENDPOINT" ;;
      *) ELASTICSEARCH_URL="https://$ELASTIC_OTLP_ENDPOINT" ;;
    esac
    ELASTICSEARCH_URL="${ELASTICSEARCH_URL/.ingest./.es.}"
  fi

  ELASTICSEARCH_URL="${ELASTICSEARCH_URL%/}"

  if [[ -z "${KIBANA_URL:-}" && "$ELASTICSEARCH_URL" == *".es."* ]]; then
    KIBANA_URL="${ELASTICSEARCH_URL/.es./.kb.}"
  fi
  KIBANA_URL="${KIBANA_URL:-}"
  KIBANA_URL="${KIBANA_URL%/}"
  KIBANA_SPACE="${KIBANA_SPACE:-default}"
}

elastic_api_key() {
  case "$ELASTIC_API_KEY" in
    "ApiKey "*) printf '%s' "${ELASTIC_API_KEY#ApiKey }" ;;
    *:*) printf '%s' "$ELASTIC_API_KEY" | base64 | tr -d '\n' ;;
    *) printf '%s' "$ELASTIC_API_KEY" ;;
  esac
}

elastic_es_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local key
  key="$(elastic_api_key)"

  if [[ -n "$body" ]]; then
    curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -fsS \
      -X "$method" \
      -H "Authorization: ApiKey $key" \
      -H "Content-Type: application/json" \
      "$ELASTICSEARCH_URL/$path" \
      -d "$body"
  else
    curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -fsS \
      -X "$method" \
      -H "Authorization: ApiKey $key" \
      "$ELASTICSEARCH_URL/$path"
  fi
}

elastic_kibana_prefix() {
  if [[ "$KIBANA_SPACE" == "default" ]]; then
    printf '%s' "$KIBANA_URL"
  else
    printf '%s/s/%s' "$KIBANA_URL" "$KIBANA_SPACE"
  fi
}

elastic_kibana_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local key
  local base
  key="$(elastic_api_key)"
  base="$(elastic_kibana_prefix)"

  if [[ -n "$body" ]]; then
    curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -fsS \
      -X "$method" \
      -H "Authorization: ApiKey $key" \
      -H "Content-Type: application/json" \
      -H "kbn-xsrf: opamp-poc" \
      "$base/$path" \
      -d "$body"
  else
    curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -fsS \
      -X "$method" \
      -H "Authorization: ApiKey $key" \
      -H "kbn-xsrf: opamp-poc" \
      "$base/$path"
  fi
}

elastic_require_kibana() {
  if [[ -z "$KIBANA_URL" ]]; then
    echo "KIBANA_URL is required for Kibana saved objects and Security rules" >&2
    echo "Set it in secrets/elastic-cloud.env or export it before running this task." >&2
    return 1
  fi
}

elastic_json_array_items() {
  local file="$1"
  local filter="$2"
  jq -c "$filter"'[]' "$file"
}
