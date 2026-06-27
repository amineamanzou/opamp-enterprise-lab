#!/usr/bin/env bash
set -euo pipefail

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required to render inventory from outputs" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to render inventory from Terraform JSON outputs" >&2
  exit 1
fi

output_json="$(terraform output -json)"
if [ -z "$output_json" ] || [ "$output_json" = "{}" ]; then
  echo "terraform outputs are empty; run terraform apply first" >&2
  exit 1
fi

inventory_dir="../../ansible/inventory"
inventory_file="$inventory_dir/hosts.ini"
mkdir -p "$inventory_dir/group_vars"

jq -r '
  [.servers.value[]] as $servers |
  def hostline:
    .name + " ansible_user=root ansible_host=" + .public_host;
  def group($name; $roles):
    "[" + $name + "]\n" + (
      $servers
      | map(select(.role as $role | $roles | index($role)))
      | map(hostline)
      | join("\n")
    ) + "\n";
  group("opamp_server"; ["opamp_server"]),
  group("host_agents"; ["host_agents", "optional_load"]),
  group("k3s_servers"; ["k3s_server"]),
  group("k3s_workers"; ["k3s_worker"]),
  "[lab:children]\nopamp_server\nhost_agents\nk3s_servers\nk3s_workers\n",
  "[collectors:children]\nhost_agents\nk3s_servers\nk3s_workers\n"
' <<<"$output_json" > "$inventory_file"

cp "../../ansible/group_vars/all.yml" "$inventory_dir/group_vars/all.yml"

echo "$inventory_file"
