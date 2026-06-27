#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

status=0

scan_paths=()
for path in docs/evidence .github/workflows scripts/qa; do
  if [[ -e "$path" ]]; then
    scan_paths+=("$path")
  fi
done

if [[ ${#scan_paths[@]} -eq 0 ]]; then
  exit 0
fi

patterns=(
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
  'xox[baprs]-[A-Za-z0-9-]+'
  'gh[pousr]_[A-Za-z0-9_]{36,}'
  'sk-[A-Za-z0-9]{20,}'
  'https?://[^[:space:]]+:[^[:space:]@]+@'
)

for pattern in "${patterns[@]}"; do
  if rg --hidden --line-number --color never -e "$pattern" "${scan_paths[@]}"; then
    printf 'Potential secret matched pattern: %s\n' "$pattern" >&2
    status=1
  fi
done

if rg --hidden --line-number --color never \
  -e '([0-9]{1,3}\.){3}[0-9]{1,3}' \
  docs/evidence 2>/dev/null \
  | rg -v '(^|[^0-9])(0\.0\.0\.0|127\.0\.0\.1|192\.0\.2\.[0-9]{1,3}|198\.51\.100\.[0-9]{1,3}|203\.0\.113\.[0-9]{1,3})([^0-9]|$)'; then
  printf 'Potential public or private IPv4 address found in docs/evidence; redact or justify before publishing.\n' >&2
  status=1
fi

exit "$status"
