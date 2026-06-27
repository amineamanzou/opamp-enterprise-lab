#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$root/lab/ansible/inventory/hosts.ini"
binary="$root/lab/opamp-server/bin/opamp-agent-swarm"
counts="${OPAMP_AGENT_SCALE_COUNTS:-100 250 500 1000 2000}"
duration="${OPAMP_AGENT_SCALE_DURATION:-5m}"
ramp="${OPAMP_AGENT_SCALE_RAMP_PER_SECOND:-50}"
heartbeat="${OPAMP_AGENT_SCALE_HEARTBEAT:-30s}"
ring="${OPAMP_AGENT_SCALE_RING:-scale}"
hostname_prefix="${OPAMP_AGENT_SCALE_HOSTNAME_PREFIX:-opamp-scale}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="${OPAMP_AGENT_SCALE_OUT_DIR:-$root/tmp/opamp-agent-scale-$timestamp}"
csv="$out_dir/opamp-agent-scale.csv"

if [ ! -x "$binary" ]; then
  echo "missing $binary; run task opamp:agent-swarm:build first" >&2
  exit 1
fi

opamp_host="$(awk '$1 == "opamp-poc-opamp" { for (i = 1; i <= NF; i++) if ($i ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $i); print $i } }' "$inventory")"
agent_host="$(awk '$1 == "opamp-poc-agent" { for (i = 1; i <= NF; i++) if ($i ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $i); print $i } }' "$inventory")"
if [ -z "$opamp_host" ] || [ -z "$agent_host" ]; then
  echo "could not resolve opamp or host-agent from $inventory" >&2
  exit 1
fi

token="${OPAMP_AUTH_TOKEN:-}"
if [ -z "$token" ] && [ -f "$root/secrets/opamp.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$root/secrets/opamp.env"
  set +a
  token="${OPAMP_AUTH_TOKEN:-}"
fi
token_b64="$(printf '%s' "$token" | base64 | tr -d '\n')"

mkdir -p "$out_dir"
printf 'timestamp_utc,phase,target_agents,server_agents,server_connected_agents,server_connections,server_limited_metadata,server_heap_alloc_bytes,server_runtime_sys_bytes,server_goroutines,client_connected_callbacks,client_connect_failed,client_errors,client_remote_configs\n' > "$csv"

ssh_opts=(-o UserKnownHostsFile=/tmp/opamp_poc_known_hosts -o StrictHostKeyChecking=accept-new)
scp "${ssh_opts[@]}" "$binary" "root@$agent_host:/opt/opamp-poc/opamp-agent-swarm"
ssh "${ssh_opts[@]}" "root@$agent_host" "chmod +x /opt/opamp-poc/opamp-agent-swarm"

capture_stats() {
  local phase="$1"
  local count="$2"
  local client_file="${3:-}"
  local stats_json="$out_dir/stats-${count}-${phase}.json"
  ssh "${ssh_opts[@]}" "root@$opamp_host" "curl -fsS http://127.0.0.1:4321/v1/stats" > "$stats_json"
  if [ -n "$client_file" ]; then
    client_args=(--slurpfile client "$client_file")
  else
    client_args=(--argjson client '[{}]')
  fi
  jq -r --arg phase "$phase" --arg count "$count" "${client_args[@]}" '
    . as $s |
    ($client[0] // {}) as $c |
    [
      now | strftime("%Y-%m-%dT%H:%M:%SZ"),
      $phase,
      $count,
      $s.agents,
      $s.connected_agents,
      $s.connections,
      $s.limited_metadata_agents,
      $s.heap_alloc_bytes,
      $s.runtime_sys_bytes,
      $s.num_goroutine,
      ($c.connected // ""),
      ($c.connect_failed // ""),
      ($c.errors // ""),
      ($c.remote_configs // "")
    ] | @csv
  ' "$stats_json" >> "$csv"
}

for count in $counts; do
  echo "running agent scale count=$count duration=$duration ramp=$ramp/s" >&2
  capture_stats before "$count"
  remote_json="/tmp/opamp-agent-scale-${timestamp}-${count}.json"
  remote_err="/tmp/opamp-agent-scale-${timestamp}-${count}.err"
  remote_pid="$(
    ssh "${ssh_opts[@]}" "root@$agent_host" \
      "sh -c 'OPAMP_AUTH_TOKEN=\"\$(printf %s '$token_b64' | base64 -d)\" /opt/opamp-poc/opamp-agent-swarm --endpoint \"ws://$opamp_host:4320/v1/opamp\" --token \"\$OPAMP_AUTH_TOKEN\" --agents \"$count\" --ring \"$ring\" --hostname-prefix \"$hostname_prefix\" --duration \"$duration\" --ramp-per-second \"$ramp\" --heartbeat \"$heartbeat\" > \"$remote_json\" 2> \"$remote_err\" & echo \$!'"
  )"
  ramp_wait=$(( (count + ramp - 1) / ramp + 5 ))
  sleep "$ramp_wait"
  capture_stats during "$count"
  ssh "${ssh_opts[@]}" "root@$agent_host" "while kill -0 '$remote_pid' 2>/dev/null; do sleep 1; done"
  remote_json_content="$(ssh "${ssh_opts[@]}" "root@$agent_host" "cat '$remote_json'")"
  ssh "${ssh_opts[@]}" "root@$agent_host" "cat '$remote_err' >&2 || true"
  client_file="$out_dir/client-${count}.json"
  printf '%s\n' "$remote_json_content" > "$client_file"
  capture_stats after "$count" "$client_file"
  sleep 10
done

echo "$out_dir"
