# Browser UI Summary

Access date: 2026-06-19 UTC.

Raw browser state was not committed because it included account-specific project and user details.

## Bindplane

- Page: Agents.
- Rows visible: 1.
- Agent name: `opamp-poc-agent`.
- Status: `Disconnected`.
- Type: `BDOT 1.x (Stable)`.
- Version: `v1.101.2`.
- Operating system shown: Ubuntu 24.04.

Interpretation: after stopping `observiq-otel-collector.service`, Bindplane retained the old BDOT row and marked it disconnected.

## Elastic Fleet

- Page: Fleet Agents.
- Rows visible: 3.
- All visible rows were `otelcol-contrib`.
- Status: offline.
- Version: `0.151.0`.
- Last activity labels: two to three hours before capture.
- CPU and memory columns showed `N/A`.

Interpretation: Fleet retained stale OTel collector rows from the prior Fleet OTel-only run.
