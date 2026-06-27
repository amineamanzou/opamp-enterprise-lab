#!/usr/bin/env bash
set -euo pipefail

shell_export=0

if [[ "${1:-}" == "--shell-export" ]]; then
  shell_export=1
  shift
fi

if [[ $# -ne 2 ]]; then
  echo "usage: $0 [--shell-export] <input.sops.yaml> <output.env>" >&2
  exit 1
fi

input_sops="$1"
output_env="$2"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
default_age_key_file="$repo_root/secrets/age/operator.txt"

if [[ ! -f "$input_sops" ]]; then
  echo "input file not found: $input_sops" >&2
  exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
  echo "sops is required" >&2
  exit 1
fi

if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
  if [[ -f "$default_age_key_file" ]]; then
    export SOPS_AGE_KEY_FILE="$default_age_key_file"
  fi
fi

mkdir -p "$(dirname "$output_env")"
tmp_env="$(mktemp)"
trap 'rm -f "$tmp_env"' EXIT

sops --decrypt --output-type yaml "$input_sops" | ruby -e '
  require "yaml"

  shell_export = ARGV[0] == "1"
  data = YAML.safe_load($stdin.read, aliases: false) || {}
  abort "expected top-level mapping" unless data.is_a?(Hash)

  data.each do |key, value|
    next if value.nil?
    prefix = shell_export ? "export " : ""
    puts "#{prefix}#{key}=#{value}"
  end
' "$shell_export" > "$tmp_env"

chmod 600 "$tmp_env"
mv "$tmp_env" "$output_env"
