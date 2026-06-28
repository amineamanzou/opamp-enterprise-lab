#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

status=0

workflow=".github/workflows/ci.yml"
required_tasks=(
  'study:check'
  'opamp:test'
  'ocb:build'
  'infra:validate'
  'ansible:lint'
  'ci:local'
)

if [[ ! -f "$workflow" ]]; then
  printf 'Missing workflow: %s\n' "$workflow" >&2
  exit 1
fi

if rg --hidden --line-number --color never '\bmake\b' .github/workflows; then
  printf 'Workflows must call task, not make.\n' >&2
  status=1
fi

for task_name in "${required_tasks[@]}"; do
  if ! grep -Fq -- "$task_name" "$workflow"; then
    printf 'Workflow does not reference required task: %s\n' "$task_name" >&2
    status=1
  fi
done

if ! grep -Eq 'run:[[:space:]]*task|task "\$\{\{ matrix\.task_name \}\}"' "$workflow"; then
  printf 'Workflow must invoke task directly.\n' >&2
  status=1
fi

if ! grep -Fq 'actions/setup-go@v6' "$workflow"; then
  printf 'Workflow must use Node 24-compatible actions/setup-go@v6 before Go tasks.\n' >&2
  status=1
fi

if ! grep -Fq 'go.opentelemetry.io/collector/cmd/builder@v0.151.0' "$workflow"; then
  printf 'Workflow must install the OCB builder for real collector builds.\n' >&2
  status=1
fi

for script in scripts/qa/check-anonymization.sh scripts/qa/check-markdown.sh scripts/qa/check-sources.sh; do
  if [[ ! -x "$script" ]]; then
    printf 'QA script is not executable: %s\n' "$script" >&2
    status=1
  fi
done

exit "$status"
