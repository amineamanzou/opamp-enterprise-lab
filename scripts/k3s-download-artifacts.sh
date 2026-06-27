#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${K3S_VERSION:-v1.36.1+k3s1}"
base_url="https://github.com/k3s-io/k3s/releases/download/${version}"
out_dir="$root/tmp/k3s/$version"
binary="$out_dir/k3s"
checksum_file="$out_dir/sha256sum-amd64.txt"

mkdir -p "$out_dir"

if [ ! -f "$checksum_file" ]; then
  curl --fail --location --silent --show-error \
    "$base_url/sha256sum-amd64.txt" \
    -o "$checksum_file"
fi

if [ ! -f "$binary" ]; then
  curl --fail --location --silent --show-error \
    "$base_url/k3s" \
    -o "$binary"
  chmod 0755 "$binary"
fi

expected="$(awk '$2 == "k3s" {print $1}' "$checksum_file")"
if [ -z "$expected" ]; then
  echo "could not find k3s checksum in $checksum_file" >&2
  exit 1
fi

actual="$(shasum -a 256 "$binary" | awk '{print $1}')"
if [ "$actual" != "$expected" ]; then
  echo "checksum mismatch for $binary" >&2
  exit 1
fi

echo "$binary"
