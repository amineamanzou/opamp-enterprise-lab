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
