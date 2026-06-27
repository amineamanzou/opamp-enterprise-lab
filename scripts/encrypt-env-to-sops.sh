#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <input.env> <output.sops.yaml>" >&2
  exit 1
fi

input_env="$1"
output_sops="$2"

if [[ ! -f "$input_env" ]]; then
  echo "input file not found: $input_env" >&2
  exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
  echo "sops is required" >&2
  exit 1
fi

tmp_yaml="$(mktemp)"
trap 'rm -f "$tmp_yaml"' EXIT

ruby -e '
  require "yaml"

  data = {}

  File.foreach(ARGV[0]) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    line = line.sub(/\Aexport\s+/, "")
    key, value = line.split("=", 2)
    next unless key && value
    next unless key.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)

    data[key] = value
  end

  File.write(ARGV[1], YAML.dump(data))
' "$input_env" "$tmp_yaml"

sops --encrypt \
  --filename-override "$output_sops" \
  --input-type yaml \
  --output-type yaml \
  "$tmp_yaml" > "$output_sops"
