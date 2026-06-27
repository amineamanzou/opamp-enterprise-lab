#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
matrix="$root/docs/study/evidence-matrix.md"

test -f "$matrix"

grep -q "source-only" "$matrix"
grep -q "lab-proven" "$matrix"
grep -q "https://opentelemetry.io/docs/specs/opamp/" "$matrix"
grep -q "https://opentelemetry.io/docs/collector/extend/ocb/" "$matrix"
grep -q "https://www.elastic.co/docs/reference/fleet" "$matrix"

echo "source check passed"
