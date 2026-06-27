# Draft: Building a Public OpAMP and Fleet Management Logs POC

## Working Title

Managing 100,000 Log Collectors: A Vendor-Neutral POC Plan for OpAMP, OpenTelemetry, and Fleet

## Audience

Platform engineers, SREs, observability engineers, and architecture teams evaluating how to manage log collection across a large on-premises estate.

## Editorial Position

The article should be careful, public, and evidence-driven. It should not claim production readiness before the lab proves it. It should explain why fleet management is a control-plane problem, not just a collector binary choice.

## Outline

1. The fictional enterprise problem: 100,000 on-prem assets and logs-only V1.
2. Why logs-only first: narrower blast radius, easier evidence, faster backend validation.
3. The benchmark set: custom OpAMP, OCB minimal collector, EDOT Collector, Elastic Agent with Fleet, and upstream `otelcol-contrib`.
4. Why Elastic Cloud trial is the common backend for the lab.
5. What public sources say today.
6. What the lab will prove.
7. The two blueprints: standalone OpAMP POC and 100k enterprise architecture.
8. Evidence labels: `source-only` versus `lab-proven`.
9. Early hypotheses and risks.
10. How readers can reproduce or critique the study.

## Draft

Large observability rollouts often start with a deceptively simple question: "Which agent should we install?"

For a small estate, that question may be enough. For a large on-premises organization with around 100,000 assets, it is the wrong starting point. The harder question is: "How do we safely manage configuration, identity, health, rollout, failure, and evidence across the whole fleet?"

This proof of concept uses a fictitious enterprise profile to keep the work public and anonymized. There are no real customer names, private network details, production hostnames, or proprietary operational constraints in the study. The scenario is intentionally generic: a large organization with data centers, branch sites, segmented networks, mixed operating systems, and a first requirement to centralize logs.

V1 is logs-only. That constraint matters. Logs are still operationally meaningful, but they keep the first study smaller than a full observability rollout with metrics, traces, profiling, endpoint controls, and application instrumentation. The lab can focus on whether each candidate can be installed, configured, observed, changed, broken, and recovered in a repeatable way.

The common backend is an Elastic Cloud trial. That choice is pragmatic, not architectural. A managed trial gives the lab a shared place to validate ingest, query documents, and capture screenshots without building a backend first. It also lets Elastic Agent with Fleet be tested in a natural environment. The comparison should still keep backend convenience separate from agent-management conclusions.

The benchmark set has five paths:

- A custom OpAMP server and OpAMP-capable agent wrapper, used to test the protocol-level control-plane model.
- An OCB minimal collector, used to test how small and explicit an OpenTelemetry Collector distribution can be for logs.
- EDOT Collector, used to test an OpenTelemetry Collector distribution maintained by Elastic.
- Elastic Agent with Fleet, used as a mature central-management benchmark.
- Upstream `otelcol-contrib`, used as the broad open-source Collector baseline.

The distinction between these paths is important. OpAMP is a protocol for managing agents. Fleet is a product control plane for Elastic Agent. OCB is a way to build a custom Collector distribution. EDOT and `otelcol-contrib` are Collector distributions. These are related, but they are not interchangeable layers.

The first public artifact in the study is an evidence matrix. Every claim starts as `source-only` unless the lab has reproduced it and retained evidence. For example, OpenTelemetry documents OpAMP as a protocol for remote management of agent fleets. Elastic documents Fleet as a Kibana-based way to centrally manage Elastic Agents and their policies. Those statements are public-source evidence. They are not yet lab results.

Sources:

- https://opentelemetry.io/docs/specs/opamp/
- https://github.com/open-telemetry/opamp-go
- https://opentelemetry.io/docs/collector/extend/ocb/
- https://github.com/open-telemetry/opentelemetry-collector-contrib
- https://www.elastic.co/docs/reference/edot-collector
- https://www.elastic.co/docs/reference/fleet
- https://www.elastic.co/docs/reference/fleet/fleet-server
- https://www.elastic.co/cloud/cloud-trial-overview

The lab will promote claims to `lab-proven` only after repeatable evidence exists: pinned versions, sanitized configs, reproduction steps, command output or screenshots, ingest confirmation, and failure notes. This is deliberately stricter than a quick demo. The goal is to learn what breaks and what remains to be built.

The standalone OpAMP blueprint starts small. An OpAMP server assigns a logs-only desired configuration. An agent wrapper reports identity and health, applies configuration locally, and supervises a Collector process. The Collector tails synthetic logs and exports them to Elastic Cloud. The important evidence is not just that logs arrive. The important evidence is that the management loop works: desired config, effective config, status, failure, recovery, and audit trail.

The enterprise blueprint scales the idea conceptually to 100,000 assets. It uses cohorts instead of a flat host list: rollout ring, site, OS family, criticality, and connectivity model. It adds regional gateways, rate limits, reconnect-storm handling, audit history, policy validation, and observability for the control plane itself. None of that should be hand-waved. A protocol implementation is not an enterprise management platform by itself.

Elastic Agent with Fleet is included because it sets a useful benchmark for day-2 operations: enrollment, central policy management, agent health, version visibility, and upgrade workflows. The article should not present Fleet and OpAMP as equivalent. It should ask a practical question: if a mature product control plane behaves this way, what would a custom OpAMP route need to build, buy, or deliberately skip?

The early hypotheses are straightforward:

- For the fastest managed experience, Elastic Agent with Fleet should be hard to beat in an Elastic-backed lab.
- For minimum binary surface, OCB should be attractive, but it does not solve fleet management by itself.
- For upstream flexibility, `otelcol-contrib` should provide breadth at the cost of a larger default surface.
- For an OpenTelemetry-based Elastic path, EDOT should reduce some integration choices while still requiring an operations model.
- For vendor-neutral management, OpAMP is the right protocol to study, but the enterprise value depends on everything built around it.

Those are hypotheses, not conclusions.

The public study will be useful only if it is honest about labels. `source-only` means the source says it. `lab-proven` means the lab reproduced it. `not-tested` means it was outside scope. `blocked` means the lab intended to test it but could not. That vocabulary keeps the work readable and prevents a common POC failure mode: turning documentation, demos, and assumptions into conclusions.

The first version of this POC is intentionally modest: logs-only, synthetic data, public sources, an Elastic Cloud trial backend, and a benchmark set that mixes protocols, distributions, and product management planes. The ambition is not to crown a universal winner. It is to build a clean evidence base for a specific question:

What does it really take to manage log collection across a very large on-premises fleet?

## Public-Safe Notes

- Do not mention real customer names.
- Do not include screenshots with tenant identifiers, email addresses, deployment IDs, tokens, or private hostnames.
- Use synthetic assets such as `asset-000001.example.invalid`.
- Use "fictitious organization" or "reference enterprise" instead of implying a real deployment.
- Keep vendor language descriptive and sourced.

## Suggested Follow-Up Articles

1. First lab run: smoke-testing logs ingest across all candidates.
2. OpAMP management loop: desired config, effective config, and failure reporting.
3. Fleet benchmark: what a mature control plane gives operators out of the box.
4. Minimal collector versus broad collector: OCB and `otelcol-contrib` trade-offs.
5. What changes at 100,000 assets: cohorts, reconnect storms, and rollout safety.
