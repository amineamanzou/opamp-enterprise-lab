#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rendered=0

if [[ -f "$root/secrets.encrypted/hcloud.sops.yaml" ]]; then
  "$root/scripts/render-env-from-sops.sh" --shell-export \
    "$root/secrets.encrypted/hcloud.sops.yaml" \
    "$root/secrets/hcloud.env"
  rendered=1
fi

if [[ -f "$root/secrets.encrypted/elastic-cloud.sops.yaml" ]]; then
  "$root/scripts/render-env-from-sops.sh" --shell-export \
    "$root/secrets.encrypted/elastic-cloud.sops.yaml" \
    "$root/secrets/elastic-cloud.env"
  rendered=1
fi

if [[ -f "$root/secrets.encrypted/opamp.sops.yaml" ]]; then
  "$root/scripts/render-env-from-sops.sh" --shell-export \
    "$root/secrets.encrypted/opamp.sops.yaml" \
    "$root/secrets/opamp.env"
  rendered=1
fi

if [[ "$rendered" -eq 0 ]]; then
  echo "no SOPS files found under secrets.encrypted/" >&2
  exit 1
fi

echo "rendered local secret env files under secrets/"
