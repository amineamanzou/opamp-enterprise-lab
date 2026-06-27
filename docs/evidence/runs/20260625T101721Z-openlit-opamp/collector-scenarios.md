# Collector Functional Scenarios

All scenarios use OpenTelemetry collector binaries only. If OpenLit requires a specific distribution or Controller path, record why upstream `otelcol-contrib` was not enough.

| Scenario | Expected evidence | Result |
| --- | --- | --- |
| First connection | Collector appears in OpenLit Fleet Hub without Elastic Agent. | pending |
| Log ingest | Synthetic logs arrive in Elastic through OTLP/HTTP. | pending |
| Remote config | OpenLit changes collector behavior and exposes desired/effective state. | pending |
| Bad config | OpenLit blocks, reports, or safely recovers from invalid config. | pending |
| Recovery | Collector returns healthy after restoring config. | pending |
| Restart | Status transitions are visible and stable. | pending |
| Disconnect | Offline/stale behavior is visible and understandable. | pending |
| TLS/mTLS | TLS or mTLS setup works, or the limitation is documented. | pending |
| Controller boundary | Controller capabilities are documented separately from Fleet Hub. | pending |
