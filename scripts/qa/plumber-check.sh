#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

if [[ -n "${PLUMBER_GITHUB_TOKEN:-}" ]]; then
  export GH_TOKEN="$PLUMBER_GITHUB_TOKEN"
elif [[ -n "${GH_TOKEN:-}" ]]; then
  export GH_TOKEN
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  export GH_TOKEN="$GITHUB_TOKEN"
fi

install_plumber() {
  local os arch asset tmp_dir

  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux) os="linux" ;;
    darwin) os="darwin" ;;
    *) printf 'Unsupported OS for Plumber binary install: %s\n' "$os" >&2; return 1 ;;
  esac

  case "$arch" in
    x86_64 | amd64) arch="amd64" ;;
    arm64 | aarch64) arch="arm64" ;;
    *) printf 'Unsupported architecture for Plumber binary install: %s\n' "$arch" >&2; return 1 ;;
  esac

  asset="plumber-${os}-${arch}"
  tmp_dir="$(mktemp -d)"
  curl -fsSL "https://github.com/getplumber/plumber/releases/latest/download/${asset}" -o "${tmp_dir}/plumber"
  chmod +x "${tmp_dir}/plumber"
  export PATH="${tmp_dir}:$PATH"
}

if ! command -v plumber >/dev/null 2>&1; then
  install_plumber
fi

plumber config validate
plumber analyze --config .plumber.yaml --threshold "${PLUMBER_THRESHOLD:-100}"
