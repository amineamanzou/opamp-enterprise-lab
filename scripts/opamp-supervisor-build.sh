#!/usr/bin/env bash
set -euo pipefail

version="${OPAMP_SUPERVISOR_VERSION:-0.151.0}"
os_name="${OPAMP_SUPERVISOR_OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
arch_name="${OPAMP_SUPERVISOR_ARCH:-$(uname -m)}"

case "$arch_name" in
  x86_64|amd64) arch_name="amd64" ;;
  arm64|aarch64) arch_name="arm64" ;;
  *) echo "unsupported architecture: $arch_name" >&2; exit 1 ;;
esac

case "$os_name" in
  linux|darwin) ;;
  *) echo "unsupported OS: $os_name" >&2; exit 1 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$root/lab/opamp-supervisor/bin"
mkdir -p "$out_dir"

binary="opampsupervisor_${version}_${os_name}_${arch_name}"
url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fopampsupervisor%2Fv${version}/${binary}"
target="$out_dir/opampsupervisor"

if [ "${OPAMP_SUPERVISOR_DOWNLOAD:-1}" = "0" ]; then
  printf '%s\n' "$url" > "$out_dir/download-url.txt"
  echo "download disabled; wrote $out_dir/download-url.txt"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download opampsupervisor" >&2
  exit 1
fi

curl --fail --location --show-error --output "$target" "$url"
chmod +x "$target"

if command -v shasum >/dev/null 2>&1; then
  (cd "$out_dir" && shasum -a 256 opampsupervisor > opampsupervisor.sha256)
fi

echo "$target"
