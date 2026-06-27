#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$("$root/scripts/evidence-run.sh" exit-drill-secrets-outage)"

mkdir -p "$run_dir/artifacts/api" "$run_dir/artifacts/browser-use" "$run_dir/config" "$run_dir/logs"

git -C "$root" rev-parse HEAD > "$run_dir/artifacts/git-head.txt"
git -C "$root" status --short --branch > "$run_dir/artifacts/git-status.txt"

cp "$root/docs/runbooks/exit-drill-secrets-outage.md" "$run_dir/runbook.md"

access_date="$(date -u +%Y-%m-%d)"

cat > "$run_dir/README.md" <<EOF
# Exit Drill, Secrets, And Control-Plane Outage Evidence

Access date: ${access_date}

This evidence package captures the final fleet-management drill. It is intentionally focused on exit friction, production secret handling, and control-plane outage behavior.

Constraints:

- Bindplane Enterprise and bring-your-own-collector paths are out of scope.
- No new scale paliers are run.
- Evidence must stay sanitized before commit.
EOF

cat > "$run_dir/run.md" <<'EOF'
# Exit Drill, Secrets, And Control-Plane Outage Run

## Summary

This run is a redacted operational drill package. The drill moves from previously captured Fleet OTel-only and Bindplane BDOT baselines toward the custom OpAMP Go path, then records secrets and outage risk.

## Final Conclusion

| Solution | Exit status | Migration effort | Secrets risk | Outage behavior | Scale operations risk |
| --- | --- | --- | --- | --- | --- |
| Fleet OTel-only | Partially immediate | Medium | High around Fleet auth and Elastic API key ownership | Data path should continue when only OpAMP is lost; verify per collector config | Medium to high because lifecycle remains external |
| Bindplane BDOT | Partial | Medium to high | High around Bindplane secret key, API key, and destination credentials | Control-plane-only conclusion until Elastic destination is finalized | High if BDOT and plan limits remain mandatory |
| Custom OpAMP Go | Immediate target | Low migration target, high product ownership | High unless token rotation and audit are productized | Expected to preserve data path during server outage | High operational ownership at fleet scale |

## Lab State

| Service | Final state | Notes |
| --- | --- | --- |
| Fleet OTel-only collector | documented-stop-or-active | Fill after live drill. |
| Bindplane BDOT collector | documented-stop-or-active | Fill after live drill. |
| OpAMP Go server | documented-active-or-stopped | Fill after live drill. |
| OpAMP supervisor collector | documented-active-or-stopped | Fill after live drill. |
| Elastic ingest | documented-verified-or-not-run | Fill after live drill. |

## Sanitization

Use placeholders only:

- `<redacted-token>`
- `<redacted-host>`
- `<redacted-tenant>`
- `<redacted-email>`
EOF

cat > "$run_dir/commands.md" <<'EOF'
# Commands

Fill this file during the live drill. Do not commit raw outputs containing addresses, tokens, tenant IDs, emails, or private hostnames.

## Fleet Exit

```sh
systemctl --user status <fleet-otel-service>
systemctl --user stop <fleet-otel-service>
systemctl --user start <opamp-supervisor-service>
```

## Bindplane Exit

```sh
systemctl status <bindplane-bdot-service>
systemctl stop <bindplane-bdot-service>
systemctl start <opamp-supervisor-service>
```

## OpAMP Go Outage

```sh
systemctl stop <opamp-go-service>
sleep 60
systemctl start <opamp-go-service>
```

## Elastic Continuity Check

```sh
curl -fsS "<elastic-query-endpoint>" \
  -H "Authorization: ApiKey <redacted-token>" \
  -H "Content-Type: application/json" \
  --data @config/elastic-continuity-query.redacted.json
```
EOF

cat > "$run_dir/exit-fleet-to-opamp.md" <<'EOF'
# Exit Fleet OTel-Only To OpAMP Go

| Measurement | Result | Evidence |
| --- | --- | --- |
| Baseline collector visible in Fleet | pending | artifacts/browser-use/fleet-baseline.state.txt |
| Baseline Elastic synthetic logs visible | pending | artifacts/api/fleet-baseline-elastic-query.redacted.json |
| Stop command | pending | commands.md |
| OpAMP supervisor deployed | pending | logs/opamp-supervisor-start.redacted.log |
| OpAMP inventory visible | pending | artifacts/api/opamp-inventory-after-fleet-exit.redacted.json |
| OpAMP events visible | pending | artifacts/api/opamp-events-after-fleet-exit.redacted.json |
| Elastic logs visible after exit | pending | artifacts/api/fleet-exit-elastic-query.redacted.json |
| Data-path downtime | pending | run.md |
| Stale Fleet row | pending | artifacts/browser-use/fleet-after-exit.state.txt |

## Expected Changes

| Area | Fleet OTel-only | OpAMP Go |
| --- | --- | --- |
| OpAMP endpoint | Fleet Server OpAMP endpoint | Custom OpAMP Go endpoint |
| Auth | Fleet generated header | `OPAMP_AUTH_TOKEN` |
| Collector service | External service owned by lab | Supervisor-managed OCB service |
| Remote config | Effective config visibility only in lab evidence | Lab remote config assignment |
| Elastic exporter | Same OTLP endpoint and API key when possible | Same OTLP endpoint and API key when possible |

## Interim Verdict

Exit is partially immediate. The collector binary and data path are portable, but lifecycle automation, identity mapping, stale Fleet cleanup, and dashboard/status ownership stay with the operator.
EOF

cat > "$run_dir/exit-bindplane-to-opamp.md" <<'EOF'
# Exit Bindplane BDOT To OpAMP Go

| Measurement | Result | Evidence |
| --- | --- | --- |
| Baseline collector visible in Bindplane | pending | artifacts/browser-use/bindplane-baseline.state.txt |
| Baseline Elastic synthetic logs visible | pending | artifacts/api/bindplane-baseline-elastic-query.redacted.json |
| Stop command | pending | commands.md |
| OCB supervisor deployed | pending | logs/opamp-supervisor-after-bdot-stop.redacted.log |
| OpAMP inventory visible | pending | artifacts/api/opamp-inventory-after-bindplane-exit.redacted.json |
| OpAMP events visible | pending | artifacts/api/opamp-events-after-bindplane-exit.redacted.json |
| Elastic logs visible after exit | pending | artifacts/api/bindplane-exit-elastic-query.redacted.json |
| Data-path downtime | pending | run.md |
| Stale Bindplane row | pending | artifacts/browser-use/bindplane-after-exit.state.txt |

## Expected Changes

| Area | Bindplane BDOT | OpAMP Go |
| --- | --- | --- |
| Collector binary | BDOT | Lab OCB distro |
| OpAMP endpoint | Bindplane WebSocket endpoint | Custom OpAMP Go endpoint |
| Auth | Bindplane secret key | `OPAMP_AUTH_TOKEN` |
| Config model | Bindplane source/destination graph | OTel YAML assigned by lab server |
| Rollout | Product workflow when configured | Lab-owned rollout and validation |

## Interim Verdict

Exit is partial. Replacing BDOT is mechanically straightforward, but product-specific source/destination modeling, secret handling, stale inventory, and any unfinished Elastic destination work create real migration effort.
EOF

cat > "$run_dir/secrets-catalog.md" <<'EOF'
# Secrets Catalog

| Secret | Creation | Storage | Distribution | Rotation | Revocation | Blast radius | UI/API visibility | Auditability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `OPAMP_AUTH_TOKEN` | Lab env or secret render path | Local secret env, optionally SOPS | Service env or rendered config | Replace token and restart/reload server plus agents | Remove old token from server allow-list or env | All custom OpAMP agents using token | Custom API/UI only if implemented | Low until explicit audit events exist |
| `ELASTIC_API_KEY` | Elastic Cloud UI/API | SOPS encrypted env and service env | Rendered collector config or env expansion | Create new key, update collectors, revoke old key | Delete/revoke key in Elastic | Elastic ingest for assigned privileges | Elastic UI/API | High in Elastic, lower in local deployment history |
| Fleet OpAMP auth header | Fleet add-collector flow | Collector config/service env | Generated config or automation | Generate replacement in Fleet flow if supported | Invalidate old enrollment/auth material if supported | Fleet OpAMP connection for affected collectors | Fleet UI/API | Product-dependent |
| Bindplane secret key | Bindplane install/onboarding flow | Service env or install script output | Generated BDOT command/config | Rotate from Bindplane UI/API if available | Revoke old key in Bindplane | Bindplane collector enrollment/config access | Bindplane UI/API | Product-dependent |
| Bindplane API key | Bindplane account/API key flow | Operator secret store | CLI/API automation env | Create replacement key and update automation | Delete old API key | Bindplane automation scope | Bindplane UI/API | Product-dependent |
| SOPS age identity | Operator workstation or CI secret | Local key file or CI secret | Decryption step only | Add new recipient, re-encrypt, retire old identity | Remove old recipient and key access | All encrypted env files for recipient | Git diff shows recipients, not private key use | Medium via Git history and CI logs |
| Kubernetes Secret objects | `kubectl`, Helm, or manifests | Kubernetes API/etcd | Mounted env or volume | Apply new Secret and restart/reload workloads | Delete old Secret and remove mounts | Namespace or cluster depending RBAC | Kubernetes API | Medium to high if audit logs enabled |

## Rotation Test

Only test `OPAMP_AUTH_TOKEN` rotation if the server and agents support overlapping tokens or a planned outage window. Do not destructively rotate Fleet or Bindplane secrets during this drill.
EOF

cat > "$run_dir/control-plane-outage.md" <<'EOF'
# Control-Plane Outage

| Control plane | Outage method | Data path expected | Evidence | Recovery metric |
| --- | --- | --- | --- | --- |
| OpAMP Go | Stop server process, keep collector and Elastic exporter running | Continue exporting synthetic logs | Elastic query before/during/after outage | Seconds until inventory and events refresh |
| Fleet OTel-only | Interrupt Fleet OpAMP path while preserving Elastic OTLP exporter | Continue exporting synthetic logs if exporter is independent | Fleet state plus Elastic query | Seconds until Fleet status returns |
| Bindplane BDOT | Interrupt Bindplane control-plane path if it does not break ingest | Control-plane-only unless Elastic destination is finalized | Bindplane state and collector logs | Seconds until connected status returns |

## Observations To Capture

- collector logs during reconnect loop;
- control-plane UI/API stale state;
- Elastic synthetic log continuity;
- remote config changes attempted during outage;
- behavior after restart;
- stale rows left by replaced collectors.
EOF

cat > "$run_dir/results.csv" <<'EOF'
scenario,status,time_to_exit_seconds,data_path_downtime_seconds,secrets_replaced,stale_old_control_plane,recovery_seconds,maintainer_friction,evidence_path,notes
fleet-to-opamp,pending,,,,,,,exit-fleet-to-opamp.md,
bindplane-to-opamp,pending,,,,,,,exit-bindplane-to-opamp.md,
opamp-token-rotation,document-only,,,,,,,secrets-catalog.md,
opamp-go-outage,pending,,,,,,,control-plane-outage.md,
fleet-opamp-outage,pending,,,,,,,control-plane-outage.md,
bindplane-opamp-outage,pending,,,,,,,control-plane-outage.md,
EOF

cat > "$run_dir/config/elastic-continuity-query.redacted.json" <<'EOF'
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } },
        { "match_phrase": { "service.name": "synthetic-log-source" } }
      ]
    }
  }
}
EOF

echo "$run_dir"
