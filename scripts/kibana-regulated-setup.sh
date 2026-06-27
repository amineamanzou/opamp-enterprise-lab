#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ndjson="$root/lab/configs/elastic/regulated-observability-kibana.ndjson"

if [ -z "${KIBANA_URL:-}" ]; then
  echo "KIBANA_URL is not set. Import this file manually in Kibana Saved Objects:" >&2
  echo "$ndjson" >&2
  exit 0
fi

auth_args=()
if [ -n "${KIBANA_API_KEY:-}" ]; then
  auth_args=(-H "Authorization: ApiKey $KIBANA_API_KEY")
elif [ -n "${KIBANA_USERNAME:-}" ] && [ -n "${KIBANA_PASSWORD:-}" ]; then
  auth_args=(-u "$KIBANA_USERNAME:$KIBANA_PASSWORD")
else
  echo "Set KIBANA_API_KEY or KIBANA_USERNAME/KIBANA_PASSWORD" >&2
  exit 1
fi

curl --connect-timeout 10 --max-time 60 -fsS \
  "${auth_args[@]}" \
  -H "kbn-xsrf: opamp-poc" \
  -F "file=@$ndjson" \
  "${KIBANA_URL%/}/api/saved_objects/_import?overwrite=true"
