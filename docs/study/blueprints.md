# Architecture Blueprints

These blueprints are public and anonymized. They model a fictitious on-premises organization with about 100,000 assets. The design assumes segmented networks, mixed operating systems, strict egress control, and operational teams that need central visibility into log collection health.

## Blueprint A: Standalone OpAMP Logs POC

Purpose: prove the smallest useful OpAMP management loop before debating enterprise scale.

### Components

| Component | Responsibility |
| --- | --- |
| OpAMP server | Agent enrollment, identity registry, desired config assignment, effective config status, heartbeat/status tracking, and audit log. |
| Agent wrapper | Connects to OpAMP, reports identity and health, applies desired logs configuration, and supervises the local collector process. |
| Local collector | Reads local test logs and exports them to Elastic Cloud. Candidate binaries: OCB minimal collector, EDOT Collector, or `otelcol-contrib`. |
| Elastic Cloud trial | Common backend for ingest validation, search, and dashboard screenshots. |
| Evidence store | Sanitized configs, run logs, screenshots, generated log corpus metadata, and result tables committed under public-safe paths. |

### Data Flow

1. Agent wrapper starts with a bootstrap endpoint and non-secret environment metadata.
2. Agent connects to the OpAMP server and reports identity, version, capabilities, and health.
3. Server assigns a logs-only desired configuration.
4. Agent writes collector config locally, restarts or reloads the collector, and reports effective config status.
5. Collector tails synthetic logs and exports to Elastic Cloud.
6. Lab runner compares generated records with received records and records timing, drops, retries, and errors.

### Minimum Logs Pipeline

The initial pipeline should stay deliberately small:

- Receiver: local file logs or OTLP logs from a generator.
- Processor: batch.
- Exporter: Elastic-compatible OTLP endpoint or another documented Elastic ingest path selected for the candidate.
- Resource attributes: synthetic organization, site, environment, host role, and scenario name.

### Security Boundaries

- No production data.
- No real hostnames, user IDs, tenant names, private IP ranges, or screenshots containing secrets.
- Tokens are injected at runtime and never committed.
- Remote executable updates are not included in V1 unless code signing and rollback evidence are part of the test.
- Desired configuration changes are logged with author, timestamp, target cohort, previous hash, and new hash.

### Success Criteria

The standalone POC is successful when the lab can show:

- Agent appears in inventory with stable anonymized identity.
- Server assigns a config and the agent reports applied or failed status.
- Collector sends synthetic logs to Elastic Cloud.
- A config change changes ingest behavior in a measurable way.
- Failure of the backend, OpAMP server, or collector produces understandable status.

## Blueprint B: Enterprise 100k-Asset Reference Architecture

Purpose: describe how the standalone pattern could be scaled for a fictitious large on-prem estate without claiming production readiness before lab evidence exists.

### Logical Topology

| Layer | Responsibility |
| --- | --- |
| Global control plane | Desired state API, policy authoring, cohort assignment, RBAC, audit trail, package metadata, and reporting API. |
| Regional OpAMP gateways | Terminate agent connections near assets, buffer state updates, enforce local rate limits, and reduce cross-region dependency. |
| Site relays or proxies | Provide egress control for network zones with limited outbound access. |
| Agent cohort | 100k assets grouped by OS, site, criticality, business service, and rollout ring. |
| Telemetry backend | Elastic Cloud trial in lab; production architecture could use Elastic, another OTLP-compatible backend, or a gateway layer. |
| Evidence and observability plane | Dashboards and logs for the control plane itself: connection count, config convergence, queue depth, failed rollouts, and ingest lag. |

### Cohort Model

Use cohorts to avoid managing 100,000 assets as a flat list:

| Cohort type | Example values | Operational use |
| --- | --- | --- |
| Rollout ring | canary, pilot, broad, holdback | Gradual policy rollout and rollback. |
| Site class | data center, branch, lab | Network routing and collector config differences. |
| OS family | Linux, Windows | File paths, service manager, packaging, and permissions. |
| Criticality | low, standard, high | Change windows and retry policy. |
| Connectivity | direct, proxy, disconnected | OpAMP transport and artifact strategy. |

### Scale Targets for Lab Simulation

The public lab does not need 100,000 real hosts. It should simulate the dimensions that matter:

- Connection fan-out: emulate 1k, 10k, and 100k logical agents with lightweight clients.
- Config convergence: measure time from desired state publication to reported effective state.
- Backend ingest: separately test realistic logs-per-second with fewer heavier generators.
- Failure domains: isolate OpAMP server restart, backend outage, bad config rollout, and network partition.
- Operator load: count steps, places to click, files to change, and APIs required per scenario.

### Enterprise Control-Plane Requirements

For a 100k-asset estate, a custom OpAMP path needs more than a protocol implementation:

- Enrollment with revocation and rotation.
- Stable asset identity independent from hostname reuse.
- Desired state versioning and immutable audit history.
- Ring-based rollout and automatic halt on error thresholds.
- Backpressure and rate limiting for reconnect storms.
- Multi-region availability and disaster recovery.
- Policy validation before rollout.
- Separate permissions for policy authors, rollout approvers, and break-glass operators.
- Observability for the management plane itself.

### Elastic Fleet Benchmark Blueprint

Fleet is included as a benchmark because it offers a mature central-management model for Elastic Agent:

- Kibana Fleet UI for policies and agent health.
- Fleet Server as the communication layer between Elastic Agents and Fleet.
- Agent policies for logs integrations and rollout.
- Remote policy and binary upgrade workflows.
- Elastic Cloud trial as a quick path to a managed test backend.

Sources:

- https://www.elastic.co/docs/reference/fleet
- https://www.elastic.co/docs/reference/fleet/fleet-server
- https://www.elastic.co/docs/reference/fleet/install-elastic-agents

The public comparison should avoid presenting Fleet as a direct equivalent to OpAMP. Fleet is a product control plane. OpAMP is a protocol that can be used to build or integrate a control plane.

## Decision Record Template

Each scenario should get a short decision record:

```text
Scenario:
Version or image:
Backend:
Management model:
Logs input:
Config rollout method:
Evidence label:
What worked:
What failed:
Operational notes:
Security notes:
Verdict for V1:
```
