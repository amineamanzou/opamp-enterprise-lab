#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=elastic-lib.sh
source "$root/scripts/elastic-lib.sh"
elastic_load_env

opamp_url="${OPAMP_ADMIN_URL:-${OPAMP_VANILLA_UI_URL:-http://127.0.0.1:4321}}"
opamp_url="${opamp_url%/}"
interval="${OPAMP_WATCH_INTERVAL:-15}"
duration="${OPAMP_WATCH_DURATION:-300}"
inventory_interval="${OPAMP_WATCH_INVENTORY_INTERVAL:-60}"
snapshot_id="${OPAMP_SNAPSHOT_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
out="${OPAMP_WATCH_OUT:-$root/tmp/opamp-elastic-watch-$snapshot_id}"
mkdir -p "$out"

end_epoch=$(( $(date +%s) + duration ))
last_inventory_epoch=0
after_seq="${OPAMP_EVENTS_AFTER_SEQ:-0}"

while [ "$(date +%s)" -lt "$end_epoch" ]; do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  now_epoch="$(date +%s)"
  bulk="$out/opamp-watch-$timestamp.ndjson"
  : > "$bulk"

  curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/stats" > "$out/stats-$timestamp.json"
  curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/events?after_seq=$after_seq&limit=${OPAMP_EVENTS_LIMIT:-5000}" > "$out/events-$timestamp.json"

  jq -c --arg ts "$timestamp" --arg sid "$snapshot_id" --arg url "$opamp_url" \
    --arg experiment_id "${EXPERIMENT_ID:-}" \
    --arg experiment_phase "${EXPERIMENT_PHASE:-watch}" \
    --arg target_rate "${EXPERIMENT_TARGET_RATE:-}" '
    {"create": {"_index": "metrics-opamp.server-lab"}},
    {
      "@timestamp": $ts,
      "data_stream": {"type": "metrics", "dataset": "opamp.server", "namespace": "lab"},
      "opamp": {"source": "vanilla-server", "server_url": $url, "snapshot_id": $sid},
      "experiment": {
        "id": (if $experiment_id == "" then null else $experiment_id end),
        "phase": (if $experiment_phase == "" then null else $experiment_phase end),
        "target_rate": (if $target_rate == "" then null else ($target_rate | tonumber) end)
      },
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
  ' "$out/stats-$timestamp.json" >> "$bulk"

  jq -c --arg ts "$timestamp" --arg sid "$snapshot_id" --arg url "$opamp_url" \
    --arg experiment_id "${EXPERIMENT_ID:-}" \
    --arg experiment_phase "${EXPERIMENT_PHASE:-watch}" \
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
  ' "$out/events-$timestamp.json" >> "$bulk"

  if [ $((now_epoch - last_inventory_epoch)) -ge "$inventory_interval" ]; then
    curl --connect-timeout 10 --max-time 30 -fsS "$opamp_url/v1/inventory" > "$out/inventory-$timestamp.json"
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
    ' "$out/inventory-$timestamp.json" >> "$bulk"
    last_inventory_epoch="$now_epoch"
  fi

  if [ -s "$bulk" ]; then
    bulk_response="$out/bulk-response-$timestamp.json"
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
    after_seq="$(jq -r --arg current "$after_seq" '[.events[]?.sequence] | max // ($current | tonumber)' "$out/events-$timestamp.json")"
  fi

  sleep "$interval"
done

echo "$out"
