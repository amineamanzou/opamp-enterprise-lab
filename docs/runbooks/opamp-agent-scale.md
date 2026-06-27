# OpAMP Agent Scale Runbook

This runbook measures how many concurrent OpAMP agents the vanilla custom Go server can keep connected and visible in inventory on the current lab infra.

## Scope

- Target control plane: custom Go OpAMP server on `main`.
- Load source: VM host-agent running mock OpAMP clients.
- Agent type: lightweight mock agents using the real `opamp-go` WebSocket client.
- Out of scope: collector CPU, log ingestion throughput, Elastic backend throughput, and package update workflows.

## Fix Inventory First

Before scale runs, verify the UI and API show the supervised host-agent with complete metadata:

```sh
task opamp:build
task ansible:collector:supervisor
```

Expected:

- Host-agent has `version`, `hostname`, `health`, and `RemoteConfigStatuses_APPLIED`.
- Agents that do not report enough metadata are marked `limited`.
- Empty Current Effective Configuration renders as `not reported by agent yet`.

## Build And Run

```sh
task opamp:agent-swarm:build
task opamp:scale:agents
```

Default paliers:

```text
100 250 500 1000 2000 agents
```

Override defaults:

```sh
OPAMP_AGENT_SCALE_COUNTS="100 250 500 1000 2000 5000" \
OPAMP_AGENT_SCALE_DURATION=5m \
OPAMP_AGENT_SCALE_RAMP_PER_SECOND=50 \
OPAMP_AGENT_SCALE_HEARTBEAT=30s \
task opamp:scale:agents
```

The run writes a timestamped directory:

```text
tmp/opamp-agent-scale-<timestamp>/
```

Key file:

```text
opamp-agent-scale.csv
```

## Evidence

```sh
task evidence:agent-scale
```

Artifacts copied from the latest `tmp/opamp-agent-scale-*` directory:

- client JSON summaries per palier;
- server stats snapshots before/after each palier;
- CSV summary.

## Interpretation

Use this as a control-plane benchmark only. The mock clients are intentionally cheap and do not perform log collection or OTLP export.

Saturation indicators:

- `server_connected_agents` is materially below `target_agents`;
- `/v1/stats` or `/v1/inventory` becomes slow or unavailable;
- `server_runtime_sys_bytes` grows without stabilizing after clients stop;
- connect failures or OpAMP server errors increase with a palier.

## Redaction

Before publishing evidence, redact public IPs, tokens, Cloud IDs, kubeconfig content, and non-synthetic hostnames. Keep counts, relative timings, versions, hashes, and anonymized resource measurements.
