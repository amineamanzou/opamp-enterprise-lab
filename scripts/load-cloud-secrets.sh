#!/usr/bin/env bash
# Source this file from a shell: source scripts/load-cloud-secrets.sh
set -euo pipefail

if [[ -n "${BASH_SOURCE[0]-}" ]]; then
  script_path="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  script_path="${(%):-%x}"
else
  script_path="$0"
fi

root="$(cd "$(dirname "$script_path")/.." && pwd)"

for env_file in "$root/secrets/hcloud.env" "$root/secrets/elastic-cloud.env" "$root/secrets/opamp.env"; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [[ -z "${TF_VAR_hcloud_token:-}" && -n "${HCLOUD_TOKEN:-}" ]]; then
  export TF_VAR_hcloud_token="$HCLOUD_TOKEN"
fi

if [[ -n "${ELASTIC_OTLP_ENDPOINT:-}" ]]; then
  case "$ELASTIC_OTLP_ENDPOINT" in
    http://*|https://*) ;;
    *) export ELASTIC_OTLP_ENDPOINT="https://$ELASTIC_OTLP_ENDPOINT" ;;
  esac
fi

export HCLOUD_TOKEN="${HCLOUD_TOKEN:-${TF_VAR_hcloud_token:-}}"

echo "loaded cloud secrets into current shell"
