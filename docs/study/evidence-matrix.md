# State of the Art and Evidence Matrix

This matrix separates public-source claims from lab-proven findings. At initial publication, most entries are intentionally `source-only`. The lab must promote rows to `lab-proven` only after repeatable evidence has been captured.

## Control Plane and Fleet Management

| Area | Public evidence | Initial label | Lab evidence required |
| --- | --- | --- | --- |
| OpAMP is a vendor-agnostic protocol for remote management of data collection agents. | OpenTelemetry OpAMP spec and `opamp-go` repository describe agent status reporting, remote configuration, package update concepts, and mixed-agent fleet management. Sources: https://opentelemetry.io/docs/specs/opamp/ and https://github.com/open-telemetry/opamp-go | source-only | A running server and agent exchange identity, health/status, effective config status, and reconnect behavior under controlled failures. |
| OpAMP supports remote configuration as a protocol capability. | Source: https://opentelemetry.io/docs/specs/opamp/ | source-only | Push a logs pipeline config to a test agent, verify local application, verify telemetry arrives in Elastic Cloud, and retain before/after configs plus agent status. |
| OpAMP includes package availability and package status concepts, with security considerations for remotely delivered executable code. | Source: https://opentelemetry.io/docs/specs/opamp/ | source-only | Do not test executable package rollout in V1 unless code signing, provenance, rollback, and blast-radius controls are explicitly included. Capture as `not-tested` or `blocked` for the public article. |
| Fleet provides central management for Elastic Agents and policies through Kibana. | Elastic docs describe Fleet as a central UI for managing Elastic Agents, policies, health, versions, and policy upgrades. Source: https://www.elastic.co/docs/reference/fleet | source-only | Enroll Elastic Agents, assign a logs policy, capture status transitions, policy revision changes, and ingest confirmation. |
| Fleet Server connects Elastic Agents to Fleet and is supported in Elastic Cloud and self-managed clusters. | Source: https://www.elastic.co/docs/reference/fleet/fleet-server | source-only | Document the Fleet Server deployment mode used in the trial, endpoint reachability, enrollment token handling, and agent check-in timing. |
| Fleet can surface OpenTelemetry Collectors through OpAMP without using Elastic Agent. | Elastic Fleet docs describe monitoring, adding, and viewing OTel collectors through Fleet/OpAMP. Sources: https://www.elastic.co/docs/reference/fleet/monitor-otel-collectors, https://www.elastic.co/docs/reference/fleet/add-otel-collector, and https://www.elastic.co/docs/reference/fleet/view-otel-collectors | source-only | Run upstream `otelcol-contrib` with Fleet OpAMP settings, capture browser-use UI evidence, verify health/effective config/status visibility, and explicitly document whether remote config is editable or monitoring-only. |
| Bindplane provides an OpenTelemetry-focused telemetry pipeline and collector-management product surface. | Bindplane public pages describe telemetry pipeline management, OpenTelemetry positioning, and plan-based pricing. Sources: https://docs.bindplane.com/ and https://bindplane.com/pricing | source-only | Connect OTel collectors through the authenticated lab account, capture UI/API evidence, test config rollout, lifecycle operations, bad config handling, and scale onboarding. |
| OpenLit Fleet Hub provides an OpAMP-facing collector-management surface. | OpenLit public docs describe Fleet Hub for OpenTelemetry Collector fleet management through OpAMP, self-host installation paths, and a repository OpAMP deployment guide. Sources: https://docs.openlit.io/latest/openlit/observability/fleet-hub, https://docs.openlit.io/latest/openlit/installation, and https://github.com/openlit/openlit/blob/main/OPAMP_DEPLOYMENT.md | source-only | Run upstream `otelcol-contrib` or the required OpenLit collector path, capture browser-use UI evidence, verify inventory, remote config, health/status, TLS/mTLS behavior, failure modes, maintainability, browser asset/CSP behavior, and whether OpenLit Controller is required or separate. Do not run OpenLit volumetry paliers in this product pass. |

## Collector Distributions and Agents

| Candidate | Public evidence | Initial label | Lab evidence required |
| --- | --- | --- | --- |
| OCB minimal collector | OCB can build a custom Collector distribution with selected receivers, processors, exporters, and extensions. Source: https://opentelemetry.io/docs/collector/extend/ocb/ | source-only | Build a minimal logs-only collector with filelog or OTLP input, batch processing, and an Elastic-compatible exporter path; record binary size, component list, config, startup output, and ingest result. |
| Upstream `otelcol-contrib` | The contrib repository provides the OpenTelemetry Collector Contrib distribution and components. Source: https://github.com/open-telemetry/opentelemetry-collector-contrib | source-only | Run the same logs pipeline as OCB where possible; record component availability, binary size, memory baseline, config portability, and ingest result. |
| EDOT Collector | Elastic describes EDOT Collector as an open-source distribution of the OpenTelemetry Collector. Source: https://www.elastic.co/docs/reference/edot-collector | source-only | Run EDOT against the common Elastic Cloud destination; record setup path, supported config, default behavior, resource footprint, and ingest result. |
| Elastic Agent | Elastic docs describe Elastic Agent installation and management through standalone or Fleet mode. Sources: https://www.elastic.co/docs/reference/fleet and https://www.elastic.co/docs/reference/fleet/install-elastic-agents | source-only | Enroll agents with Fleet, apply a custom logs policy, observe status and policy rollout, and record operational steps and failure modes. |
| Upstream `otelcol-contrib` with Fleet OpAMP | Fleet's OTel collector flow is evaluated only with an OpenTelemetry Collector process in the `elastic-fleet-otel-only` scenario. Sources: https://www.elastic.co/docs/reference/fleet/add-otel-collector and https://github.com/open-telemetry/opentelemetry-collector-contrib | source-only | Prove a collector can appear in Fleet without Elastic Agent, keep OTLP ingest working, and record switching friction to the lab OpAMP server. |
| Bindplane-managed OTel collector | Bindplane documentation and pricing position the product around OpenTelemetry telemetry pipeline management. Sources: https://docs.bindplane.com/ and https://bindplane.com/pricing | source-only | Prefer upstream `otelcol-contrib`; if Bindplane requires its own distribution, document whether configs and pipeline semantics remain portable OpenTelemetry. |
| OpenLit-managed OTel collector | OpenLit documentation positions Fleet Hub around OpAMP-based OpenTelemetry Collector management. Sources: https://docs.openlit.io/latest/openlit/observability/fleet-hub and https://github.com/openlit/openlit/blob/main/OPAMP_DEPLOYMENT.md | source-only | Prefer upstream `otelcol-contrib`; if OpenLit requires a specific collector distribution or Controller path, document whether configs and pipeline semantics remain portable OpenTelemetry. Focus on function and maintainability, not OpAMP protocol volumetry. |
| Custom OpAMP-capable agent | `opamp-go` provides Go client and server implementation building blocks. Source: https://github.com/open-telemetry/opamp-go | source-only | Implement or wire a small agent wrapper that reports inventory and status and applies logs pipeline config. Keep the implementation demonstrably minimal and auditable. |

## Backend and Ingest

| Area | Public evidence | Initial label | Lab evidence required |
| --- | --- | --- | --- |
| Elastic Cloud trial can be used as a shared backend for the POC. | Elastic documents a free trial workflow and Elastic Cloud as a managed offering for search, observability, and security. Source: https://www.elastic.co/cloud/cloud-trial-overview | source-only | Create a trial deployment, store non-secret endpoint metadata, confirm ingest from each scenario, and capture index/data stream names and sample documents with anonymized host fields. |
| Logs-only ingest can be validated independently from agent-management maturity. | OpenTelemetry Collector deployment docs describe agent and gateway patterns. Sources: https://opentelemetry.io/docs/collector/deploy/agent/ and https://opentelemetry.io/docs/collector/deploy/gateway/ | source-only | Run equivalent log generation across scenarios and compare delivered document counts, latency windows, dropped records, retry behavior, and backpressure symptoms. |

## Evidence Promotion Rules

Promote a row to `lab-proven` only when the repository contains:

1. The exact public version or image tag tested.
2. Sanitized configuration with secrets removed.
3. Commands or scripted steps sufficient to reproduce the finding.
4. Evidence of agent control-plane state where applicable.
5. Evidence of log ingest in the common backend.
6. Failure-mode notes, not only the happy path.

Evidence must not include real customer names, internal IP ranges, usernames, cloud account identifiers, API keys, tokens, screenshots with private tenant metadata, or unredacted hostnames.

## Comparison Dimensions

Use these dimensions for the public comparison:

| Dimension | Custom OpAMP | OCB minimal collector | EDOT Collector | Elastic Agent + Fleet | Fleet + OTel Collector | Bindplane + OTel Collector | OpenLit Fleet Hub + OTel Collector | Upstream otelcol-contrib |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Central inventory | Target capability | Not native without added control plane | Depends on surrounding tooling | Native Fleet view | Lab-proven single collector; scale onboarding blocked by credential flow | Source-only; to test with UI/API evidence | Source-only; to test with Fleet Hub UI/API evidence | Not native without added control plane |
| Remote logs config | Target capability through OpAMP | File/config management required unless wrapped | File/config management unless vendor tooling adds more | Native policy model | Effective config visible; editable remote policy not found for OTel-only flow | Source-only; to test rollout and validation | Source-only; to test rollout, effective state, and TLS/mTLS effects | File/config management required unless wrapped |
| Remote binary/package update | High-risk future capability | External tooling | External or vendor packaging | Fleet upgrade workflow | Not proven for OTel-only collector deployment | Source-only; to test upgrade/downgrade ownership | Source-only; to test upgrade/downgrade ownership | External tooling |
| Minimal binary surface | Depends on implementation | Strong | Medium | Lower, because it is a broader agent | Strong with upstream `otelcol-contrib` in lab | To test; note any required Bindplane distribution | To test; note whether upstream `otelcol-contrib`, OpenLit distribution, or Controller is required | Lower than OCB, broader component set |
| Vendor neutrality | Strong protocol story | Strong upstream story | OTel-based with Elastic distribution choices | Elastic-specific management plane | OTel process with Elastic Fleet coupling | To test; expected product coupling through config model, credentials, and UI/API | To test; expected coupling around Fleet Hub model, TLS/mTLS, Controller boundary, credentials, UI/API, and browser asset packaging | Strong upstream story |
| Day-2 operations | Must be built | Must be built | Partially packaged, still needs ops model | Mature benchmark | UI visibility only for observed OTel path; lifecycle external | To test as the core Bindplane value proposition | To test as the core OpenLit Fleet Hub value proposition, including airgapped and Artifactory-friendly asset delivery for config editing | Must be built |

The table is a framing aid, not a verdict. Final labels require lab evidence.
