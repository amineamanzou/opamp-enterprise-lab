#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

mapfile -t markdown_files < <(find docs .github scripts -type f \( -name '*.md' -o -name '*.markdown' \) 2>/dev/null | sort)

if [[ ${#markdown_files[@]} -eq 0 ]]; then
  exit 0
fi

status=0

for file in "${markdown_files[@]}"; do
  if [[ ! -s "$file" ]]; then
    printf 'Empty Markdown file: %s\n' "$file" >&2
    status=1
  fi

  if LC_ALL=C grep -n '[[:blank:]]$' "$file"; then
    printf 'Trailing whitespace in Markdown file: %s\n' "$file" >&2
    status=1
  fi

  if [[ "$(tail -c 1 "$file")" != "" ]]; then
    printf 'Missing final newline in Markdown file: %s\n' "$file" >&2
    status=1
  fi
done

exit "$status"
