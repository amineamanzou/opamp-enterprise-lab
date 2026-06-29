#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GOCACHE="${GOCACHE:-/tmp/opamp-poc-go-cache}"
export GOMODCACHE="${GOMODCACHE:-/tmp/opamp-poc-ocb-go-mod-cache}"
export GOTOOLCHAIN="${GOTOOLCHAIN:-go1.25.5}"
export CGO_ENABLED="${CGO_ENABLED:-0}"
export GOOS="${GOOS:-linux}"
export GOARCH="${GOARCH:-amd64}"
mkdir -p "$GOCACHE" "$GOMODCACHE"

manifests=(
  "$root/lab/collector-ocb/otelcol-logs-min.yaml"
  "$root/lab/collector-ocb/otelcol-logs-opamp.yaml"
)

binaries=(
  "$root/dist/otelcol-logs-min/otelcol-logs-min"
  "$root/dist/otelcol-logs-opamp/otelcol-logs-opamp"
)

checksum_file="$root/dist/ocb/SHA256SUMS"

for manifest in "${manifests[@]}"; do
  test -f "$manifest"
  grep -q "dist:" "$manifest"
  grep -q "receivers:" "$manifest"
  grep -q "exporters:" "$manifest"
  grep -q "kafkaexporter" "$manifest"
  grep -q "processors:" "$manifest"
  grep -q "extensions:" "$manifest"
done

if [ "${OCB_FORCE_REBUILD:-0}" != "1" ] && [ -f "$checksum_file" ]; then
  cached_binaries=true
  for binary in "${binaries[@]}"; do
    if [ ! -x "$binary" ]; then
      cached_binaries=false
    fi
  done

  if [ "$cached_binaries" = true ]; then
    (
      cd "$root"
      shasum -a 256 -c dist/ocb/SHA256SUMS
    )
    echo "OCB binaries already available; set OCB_FORCE_REBUILD=1 to rebuild"
    exit 0
  fi
fi

if command -v ocb >/dev/null 2>&1; then
  mkdir -p "$root/dist/ocb"
  ocb --config "$root/lab/collector-ocb/otelcol-logs-min.yaml"
  ocb --config "$root/lab/collector-ocb/otelcol-logs-opamp.yaml"
elif command -v builder >/dev/null 2>&1; then
  mkdir -p "$root/dist/ocb"
  builder --config "$root/lab/collector-ocb/otelcol-logs-min.yaml"
  builder --config "$root/lab/collector-ocb/otelcol-logs-opamp.yaml"
else
  echo "ocb builder not installed; manifests validated statically"
  exit 0
fi

for binary in "${binaries[@]}"; do
  test -x "$binary"
done

(
  cd "$root"
  shasum -a 256 \
    dist/otelcol-logs-min/otelcol-logs-min \
    dist/otelcol-logs-opamp/otelcol-logs-opamp \
    > dist/ocb/SHA256SUMS
)

echo "OCB binaries built and checksums written to dist/ocb/SHA256SUMS"
