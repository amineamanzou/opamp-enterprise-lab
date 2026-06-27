#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <agent-id>" >&2
  exit 2
fi

agent_id="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$root/lab/ansible/inventory/hosts.ini"

opamp_host="$(awk '$1 == "opamp-poc-opamp" { for (i = 1; i <= NF; i++) if ($i ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $i); print $i } }' "$inventory")"
if [ -z "$opamp_host" ]; then
  echo "could not resolve opamp host from $inventory" >&2
  exit 1
fi

encoded_id="$(printf '%s' "$agent_id" | jq -sRr @uri)"
ssh -o UserKnownHostsFile=/tmp/opamp_poc_known_hosts -o StrictHostKeyChecking=accept-new "root@$opamp_host" \
  "curl -fsS -X POST http://127.0.0.1:4321/v1/agents/$encoded_id/restart"
