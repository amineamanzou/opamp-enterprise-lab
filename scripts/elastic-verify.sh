#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for env_file in "$root/secrets/elastic-cloud.env" "$root/secrets/opamp.env"; do
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [ -z "${ELASTIC_OTLP_ENDPOINT:-}" ] || [ -z "${ELASTIC_API_KEY:-}" ]; then
  echo "ELASTIC_OTLP_ENDPOINT and ELASTIC_API_KEY are required" >&2
  echo "See docs/runbooks/elastic-cloud-trial.md" >&2
  exit 1
fi

case "$ELASTIC_OTLP_ENDPOINT" in
  http://*|https://*) ;;
  *) ELASTIC_OTLP_ENDPOINT="https://$ELASTIC_OTLP_ENDPOINT" ;;
esac

export ELASTIC_OTLP_ENDPOINT

echo "Elastic OTLP endpoint is configured: ${ELASTIC_OTLP_ENDPOINT%/}"

if [ "${ELASTIC_PROBE:-0}" = "1" ]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required when ELASTIC_PROBE=1" >&2
    exit 1
  fi
  curl --fail --silent --show-error \
    --header "Authorization: ApiKey ${ELASTIC_API_KEY}" \
    --max-time 10 \
    "${ELASTIC_OTLP_ENDPOINT%/}" >/dev/null
  echo "Elastic endpoint probe completed"
fi
