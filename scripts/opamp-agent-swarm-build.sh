#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$root/lab/opamp-server/bin"
mkdir -p "$out_dir"

(
  cd "$root/lab/opamp-server"
  CGO_ENABLED=0 GOOS="${OPAMP_SWARM_GOOS:-linux}" GOARCH="${OPAMP_SWARM_GOARCH:-amd64}" \
    GOCACHE="${GOCACHE:-/tmp/opamp-poc-go-cache}" GOMODCACHE="${GOMODCACHE:-/tmp/opamp-poc-go-mod-cache}" \
    go build -trimpath -o "$out_dir/opamp-agent-swarm" ./cmd/opamp-agent-swarm
)

if command -v shasum >/dev/null 2>&1; then
  (cd "$out_dir" && shasum -a 256 opamp-agent-swarm > opamp-agent-swarm.sha256)
fi

echo "$out_dir/opamp-agent-swarm"
