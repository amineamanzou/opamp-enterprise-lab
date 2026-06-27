# Collector Scenarios

All scenarios use OpenTelemetry Collector binaries only.

| Scenario | Expected evidence | Result |
| --- | --- | --- |
| First connection | Collector appears in Fleet without Elastic Agent enrollment. | pass: `fleet-opamp-listening-after-start.state.txt` shows "1 collector has been connected"; `fleet-agents-after-connect.state.txt` shows one healthy `otelcol-contrib` row. |
| Log ingest | Synthetic logs continue to arrive in Elastic through OTLP/HTTP. | pass: `elastic-service-query.json` shows `logs-generic.otel-*` documents with `resource.attributes.fleet.scenario.name=elastic-fleet-otel-only`. |
| Bad config | Fleet exposes a useful component or config error. | partial: local `otelcol-contrib validate` catches invalid YAML, but Fleet does not own config rollout. Bad config is primarily a deployment-tooling concern for OTel-only collectors. |
| Recovery | Collector returns healthy after restoring config. | pass: service returns active after restore; `fleet-agents-after-bad-config-recovery.state.txt` shows the stable collector healthy. |
| Restart | Fleet status transitions and returns healthy. | partial/pass: restart works after adding stable `instance_uid`; without it Fleet created duplicate stale rows. |
| Disconnect | Fleet reports stale/offline state after OpAMP connectivity loss. | pass: after stopping the service for 75 seconds, `fleet-agents-after-disconnect.state.txt` shows the stable collector `Hors ligne`; after start, `fleet-agents-after-reconnect.state.txt` shows it `Sain`. |
| Scale step | UI/API remains usable at the selected collector count. | blocked at 10: first attempt lacked a pipeline, second hit default telemetry port `8888`, third ran but each extra collector received OpAMP `401`; the Add Collector credential appears scoped to the generated collector/config rather than reusable for arbitrary many collectors. |
