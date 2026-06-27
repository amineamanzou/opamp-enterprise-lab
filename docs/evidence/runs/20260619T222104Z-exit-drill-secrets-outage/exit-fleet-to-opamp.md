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
