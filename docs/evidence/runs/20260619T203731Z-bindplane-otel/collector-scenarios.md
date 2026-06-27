# Collector Functional Scenarios

All scenarios use OpenTelemetry collector binaries only. If BDOT is required, record why upstream `otelcol-contrib` was not enough.

| Scenario | Expected evidence | Result |
| --- | --- | --- |
| First connection | Collector appears in Bindplane without Elastic Agent. | pass: BDOT 1.101.2 connected and visible. |
| First connection with lab OCB distro | `otelcol-logs-opamp` appears in Bindplane using OpAMP extension. | blocked: service started, but Bindplane returned `403 Forbidden` during WebSocket handshake; UI still showed only BDOT. |
| Log ingest | Synthetic logs arrive in Elastic through OTLP/HTTP. | blocked: destination preset expects APM secret token, not current Elastic ApiKey model; Custom exporter path still to test. |
| Remote config | Bindplane changes collector behavior and exposes rollout state. | partial: draft config builder tested, File source saved, no rollout yet. |
| Bad config | Bindplane blocks, reports, or safely recovers from invalid config. | not-tested: do after a known-good config rollout exists. |
| Recovery | Collector returns healthy after restoring config. | not-tested for config; reconnect recovery passed after stop/start. |
| Restart | Status transitions are visible and stable. | pass: systemd restart returned active and UI remained Connected. |
| Disconnect | Offline/stale behavior is visible and understandable. | pass: after 25s stopped, UI showed Disconnected; after start, Connected. |
| Upgrade | Bindplane owns version change or documents external ownership. | not-tested. |
| Downgrade | Bindplane owns rollback or documents external ownership. | not-tested. |
