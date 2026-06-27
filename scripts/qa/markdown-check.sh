#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
status=0

while IFS= read -r file; do
  if grep -n $'\t' "$file" >/tmp/opamp-poc-md-tabs.txt; then
    cat /tmp/opamp-poc-md-tabs.txt >&2
    status=1
  fi
  if [ "$(tail -c 1 "$file" | wc -l | tr -d ' ')" = "0" ]; then
    echo "$file: missing trailing newline" >&2
    status=1
  fi
done < <(find "$root" -path "$root/.git" -prune -o -name '*.md' -type f -print)

if [ "$status" -ne 0 ]; then
  echo "markdown check failed" >&2
  exit "$status"
fi

echo "markdown check passed"
