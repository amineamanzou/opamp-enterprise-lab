#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=elastic-lib.sh
source "$root/scripts/elastic-lib.sh"
elastic_load_env

opamp_url="${OPAMP_ADMIN_URL:-${OPAMP_VANILLA_UI_URL:-http://127.0.0.1:4321}}"
opamp_url="${opamp_url%/}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
snapshot_id="${OPAMP_SNAPSHOT_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
out="${OPAMP_SNAPSHOT_OUT:-$root/tmp/opamp-elastic-snapshot}"
mkdir -p "$out"

curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/inventory" > "$out/inventory.json"
curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/stats" > "$out/stats.json"
curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/opamp/connections" > "$out/connections.json"
curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/events?limit=${OPAMP_EVENTS_LIMIT:-5000}" > "$out/events.json"

bulk="$out/opamp-snapshot.ndjson"
: > "$bulk"

jq -c --arg ts "$timestamp" --arg sid "$snapshot_id" --arg url "$opamp_url" '
  .agents[]? |
  {"create": {"_index": "logs-opamp.inventory-lab"}},
  {
    "@timestamp": $ts,
    "data_stream": {"type": "logs", "dataset": "opamp.inventory", "namespace": "lab"},
    "event": {"kind": "state", "category": "configuration", "type": "info", "action": "inventory_snapshot"},
    "opamp": {"source": "vanilla-server", "server_url": $url, "snapshot_id": $sid},
    "agent": {
      "id": .id,
      "instance_uid": .instance_uid,
      "ring": .ring,
      "version": .version,
      "hostname": .hostname,
      "health": .health,
      "capabilities": .capabilities,
      "desired_config_hash": .desired_config_hash,
      "effective_config": .effective_config,
      "remote_config_status": .remote_config_status,
      "restart_command_pending": .restart_command_pending,
      "connected": .connected,
      "updated_at": .updated_at,
      "limited_metadata": (.limited_metadata // false)
    }
  }
' "$out/inventory.json" >> "$bulk"

jq -c --arg ts "$timestamp" --arg sid "$snapshot_id" --arg url "$opamp_url" '
  {"create": {"_index": "metrics-opamp.server-lab"}},
  {
    "@timestamp": $ts,
    "data_stream": {"type": "metrics", "dataset": "opamp.server", "namespace": "lab"},
    "opamp": {"source": "vanilla-server", "server_url": $url, "snapshot_id": $sid},
    "server": {
      "agents": .agents,
      "connected_agents": .connected_agents,
      "connections": .connections,
      "limited_metadata_agents": .limited_metadata_agents,
      "heap_alloc_bytes": .heap_alloc_bytes,
      "heap_sys_bytes": .heap_sys_bytes,
      "runtime_sys_bytes": .runtime_sys_bytes,
      "num_goroutine": .num_goroutine,
      "collected_at": .collected_at
    }
  }
' "$out/stats.json" >> "$bulk"

jq -c --arg ts "$timestamp" --arg sid "$snapshot_id" --arg url "$opamp_url" '
  .connections[]? |
  {"create": {"_index": "logs-opamp.connections-lab"}},
  {
    "@timestamp": $ts,
    "data_stream": {"type": "logs", "dataset": "opamp.connections", "namespace": "lab"},
    "event": {"kind": "state", "category": "network", "type": "connection", "action": "connection_snapshot"},
    "opamp": {"source": "vanilla-server", "server_url": $url, "snapshot_id": $sid},
    "connection": {
      "instance_uid": .instance_uid,
      "remote_addr": .remote_addr,
      "connected": true
    }
  }
' "$out/connections.json" >> "$bulk"

jq -c \
  --arg ts "$timestamp" \
  --arg sid "$snapshot_id" \
  --arg url "$opamp_url" \
  --arg experiment_id "${EXPERIMENT_ID:-}" \
  --arg experiment_phase "${EXPERIMENT_PHASE:-snapshot}" \
  --arg target_rate "${EXPERIMENT_TARGET_RATE:-}" '
  .events[]? |
  {"create": {"_index": "logs-opamp.events-lab"}},
  {
    "@timestamp": (.timestamp // $ts),
    "data_stream": {"type": "logs", "dataset": "opamp.events", "namespace": "lab"},
    "event": {
      "kind": "event",
      "category": "configuration",
      "type": "change",
      "action": .action,
      "sequence": .sequence,
      "reason": .reason
    },
    "opamp": {"source": "vanilla-server", "server_url": $url, "snapshot_id": $sid},
    "experiment": {
      "id": (if $experiment_id == "" then null else $experiment_id end),
      "phase": (if $experiment_phase == "" then null else $experiment_phase end),
      "target_rate": (if $target_rate == "" then null else ($target_rate | tonumber) end)
    },
    "agent": {
      "id": .agent_id,
      "instance_uid": .instance_uid,
      "ring": .ring,
      "hostname": .hostname,
      "previous_version": .previous_version,
      "current_version": .current_version,
      "version_direction": .direction,
      "previous_health": .previous_health,
      "current_health": .current_health,
      "previous_status": .previous_status,
      "current_status": .current_status,
      "previous_config_hash": .previous_config_hash,
      "current_config_hash": .current_config_hash
    }
  }
' "$out/events.json" >> "$bulk"

if [[ ! -s "$bulk" ]]; then
  echo "no OpAMP snapshot documents were generated" >&2
  exit 1
fi

bulk_response="$out/bulk-response.json"
key="$(elastic_api_key)"
curl --connect-timeout 10 --max-time "${ELASTIC_API_TIMEOUT:-60}" -fsS \
  -X POST \
  -H "Authorization: ApiKey $key" \
  -H "Content-Type: application/x-ndjson" \
  "$ELASTICSEARCH_URL/_bulk" \
  --data-binary "@$bulk" \
  | jq . > "$bulk_response"

if jq -e '.errors == true' "$bulk_response" >/dev/null; then
  echo "Elastic Bulk API reported item errors" >&2
  jq '[.items[] | select((.create.status // 200) >= 300)][0:10]' "$bulk_response" >&2
  exit 1
fi

jq '{
  errors,
  took,
  created: ([.items[].create.status] | map(select(. >= 200 and . < 300)) | length),
  indices: ([.items[].create._index] | group_by(.) | map({index: .[0], count: length}))
}' "$bulk_response"
echo "$out"
