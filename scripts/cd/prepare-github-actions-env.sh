#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

required_env=(
  CD_OPERATION
  CD_OPERATOR_CIDR
  HCLOUD_TOKEN
  ELASTIC_OTLP_ENDPOINT
  ELASTIC_API_KEY
  OPAMP_AUTH_TOKEN
  LAB_SSH_PRIVATE_KEY
  LAB_SSH_PUBLIC_KEY
  TF_STATE_S3_BUCKET
  TF_STATE_S3_REGION
  TF_STATE_S3_ENDPOINT
  TF_STATE_S3_ACCESS_KEY_ID
  TF_STATE_S3_SECRET_ACCESS_KEY
)

for name in "${required_env[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required environment variable: %s\n' "$name" >&2
    exit 1
  fi
done

case "$CD_OPERATION" in
  plan | apply | runtime | destroy) ;;
  *)
    printf 'CD_OPERATION must be one of: plan, apply, runtime, destroy\n' >&2
    exit 1
    ;;
esac

if [[ "$CD_OPERATOR_CIDR" != */* ]]; then
  printf 'CD_OPERATOR_CIDR must be a CIDR, for example 203.0.113.10/32\n' >&2
  exit 1
fi

project_name="${CD_PROJECT_NAME:-opamp-enterprise-lab}"
default_state_key="${GITHUB_REPOSITORY:-opamp-enterprise-lab}/hcloud.tfstate"
state_key="${TF_STATE_S3_KEY:-$default_state_key}"
export CD_PROJECT_NAME="$project_name"
export CD_STATE_KEY="$state_key"
runner_cidrs_file="tmp/github-runner-cidrs.txt"
operator_cidrs_file="tmp/operator-cidrs.txt"
all_ssh_cidrs_file="tmp/all-ssh-cidrs.txt"

mkdir -p secrets tmp/cd-ssh lab/infra/hcloud

{
  printf 'export HCLOUD_TOKEN=%q\n' "$HCLOUD_TOKEN"
  printf 'export TF_VAR_hcloud_token=%q\n' "$HCLOUD_TOKEN"
} > secrets/hcloud.env

{
  printf 'export ELASTIC_OTLP_ENDPOINT=%q\n' "$ELASTIC_OTLP_ENDPOINT"
  printf 'export ELASTIC_API_KEY=%q\n' "$ELASTIC_API_KEY"
} > secrets/elastic-cloud.env

{
  printf 'export OPAMP_AUTH_TOKEN=%q\n' "$OPAMP_AUTH_TOKEN"
} > secrets/opamp.env

chmod 600 secrets/hcloud.env secrets/elastic-cloud.env secrets/opamp.env

printf '%s\n' "$LAB_SSH_PRIVATE_KEY" > tmp/cd-ssh/opamp_lab
printf '%s\n' "$LAB_SSH_PUBLIC_KEY" > tmp/cd-ssh/opamp_lab.pub
chmod 600 tmp/cd-ssh/opamp_lab
chmod 644 tmp/cd-ssh/opamp_lab.pub

cat > lab/infra/hcloud/backend.cd.tf <<'EOF_BACKEND_TF'
terraform {
  backend "s3" {}
}
EOF_BACKEND_TF

ruby <<'RUBY' > lab/infra/hcloud/backend.cd.hcl
def quote(value)
  value.to_s.dump
end

bools = {
  "use_path_style" => ENV.fetch("TF_STATE_S3_USE_PATH_STYLE", "true"),
  "skip_region_validation" => ENV.fetch("TF_STATE_S3_SKIP_REGION_VALIDATION", "true"),
  "skip_credentials_validation" => ENV.fetch("TF_STATE_S3_SKIP_CREDENTIALS_VALIDATION", "true"),
  "skip_requesting_account_id" => ENV.fetch("TF_STATE_S3_SKIP_REQUESTING_ACCOUNT_ID", "true"),
  "skip_metadata_api_check" => ENV.fetch("TF_STATE_S3_SKIP_METADATA_API_CHECK", "true")
}

puts "bucket = #{quote(ENV.fetch("TF_STATE_S3_BUCKET"))}"
puts "key    = #{quote(ENV.fetch("CD_STATE_KEY"))}"
puts "region = #{quote(ENV.fetch("TF_STATE_S3_REGION"))}"
puts
puts "access_key = #{quote(ENV.fetch("TF_STATE_S3_ACCESS_KEY_ID"))}"
puts "secret_key = #{quote(ENV.fetch("TF_STATE_S3_SECRET_ACCESS_KEY"))}"
puts
puts "endpoints = {"
puts "  s3 = #{quote(ENV.fetch("TF_STATE_S3_ENDPOINT"))}"
puts "}"
puts
bools.each do |key, value|
  unless %w[true false].include?(value)
    warn "#{key} must be true or false"
    exit 1
  end
  puts "#{key} = #{value}"
end
RUBY

if [[ -n "${CD_GITHUB_ACTIONS_CIDRS:-}" ]]; then
  printf '%s\n' "$CD_GITHUB_ACTIONS_CIDRS" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | awk 'NF' > "$runner_cidrs_file"
else
  if ! command -v curl >/dev/null 2>&1; then
    printf 'curl is required to resolve the current runner SSH CIDR. Set CD_GITHUB_ACTIONS_CIDRS to override.\n' >&2
    exit 1
  fi

  runner_ipv4="$(curl -4fsSL https://api.ipify.org || true)"
  if [[ -z "$runner_ipv4" ]]; then
    printf 'Unable to resolve the current runner public IPv4. Set CD_GITHUB_ACTIONS_CIDRS to override.\n' >&2
    exit 1
  fi
  printf '%s/32\n' "$runner_ipv4" > "$runner_cidrs_file"
fi

if [[ ! -s "$runner_cidrs_file" ]]; then
  printf 'No GitHub runner SSH CIDRs were resolved.\n' >&2
  exit 1
fi

printf '%s\n' "$CD_OPERATOR_CIDR" > "$operator_cidrs_file"
cat "$operator_cidrs_file" "$runner_cidrs_file" | sort -u > "$all_ssh_cidrs_file"

ruby <<'RUBY' > lab/infra/hcloud/github-actions.auto.tfvars.json
require "json"

def read_lines(path)
  File.readlines(path, chomp: true).map(&:strip).reject(&:empty?)
end

operator_cidrs = read_lines("tmp/operator-cidrs.txt")
ssh_cidrs = read_lines("tmp/all-ssh-cidrs.txt")

data = {
  "project_name" => ENV.fetch("CD_PROJECT_NAME", "opamp-enterprise-lab"),
  "ssh_public_key_path" => File.expand_path("tmp/cd-ssh/opamp_lab.pub", Dir.pwd),
  "allowed_ssh_cidrs" => ssh_cidrs,
  "allowed_http_cidrs" => operator_cidrs,
  "allowed_opamp_cidrs" => operator_cidrs,
  "allowed_admin_api_cidrs" => operator_cidrs,
  "allowed_otlp_cidrs" => operator_cidrs,
  "allowed_k3s_api_cidrs" => [],
  "allowed_k3s_peer_cidrs" => [],
  "enable_optional_load_host" => false,
  "enable_host_agent_vm" => true,
  "enable_kubernetes_vms" => false,
  "labels" => {
    "owner" => "github-actions",
    "cost-center" => "lab"
  }
}

puts JSON.pretty_generate(data)
RUBY

printf 'Generated GitHub Actions CD environment files.\n'
printf 'Terraform backend config: %s\n' "lab/infra/hcloud/backend.cd.hcl"
printf 'Terraform variables: %s\n' "lab/infra/hcloud/github-actions.auto.tfvars.json"
printf 'SSH CIDRs allowed: %s\n' "$(wc -l < "$all_ssh_cidrs_file" | tr -d ' ')"
printf 'Operator CIDRs allowed for app endpoints: %s\n' "$(wc -l < "$operator_cidrs_file" | tr -d ' ')"
