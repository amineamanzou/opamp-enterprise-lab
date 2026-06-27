---
series: opamp-enterprise-adoption
part: 1
language: en
status: draft
evidence_review: complete
contradictory_review: complete
---

# Stop Asking "Which Collector?" First

Large observability programs often begin with a binary question: which collector should we install?

It is a reasonable question, but it is not the first one a large enterprise should ask. A collector binary can be good, small, well documented, and still leave the organization without a safe way to manage identity, rollout, failure, audit, secrets, and recovery across the estate. At 100k assets, the hardest part is rarely the first log line. It is the control plane around the log line.

That is the question behind this series: is OpAMP ready for large enterprises, or is it still a protocol for expert teams and vendors to productize?

The lab uses a fictitious reference enterprise: an on-premises organization with about 100,000 managed assets across data centers, branch sites, segmented network zones, mixed operating systems, and strict egress rules. That number is the architecture target, not a claim that 100,000 real hosts were tested. The lab deliberately keeps the public evidence smaller, reproducible, and anonymized.

The first version is logs-only. Metrics, traces, profiling, endpoint controls, and application instrumentation are outside the primary scope. That constraint is not a downgrade. It is what makes the evidence useful. Logs are operationally meaningful, but a logs-only slice keeps the test narrow enough to compare control-plane behavior without hiding everything behind a full observability platform rollout.

The architecture target is illustrated in `assets/diagrams/enterprise-100k-reference.png`. The diagram should be read as a reference model: cohorts, regional OpAMP gateways, site relays, collectors, and a telemetry backend. It is not a claim that the lab already operated that entire estate.

## The Real First Question

The better first question is: how will operators safely manage a collector fleet?

That question breaks down quickly:

- How does an agent identify itself in a stable way?
- How does the control plane know which config it should receive?
- How does an operator know the config was accepted, applied, or rejected?
- What happens when the collector process crashes?
- What happens when the control plane is unavailable?
- Can secrets be rotated without breaking the fleet?
- Are stale agents cleaned up, retained, or left for operators to interpret?
- Can another team reproduce the evidence without private data?

These questions change the comparison. OpenTelemetry Collector, OCB, EDOT Collector, Elastic Agent with Fleet, Bindplane, `opamp-go`, and `opamp-server-py` do not occupy the same layer. Some are collectors, some are distributions, some are product control planes, and OpAMP is a management protocol. Treating them as interchangeable "agents" is how POCs drift into unclear conclusions.

The lab therefore compares management behavior separately from log ingestion. A collector can send logs successfully while still being difficult to operate at scale. A product control plane can give a strong operator experience while introducing coupling that matters during exit. A protocol implementation can be portable while leaving large amounts of product work to the platform team.

## Evidence Before Verdicts

The study uses evidence labels to keep claims honest.

`source-only` means a public source or project document says something, but the lab has not reproduced it. `lab-proven` means the lab reproduced the behavior and retained evidence: versions, sanitized configuration, command output, screenshots, logs, dashboards, or result tables. `not-tested` means deliberately outside scope. `blocked` means the lab intended to test it but could not, because of access, licensing, scale limits, missing features, or reproducibility gaps.

This vocabulary matters. Public documentation is useful, but documentation is not the same as an operator holding a broken rollout at 2 a.m. A demo screenshot is useful, but a screenshot is not the same as a runbook another engineer can repeat. A vendor feature can be real and still not answer the specific enterprise question being tested.

The evidence matrix and methodology live under `docs/study/`. The raw run artifacts used later in the series live under `docs/evidence/runs/`. Screenshots are referenced as relative assets, for example `assets/screenshots/kibana-opamp-overview.png` and `assets/screenshots/kibana-fleet-agents-table.png`, with the expectation that visual material is sanitized before publication.

## The Lab Story

The lab started as a simple plan: create a public proof of concept for logs management using OpAMP and comparable managed paths. The common backend was an Elastic Cloud trial. That choice was pragmatic. It gave the study a shared place to validate ingest, query documents, and capture dashboards without first building a telemetry backend. It also allowed Elastic Fleet to be tested in a natural environment.

The candidate set was intentionally mixed:

- a custom OpAMP server and OpAMP-capable agent wrapper as the protocol-level path;
- an OCB minimal collector to test a small logs-only distribution;
- EDOT Collector as an OpenTelemetry Collector distribution maintained by Elastic;
- Elastic Fleet with an upstream OTel collector as a managed visibility benchmark;
- Bindplane with BDOT as a managed telemetry pipeline benchmark;
- upstream `otelcol-contrib` as the broad open-source baseline.

This mix is uncomfortable in the right way. It prevents the study from pretending the market offers one neat category. Enterprises do not buy protocols in isolation. They operate systems, contracts, dashboards, binaries, policy models, secrets, and escalation paths.

The first lab lessons were not about log parsing. They were about identity, status, and ownership. A collector appeared, but not always with the operator-facing fields a control plane needs. A status was visible, but not always enough to understand applied configuration. An upstream collector could be observed by a managed product, but lifecycle remained external. A custom OpAMP server could be shaped to the lab, but every missing feature became product engineering.

That is why this series does not attempt to crown a universal winner. The useful output is narrower: for a logs-only, public, anonymized study, what did each path prove, what remained external, and what would a large enterprise still need to build or buy?

## What Counts As Success

For the standalone OpAMP path, success means more than "logs arrived." The agent must appear in inventory with stable anonymized identity. The server must assign desired configuration. The agent must report whether configuration was applied or failed. The collector must send synthetic logs to the backend. A configuration change must alter ingest behavior in a measurable way. Failure of the backend, the OpAMP server, or the collector must produce understandable status.

For managed benchmarks, success is different. The question is not whether Fleet or Bindplane is "better than OpAMP." Fleet and Bindplane are product control planes. The useful question is what they absorb for operators and what remains coupled to their model. If a managed product solves enrollment, inventory, status, and UI, does it also solve remote configuration for this exact OTel-only path? If it makes onboarding easy, does it make exit easy? If it observes a collector, does it own lifecycle?

The final series structure follows that path. Part 2 builds the open OpAMP route and documents the friction. Part 3 looks at managed control planes. Part 4 runs the exit, secrets, and outage drill. Part 5 gives the enterprise verdict.

The short preview is this: OpAMP is the right protocol to study for vendor-neutral fleet management, and the Go and Python projects are useful foundations for experimentation. But a protocol foundation is not the same as an enterprise control plane. The interesting work begins after the first connection succeeds.
