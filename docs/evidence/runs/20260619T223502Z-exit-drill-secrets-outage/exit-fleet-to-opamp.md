# Exit Fleet OTel-Only To OpAMP Go

| Measurement | Result | Evidence |
| --- | --- | --- |
| Baseline collector visible in Fleet | prior evidence | `20260619T193626Z-elastic-fleet-otel-only` proved upstream `otelcol-contrib` visibility in Fleet. |
| Baseline Elastic synthetic logs visible | prior evidence | Prior Fleet evidence confirmed Elastic ingest for `elastic-fleet-otel-only`. |
| Stop command | already stopped before this run | `otelcol-fleet-opamp.service` was inactive at baseline. |
| OpAMP supervisor deployed | done for Bindplane exit path | Same host ended with `opampsupervisor-logs.service` active. |
| OpAMP inventory visible | done | Host-agent visible in OpAMP Go inventory after supervisor start. |
| OpAMP events visible | partial | Inventory refreshed; active connection accounting remained zero. |
| Elastic logs visible after exit | done | Replacement collector exported host and collector telemetry to Elastic. |
| Data-path downtime | not rerun | Fleet collector was already stopped, so this run could not measure Fleet-to-OpAMP downtime. |
| Stale Fleet row | observed | Fleet Agents page showed three `otelcol-contrib` rows as offline, last activity two to three hours earlier. |

## Expected Changes

| Area | Fleet OTel-only | OpAMP Go |
| --- | --- | --- |
| OpAMP endpoint | Fleet Server OpAMP endpoint | Custom OpAMP Go endpoint |
| Auth | Fleet generated header | `OPAMP_AUTH_TOKEN` |
| Collector service | External service owned by lab | Supervisor-managed OCB service |
| Remote config | Effective config visibility only in lab evidence | Lab remote config assignment |
| Elastic exporter | Same OTLP endpoint and API key when possible | Same OTLP endpoint and API key when possible |

## Interim Verdict

Exit remains partially immediate. The previous Fleet run already proved the upstream collector path; this run confirms stale Fleet rows remain visible after the old collector is no longer active. Because the Fleet collector was already stopped, this run records stale state but does not produce a fresh downtime measurement.
