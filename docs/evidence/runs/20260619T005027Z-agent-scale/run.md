# OpAMP Agent Scale Evidence Run

- Created at: 2026-06-19T00:50:27Z
- Scenario: vanilla custom Go OpAMP server with mock OpAMP agent swarm
- Evidence label: custom-go-opamp-agent-scale
- Branch: main
- Commit: da36e48c22bf50c2170fa07012f5b6d345ba0707

## Purpose

Measure how many concurrent OpAMP agents the vanilla server can inventory and keep connected on the current lab infra.

## Notes

- Mock agents use real OpAMP WebSocket clients and report description, health, heartbeat, remote config status, and effective config.
- This measures control-plane connection/inventory pressure, not collector CPU, log ingestion, or Elastic throughput.
- Redact public IPs, tokens, Cloud IDs, kubeconfig content, and non-synthetic hostnames before publishing.
