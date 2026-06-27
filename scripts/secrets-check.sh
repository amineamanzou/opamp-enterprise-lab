#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for env_file in "$root/secrets/hcloud.env" "$root/secrets/elastic-cloud.env" "$root/secrets/opamp.env"; do
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [ -z "${TF_VAR_hcloud_token:-}" ] && [ -n "${HCLOUD_TOKEN:-}" ]; then
  export TF_VAR_hcloud_token="$HCLOUD_TOKEN"
fi

if [ -n "${ELASTIC_OTLP_ENDPOINT:-}" ]; then
  case "$ELASTIC_OTLP_ENDPOINT" in
    http://*|https://*) ;;
    *) export ELASTIC_OTLP_ENDPOINT="https://$ELASTIC_OTLP_ENDPOINT" ;;
  esac
fi

required=(
  ELASTIC_OTLP_ENDPOINT
  ELASTIC_API_KEY
  OPAMP_AUTH_TOKEN
)

missing=()
if [ -z "${TF_VAR_hcloud_token:-}" ]; then
  missing+=("TF_VAR_hcloud_token or HCLOUD_TOKEN")
fi

for name in "${required[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  printf 'missing required environment variables for cloud runs:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  printf '\nSee docs/runbooks/elastic-cloud-trial.md for setup.\n' >&2
  exit 1
fi

echo "cloud-run secrets are present"
