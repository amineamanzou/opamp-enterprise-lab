# Elastic Dashboard And Metrics Evidence

Access date: 2026-06-19 UTC.

Source: authenticated Kibana session via `browser-use --headed --profile Default`, plus Elasticsearch aggregate API queries. Raw browser state and raw screenshots were not committed because Kibana chrome can expose account, project, URL, or user details.

## Sanitized Screenshots

- `screenshots/sanitized/kibana-opamp-overview.png`: embedded dashboard view showing connected OpAMP agents, lifecycle events, config status changes, synthetic app log rate, refused collector records, and inventory by collector version.
- `screenshots/sanitized/kibana-opamp-agent-lifecycle.png`: embedded lifecycle dashboard showing agent config, health, connection, disconnection, and inventory-by-ring evidence.
- `screenshots/sanitized/kibana-opamp-volumetry-capacity.png`: embedded volumetry/capacity dashboard showing OpAMP server metrics, host/Kubernetes metrics, and collector refused-record trend.
- `screenshots/sanitized/kibana-fleet-agents-table.png`: cropped Fleet agents table showing three stale `otelcol-contrib` rows offline after the Fleet exit.

## API Summaries

- `artifacts/api/elastic-final-24h-counts.json`: 24-hour aggregate counts by dataset and service.
- `artifacts/api/elastic-final-indices.json`: sanitized log and metric index inventory with document counts.
- `artifacts/api/elastic-opamp-fleet-summary.json`: focused OpAMP/Fleet counters and lifecycle action counts.

Key values from the focused summary:

- `app.synthetic.otel`: 433515 documents in the 24-hour window.
- `opamp.inventory`: 40052 documents in the 24-hour window.
- `opamp.events`: 106 documents in the 24-hour window.
- `opamp.connections`: 7 documents in the 24-hour window.
- `fleet_server.agent_status`: 196 documents in the 24-hour window.
- Lifecycle actions included `agent.config_offered`, `agent.connected`, `agent.health_changed`, `agent.config_status_changed`, and `agent.disconnected`.

## Interpretation

Elastic still held historical evidence after the lab teardown. The dashboards and API summaries confirm that the data path exported synthetic app logs, host/Kubernetes metrics, OpAMP inventory, and OpAMP lifecycle events before the infrastructure was destroyed.

The Fleet agents page still showed three offline `otelcol-contrib` rows, matching the exit-drill finding that Fleet retains stale control-plane inventory after the collector is moved away.
