#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

status=0
scan_paths=()

for path in README.md docs lab .github/workflows scripts; do
  if [[ -e "$path" ]]; then
    scan_paths+=("$path")
  fi
done

if [[ ${#scan_paths[@]} -eq 0 ]]; then
  echo "anonymization check passed"
  exit 0
fi

patterns=(
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
  'xox[baprs]-[A-Za-z0-9-]+'
  'gh[pousr]_[A-Za-z0-9_]{36,}'
  'sk-[A-Za-z0-9]{20,}'
  'Bearer [A-Za-z0-9._-]{20,}'
  'https?://[^[:space:]]+:[^[:space:]@]+@'
)

for pattern in "${patterns[@]}"; do
  if rg --hidden --line-number --color never \
    --glob '!scripts/qa/anonymization-check.sh' \
    --glob '!scripts/qa/check-anonymization.sh' \
    -e "$pattern" "${scan_paths[@]}"; then
    printf 'Potential secret matched pattern: %s\n' "$pattern" >&2
    status=1
  fi
done

if rg --hidden --line-number --color never \
  --glob '!docs/evidence/runs/template/**' \
  -e '([0-9]{1,3}\.){3}[0-9]{1,3}' \
  docs/evidence 2>/dev/null; then
  printf 'Potential IPv4 address found in evidence docs; redact or justify before publishing.\n' >&2
  status=1
fi

if [[ "$status" -ne 0 ]]; then
  echo "anonymization check failed" >&2
  exit "$status"
fi

echo "anonymization check passed"
