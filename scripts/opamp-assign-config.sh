#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <ring> <config-file>" >&2
  exit 2
fi

ring="$1"
config_path="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$root/lab/ansible/inventory/hosts.ini"

if [ ! -f "$config_path" ]; then
  echo "config file not found: $config_path" >&2
  exit 1
fi

opamp_host="$(awk '$1 == "opamp-poc-opamp" { for (i = 1; i <= NF; i++) if ($i ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $i); print $i } }' "$inventory")"
if [ -z "$opamp_host" ]; then
  echo "could not resolve opamp host from $inventory" >&2
  exit 1
fi

jq -n --arg ring "$ring" --rawfile config "$config_path" '{ring: $ring, config: $config}' |
  ssh -o UserKnownHostsFile=/tmp/opamp_poc_known_hosts -o StrictHostKeyChecking=accept-new "root@$opamp_host" \
    "curl -fsS -X PUT http://127.0.0.1:4321/v1/rings/$ring/config -H 'Content-Type: application/json' --data-binary @-"
