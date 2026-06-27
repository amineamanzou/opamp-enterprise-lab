#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$root/lab/opamp-server/bin"
mkdir -p "$out_dir"

(
  cd "$root/lab/opamp-server"
  GOCACHE="${GOCACHE:-/tmp/opamp-poc-go-cache}" GOMODCACHE="${GOMODCACHE:-/tmp/opamp-poc-go-mod-cache}" go test ./...
  CGO_ENABLED=0 GOOS="${OPAMP_SERVER_GOOS:-linux}" GOARCH="${OPAMP_SERVER_GOARCH:-amd64}" \
    GOCACHE="${GOCACHE:-/tmp/opamp-poc-go-cache}" GOMODCACHE="${GOMODCACHE:-/tmp/opamp-poc-go-mod-cache}" \
    go build -trimpath -o "$out_dir/opamp-poc-server" ./cmd/opamp-poc-server
)

if command -v shasum >/dev/null 2>&1; then
  (cd "$out_dir" && shasum -a 256 opamp-poc-server > opamp-poc-server.sha256)
fi

echo "$out_dir/opamp-poc-server"
