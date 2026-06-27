#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" regulated-observability)"
mkdir -p "$run_dir/artifacts" "$run_dir/config" "$run_dir/logs"

verify_out="$root/tmp/regulated-observability-elastic"
if [ -d "$verify_out" ]; then
  cp "$verify_out"/*.json "$run_dir/artifacts/" 2>/dev/null || true
fi

visibility_out="$root/tmp/elastic-visibility"
if [ -d "$visibility_out" ]; then
  mkdir -p "$run_dir/artifacts/elastic-visibility"
  cp "$visibility_out"/*.json "$run_dir/artifacts/elastic-visibility/" 2>/dev/null || true
fi

snapshot_out="$root/tmp/opamp-elastic-snapshot"
if [ -d "$snapshot_out" ]; then
  mkdir -p "$run_dir/artifacts/opamp-elastic-snapshot"
  cp "$snapshot_out"/*.json "$snapshot_out"/*.ndjson "$run_dir/artifacts/opamp-elastic-snapshot/" 2>/dev/null || true
fi

opamp_host="$(
  awk '$1 == "opamp-poc-opamp" {
    for (i = 1; i <= NF; i++) if ($i ~ /^ansible_host=/) {
      sub(/^ansible_host=/, "", $i)
      print $i
    }
  }' "$root/lab/ansible/inventory/hosts.ini" 2>/dev/null || true
)"
if [ -n "$opamp_host" ]; then
  ssh -o UserKnownHostsFile=/tmp/opamp_poc_known_hosts -o StrictHostKeyChecking=accept-new "root@$opamp_host" \
    "curl -fsS http://127.0.0.1:4321/v1/stats" \
    | jq . > "$run_dir/artifacts/opamp-stats.json" 2>/dev/null || true
fi

kubeconfig="${KUBECONFIG:-$root/secrets/kubeconfig-opamp-poc.yaml}"
if [ -f "$kubeconfig" ]; then
  KUBECONFIG="$kubeconfig" kubectl -n opamp-logs-poc get pods -o wide \
    > "$run_dir/artifacts/k8s-opamp-logs-pods.txt" 2>/dev/null || true
fi

cp "$root/lab/configs/kubernetes/otelcol-logs-opamp-daemonset.yaml" "$run_dir/config/kubernetes-otelcol-regulated.yaml"
cp "$root/lab/collector-ocb/otelcol-logs-opamp.yaml" "$run_dir/config/otelcol-logs-opamp-ocb.yaml"
cp "$root/lab/configs/opamp-regulated/noop-remote-config.yaml" "$run_dir/config/opamp-regulated-noop-remote-config.yaml"
cp "$root/lab/ansible/templates/k3s-audit-policy.yaml.j2" "$run_dir/config/k3s-audit-policy.yaml.j2"
cp "$root/lab/ansible/templates/k3s-audit-config.yaml.j2" "$run_dir/config/k3s-audit-config.yaml.j2"
cp "$root/lab/configs/elastic/regulated-observability-kibana.ndjson" "$run_dir/config/regulated-observability-kibana.ndjson"
cp "$root/lab/configs/elastic/regulated-observability-queries.json" "$run_dir/config/regulated-observability-queries.json"
cp "$root/lab/configs/elastic/opamp-visibility-es.json" "$run_dir/config/opamp-visibility-es.json"
cp "$root/lab/configs/elastic/opamp-visibility-kibana.ndjson" "$run_dir/config/opamp-visibility-kibana.ndjson"
cp "$root/lab/configs/elastic/opamp-visibility-queries.json" "$run_dir/config/opamp-visibility-queries.json"
cp "$root/lab/configs/elastic/opamp-visibility-security-rules.json" "$run_dir/config/opamp-visibility-security-rules.json"

cat > "$run_dir/run.md" <<EOF
# Regulated Observability Evidence

- Created at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Scenario: infra logs, security/SIEM logs, Kubernetes audit logs, host metrics, and collector self-observability to Elastic.
- Backend: Elastic Cloud OTLP ingest.
- Branch: $(git -C "$root" branch --show-current 2>/dev/null || echo unknown)
- Commit: $(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)

## Corrections during the run

- Reset stale OpAMP ring remote config with \`lab/configs/opamp-regulated/noop-remote-config.yaml\`; the previous operations scenario remote config referenced the older single \`logs\` pipeline and prevented the supervised collector from starting after the regulated multi-pipeline config was deployed.
- Ran the Kubernetes DaemonSet collector as UID/GID 0 with dropped capabilities because k3s audit logs are written as root-only files.
- Updated Elastic verification and Kibana query catalog for OTLP-indexed fields: Elastic stores datasets as \`*.otel\`, Kubernetes audit parsed fields under \`attributes.*\`, and service metadata under \`resource.attributes.*\`.
- Added Elastic as-code visibility artifacts for OpAMP inventory snapshots, server stats, connection snapshots, Kibana data views/dashboards/searches, and in-app Security detection rules.

## Expected datasets

- \`infra.host\`
- \`security.host\`
- \`observability.collector\`
- \`infra.kubernetes\`
- \`security.kubernetes_audit\`
- \`hostmetricsreceiver\`
- \`kubeletstatsreceiver\`
- \`k8sclusterreceiver\`
- \`metrics.collector\`
- \`opamp.inventory\`
- \`opamp.connections\`
- \`opamp.server\`

## Redaction

Audit logs may contain usernames, groups, namespaces, object names, source IPs, and user agents. Redact public IPs, private hostnames, tokens, Cloud IDs, kubeconfigs, and non-synthetic identities before publishing.
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

```sh
task ocb:build
task collector:env
./scripts/opamp-assign-config.sh dev lab/configs/opamp-regulated/noop-remote-config.yaml
task ansible:collector:supervisor
task ansible:k3s:audit
task k8s:logs:install
task elastic:regulated:verify
task elastic:visibility:check
task elastic:visibility:setup
task elastic:opamp:snapshot
task elastic:visibility:verify
task kibana:regulated:setup
task evidence:regulated-observability
```
EOF

git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt" 2>&1 || true
git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt" 2>&1 || true

echo "$run_dir"
