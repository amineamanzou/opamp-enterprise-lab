# OpAMP / Fleet Management Logs POC Study

This study describes a public, anonymized proof of concept for managing a large logs-only observability fleet. The reference organization is fictitious: an on-premises enterprise with about 100,000 managed assets across data centers, branch sites, and segmented network zones.

The goal is to compare management and ingestion approaches without naming real customers, environments, vendors as customers, internal systems, hostnames, tokens, commercial terms, or private operational details.

## Scope

V1 is logs-only. Metrics, traces, profiling, endpoint protection, and application instrumentation are out of scope except where a product requires a control-plane component that can also manage those signals.

The common backend for lab comparability is an Elastic Cloud trial deployment. This does not make Elastic the required production backend. It is a convenient shared destination for search, dashboards, ingest confirmation, and operational comparison.

Benchmark scenarios:

| Scenario | Role in the study | Why it is included |
| --- | --- | --- |
| Custom OpAMP server and OpAMP-capable agent | Reference control plane | Tests protocol-level feasibility, inventory, remote config, status, and update concepts with vendor-neutral primitives. |
| OCB minimal collector | Minimal custom distribution | Establishes the smallest practical OpenTelemetry Collector binary for logs forwarding and controlled component selection. |
| EDOT Collector | Vendor-supported OTel distribution | Tests a vendor distribution that remains OpenTelemetry Collector based. |
| Elastic Agent with Fleet | Managed benchmark | Provides a mature central-management benchmark with enrollment, policies, status, and upgrade workflows. |
| Upstream `otelcol-contrib` | Broad upstream baseline | Provides a component-rich open-source baseline with minimal packaging assumptions. |
| OpenLit Fleet Hub | Open-source/product OpAMP benchmark | Tests an OpAMP-facing OpenTelemetry collector-management surface, including self-hosting and TLS/mTLS claims. |

## Study Documents

- `evidence-matrix.md`: public source evidence, claim labels, and lab evidence still required.
- `blueprints.md`: standalone OpAMP and enterprise-scale 100k-asset architecture blueprints.
- `lab-methodology.md`: lab topology, test phases, evidence capture, and comparison rules.
- `fleet-management-comparison.md`: Elastic Fleet OTel-only, Bindplane, custom OpAMP Go, and opamp-server-py comparison, including pricing and maintainer burden.
- `vanilla-opamp-lab-notes.md`: direct-lab friction and fixes for the custom Go vanilla OpAMP server.
- `../runbooks/opamp-ops-experience.md`: day-2 operations runbook for config, restart, version redeploy, and pre-sweep volumetry.
- `../runbooks/opamp-agent-scale.md`: mock-agent scale runbook for concurrent OpAMP connection/inventory limits.
- `../runbooks/bindplane-otel.md`: Bindplane OTel-only runbook for UI/API evidence, lifecycle tests, pricing limits, and switching friction.
- `../runbooks/openlit-opamp.md`: OpenLit Fleet Hub runbook for OpAMP collector evidence, Controller boundary notes, TLS/mTLS, pricing limits, and switching friction.
- `../runbooks/regulated-observability.md`: regulated infra/SIEM logs, host metrics, collector self-observability, and Elastic visualization workflow.
- `../articles/opamp-fleet-logs-poc-draft.md`: first public article outline and draft.

## Public Source Index

Official or project-owned sources used by this study:

- OpenTelemetry OpAMP specification: https://opentelemetry.io/docs/specs/opamp/
- OpenTelemetry Collector Builder: https://opentelemetry.io/docs/collector/extend/ocb/
- OpenTelemetry Collector agent deployment pattern: https://opentelemetry.io/docs/collector/deploy/agent/
- OpenTelemetry Collector gateway deployment pattern: https://opentelemetry.io/docs/collector/deploy/gateway/
- OpenTelemetry Collector Contrib repository: https://github.com/open-telemetry/opentelemetry-collector-contrib
- OpenTelemetry OpAMP Go implementation: https://github.com/open-telemetry/opamp-go
- Elastic Cloud trial overview: https://www.elastic.co/cloud/cloud-trial-overview
- Elastic Fleet and Elastic Agent overview: https://www.elastic.co/docs/reference/fleet
- Elastic Fleet Server: https://www.elastic.co/docs/reference/fleet/fleet-server
- Elastic Agent installation: https://www.elastic.co/docs/reference/fleet/install-elastic-agents
- Elastic Distribution of OpenTelemetry Collector: https://www.elastic.co/docs/reference/edot-collector
- Elastic pricing: https://www.elastic.co/pricing
- Bindplane pricing: https://bindplane.com/pricing
- Bindplane documentation: https://docs.bindplane.com/
- OpenLit documentation: https://docs.openlit.io/latest/overview
- OpenLit Fleet Hub documentation: https://docs.openlit.io/latest/openlit/observability/fleet-hub
- OpenLit repository OpAMP deployment guide: https://github.com/openlit/openlit/blob/main/OPAMP_DEPLOYMENT.md
- OpenLit pricing: https://openlit.io/pricing

## Evidence Labels

Use these labels consistently:

- `source-only`: supported by public documentation or source code, but not yet reproduced in this lab.
- `lab-proven`: reproduced in this lab with retained evidence such as configs, command output, screenshots, ingest records, metrics, or logs.
- `not-tested`: deliberately outside the current lab phase.
- `blocked`: intended for the lab, but blocked by access, licensing, scale limits, missing features, or reproducibility gaps.

No claim should be promoted from `source-only` to `lab-proven` unless the evidence can be replayed or inspected by another engineer from the public POC materials.
