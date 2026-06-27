# Lab Design and Evidence Methodology

This document defines how the POC should generate defensible public evidence while staying anonymized and vendor-neutral.

## Lab Principles

1. Use synthetic logs only.
2. Compare management behavior separately from log throughput.
3. Keep Elastic Cloud as the common backend for V1, not as an architectural mandate.
4. Prefer official distributions, official docs, and pinned versions.
5. Record failure modes with the same care as successful runs.
6. Preserve evidence in public-safe form.

## Candidate Matrix

| Candidate | Management model tested | Logs pipeline tested | Backend |
| --- | --- | --- | --- |
| Custom OpAMP + local collector | OpAMP server assigns desired config and receives status. | Local collector tails synthetic logs. | Elastic Cloud trial |
| OCB minimal collector | No native control plane unless wrapped by OpAMP agent. | Minimal logs-only collector binary. | Elastic Cloud trial |
| EDOT Collector | Distribution behavior and Elastic-oriented setup path. | Logs-only collector pipeline. | Elastic Cloud trial |
| Elastic Agent + Fleet | Fleet enrollment, policy assignment, health, and rollout. | Logs integration or custom logs input. | Elastic Cloud trial |
| Fleet + OpenTelemetry Collector | Fleet OpAMP flow and OTel collector visibility only; no Elastic Agent enrollment. | Upstream `otelcol-contrib` logs pipeline. | Elastic Cloud trial |
| Upstream `otelcol-contrib` | No native control plane unless wrapped by OpAMP agent. | Broad upstream collector baseline. | Elastic Cloud trial |
| OpenLit Fleet Hub | OpenLit OpAMP collector-management surface; Controller treated separately. | Upstream `otelcol-contrib` preferred unless OpenLit-specific distribution is required. | Elastic Cloud trial |

## Lab Topology

Minimum local topology:

- One Elastic Cloud trial deployment.
- One test network or local container network.
- One synthetic log generator.
- One evidence collector script or manual checklist.
- One instance of each candidate per smoke test.

Scale-emulation topology:

- N lightweight OpAMP client simulators for inventory and state convergence.
- M heavier log generators for ingest and backpressure testing.
- Optional gateway collector tier to test agent-to-gateway patterns.
- Optional proxy to simulate restricted egress.

## Test Phases

### Phase 0: Source Baseline

Objective: document what official sources claim before running the lab.

Evidence:

- Source URL.
- Access date.
- Version or page date when available.
- Claim summary in neutral language.
- Initial label: `source-only`.

### Phase 1: Smoke Test

Objective: prove that each candidate can send at least one synthetic log stream to the shared backend.

Evidence:

- Candidate version.
- Sanitized config.
- Startup command or enrollment steps.
- Screenshot or query output showing received documents.
- Count of generated and received logs.
- Label candidate ingest path as `lab-proven` only after repeat.

### Phase 2: Management Behavior

Objective: compare how operators manage configuration and observe health.

Tests:

- Initial enrollment or registration.
- Assign logs config.
- Change logs path or attribute.
- Detect bad config.
- Recover good config.
- Restart candidate and observe state.

Evidence:

- Number of operator steps.
- API/UI/config files touched.
- Time to visible desired state.
- Time to reported effective state.
- Error messages and status transitions.
- Source-code or configuration corrections required to make the control-plane surface usable.
- Whether missing fields were product limitations, configuration gaps, protocol behavior, or local implementation bugs.
- Impact of each correction on the final setup and maintenance experience score.

### Phase 3: Failure Modes

Objective: understand operational resilience.

Tests:

- Backend unavailable.
- Invalid output credentials.
- Invalid logs path.
- Collector process crash.
- OpAMP server unavailable.
- Fleet Server or Fleet unavailable for Elastic Agent scenario.
- Fleet Server or Fleet OpAMP endpoint unavailable for OTel-only scenario.
- Network partition and reconnect storm simulation.

Evidence:

- Local error logs.
- Control-plane status.
- Retry behavior.
- Data loss or buffering notes.
- Manual recovery steps.

### Phase 4: Scale Simulation

Objective: evaluate management-plane shape for a 100k-asset estate without pretending a laptop test is a production load test.

Tests:

- 1,000 simulated agents.
- 10,000 simulated agents if local resources allow.
- 100,000 logical-agent extrapolation only if backed by measured per-agent costs and clearly labeled as modeled, not proven.

Metrics:

- Active connections.
- Heartbeats per second.
- Server CPU and memory.
- Config assignment throughput.
- Config convergence latency percentiles.
- Reconnect storm recovery time.
- State database size per agent.

Evidence label guidance:

- `lab-proven`: measured in the lab at the stated scale.
- `modeled`: optional sub-label in notes for extrapolations; do not use as a replacement for `source-only` or `lab-proven`.

## Synthetic Log Corpus

Use a small, realistic corpus without private data:

| Field | Example |
| --- | --- |
| `service.name` | `synthetic-payment-api` |
| `host.name` | `asset-000001.example.invalid` |
| `site.name` | `site-a` |
| `environment` | `poc` |
| `scenario.name` | `opamp-ocb-minimal` |
| `log.level` | `INFO`, `WARN`, `ERROR` |
| `message` | `synthetic checkout event completed` |

Avoid real organization names, user IDs, emails, source IPs, and domain names. Use `.example`, `.example.invalid`, or clearly synthetic values.

## Measurement Rules

- Pin candidate versions before each run.
- Reset or isolate backend data streams between scenarios.
- Use the same log corpus and generation rate when comparing ingest.
- Run each smoke test at least twice before marking `lab-proven`.
- Keep wall-clock timestamps in UTC.
- Record environment limits such as CPU, memory, disk, container runtime, and network constraints.
- Separate "could not configure" from "configured but failed at runtime".

## Evidence Artifact Checklist

For each scenario, retain:

- `versions.md`: versions, image tags, binary hashes where available.
- `config.redacted.yaml`: sanitized config.
- `runbook.md`: reproduction steps.
- `results.md`: observed behavior and measurements.
- `screenshots/`: sanitized screenshots if useful.
- `logs/`: redacted control-plane and candidate logs.

Store secrets outside the repository. Redact:

- API keys and tokens.
- Elastic Cloud IDs and deployment IDs if they identify a private tenant.
- Enrollment tokens.
- Personal names and email addresses.
- Hostnames that are not synthetic.
- Public IPs unless intentionally assigned to the lab and safe to publish.

## Public Comparison Output

The final public study should present:

- What was tested.
- What was not tested.
- Which claims are source-only.
- Which claims are lab-proven.
- What broke.
- What an enterprise would still need to build.

Avoid ranking vendors globally. Rank only the tested paths against the V1 logs-only requirements.
