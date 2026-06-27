# Fleet OTel-Only To OpAMP Switching Frictions

| Area | What to inspect | Friction level | Evidence |
| --- | --- | --- | --- |
| Collector binary | Confirm whether upstream `otelcol-contrib` is enough or EDOT is required. | low | Upstream `otelcol-contrib` 0.151.0 connected and appeared as `otelcol-contrib`; no EDOT required for the single-collector path. |
| OpAMP endpoint | Identify Fleet Server endpoint, auth header, TLS requirements, and config shape. | medium | Fleet generates `server.http`, not `server.ws`; the repo template had to be corrected from WS to HTTP. Auth is an API key generated in the flyout and must stay outside Git. |
| Remote config | Verify whether Fleet can push editable remote config to OTel collectors or only view generated/effective config. | high | Source docs and UI show OTel collectors use managed policies not displayed in Agent policies. UI exposes effective config but no editable policy path for OTel collectors. |
| Identity | Compare Fleet collector identity with OpAMP instance UID/resource attributes. | high | Missing stable `instance_uid` created duplicate Fleet rows on restart. Adding `FLEET_OPAMP_INSTANCE_UID` stabilized subsequent restarts, but stale rows remained. |
| Health | Compare component-level health, delays, and error text with custom OpAMP evidence. | low | Detail page shows collector status, last check-in message, capabilities, and component health for extensions/pipelines. |
| Data model | List Elastic-specific data streams, attributes, dashboards, and alerts introduced by the Fleet flow. | medium | Logs landed in `generic.otel`; Fleet flow adds Elastic-specific `elastic.collector.*` and uses managed OTLP/Fleet concepts. Existing dashboards/queries must account for `resource.attributes.*`. |
| Lifecycle | Confirm Fleet does not deploy, restart, upgrade, or uninstall OTel collectors without another tool. | high | Installation, systemd unit, restart, bad config validation, recovery, and cleanup were all external SSH/systemd operations. Fleet monitored state only. |
| Scale operations | Measure UI/API usability under collector count growth. | blocker for current credential flow | Ten extra collectors failed to enroll with `401` when reusing the generated OpAMP credential. Separate Add Collector credentials or an API workflow may be required per collector/group before scale testing. |

Verdict format:

- Replaceable by OpAMP: partial. For OTel-only collectors, Fleet is mostly an OpAMP visibility surface, so replacing it with another OpAMP server is technically plausible.
- Exit work required: replace Fleet HTTP OpAMP endpoint/auth, preserve stable instance UIDs, remove or replace Elastic-specific generated exporter/internal telemetry blocks, update dashboards/data views for field and dataset differences, and provide external deploy/restart/upgrade tooling.
- At-scale risk: Fleet Add Collector credentials did not scale by simple reuse; stale rows can accumulate after identity mistakes; lifecycle remains outside Fleet; remote config is not an editable policy workflow for OTel collectors.
