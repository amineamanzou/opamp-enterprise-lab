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
