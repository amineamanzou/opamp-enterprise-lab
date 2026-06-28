#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <collector-version>" >&2
  exit 2
fi

version="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GOCACHE="${GOCACHE:-/tmp/opamp-poc-go-cache}"
export GOMODCACHE="${GOMODCACHE:-/tmp/opamp-poc-ocb-go-mod-cache}"
export GOTOOLCHAIN="${GOTOOLCHAIN:-go1.25.5}"
export CGO_ENABLED="${CGO_ENABLED:-0}"
export GOOS="${GOOS:-linux}"
export GOARCH="${GOARCH:-amd64}"
mkdir -p "$GOCACHE" "$GOMODCACHE" "$root/dist/ocb"

if ! command -v ocb >/dev/null 2>&1 && ! command -v builder >/dev/null 2>&1; then
  echo "ocb builder is required for versioned builds" >&2
  exit 1
fi

manifest="$root/tmp/otelcol-logs-opamp-${version}.yaml"
mkdir -p "$(dirname "$manifest")"
sed \
  -e "s/name: otelcol-logs-opamp/name: otelcol-logs-opamp-${version}/" \
  -e "s#output_path: ./dist/otelcol-logs-opamp#output_path: ./dist/otelcol-logs-opamp-${version}#" \
  -e "s/otelcol_version: 0.151.0/otelcol_version: ${version}/" \
  -e "s/ v0.151.0/ v${version}/g" \
  "$root/lab/collector-ocb/otelcol-logs-opamp.yaml" > "$manifest"

if command -v ocb >/dev/null 2>&1; then
  ocb --config "$manifest"
else
  builder --config "$manifest"
fi

binary="$root/dist/otelcol-logs-opamp-${version}/otelcol-logs-opamp-${version}"
test -x "$binary"

(
  cd "$root"
  shasum -a 256 "dist/otelcol-logs-opamp-${version}/otelcol-logs-opamp-${version}" \
    > "dist/ocb/otelcol-logs-opamp-${version}.sha256"
)

echo "$binary"
