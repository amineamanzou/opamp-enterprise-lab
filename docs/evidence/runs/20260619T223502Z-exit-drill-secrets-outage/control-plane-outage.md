# Control-Plane Outage

| Control plane | Outage method | Data path expected | Evidence | Recovery metric |
| --- | --- | --- | --- | --- |
| OpAMP Go | Stopped `opamp-poc-server.service`, kept `opampsupervisor-logs.service` running | Confirmed continued export | Elastic query during outage returned 1,898 host/supervisor logs and metrics in a two-minute window | Host-agent inventory timestamp refreshed about 25 seconds after restart |
| Fleet OTel-only | Not rerun because Fleet collector was already stopped | Prior design says exporter independence should preserve data path | Fleet UI showed three offline `otelcol-contrib` stale rows | Not measured in this run |
| Bindplane BDOT | Stopped BDOT as part of exit, not as a standalone outage | Control-plane-only because active BDOT config was `nop` | Bindplane UI showed the BDOT agent disconnected | Not measured; replacement was OpAMP Go supervisor |

## Observations To Capture

- collector logs during reconnect loop;
- control-plane UI/API stale state;
- Elastic synthetic log continuity;
- remote config changes attempted during outage;
- behavior after restart;
- stale rows left by replaced collectors.

## OpAMP Go Findings

The data path continued while the custom OpAMP Go server was stopped. The supervisor remained active, the local health endpoint stayed available, and Elastic continued receiving host logs, host metrics, collector logs, and collector metrics.

The supervisor logged repeated connection failures to the OpAMP endpoint during the outage. After restart at 2026-06-19T22:40:04Z, the host-agent inventory timestamp refreshed at 2026-06-19T22:40:29Z.

Control-plane caveat: `/v1/opamp/connections` and `/v1/stats.connected_agents` reported zero active connections even while inventory was refreshing. Treat this as an observability gap in the custom server before production use.
