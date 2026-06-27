#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$root/scripts/qa/check-anonymization.sh"
"$root/scripts/qa/check-markdown.sh"
"$root/scripts/qa/source-check.sh"
"$root/scripts/qa/check-sources.sh"
"$root/scripts/qa/check-elastic-visibility.sh"

echo "study checks passed"
