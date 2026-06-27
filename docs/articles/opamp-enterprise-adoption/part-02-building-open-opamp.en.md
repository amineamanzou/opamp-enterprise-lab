---
series: opamp-enterprise-adoption
part: 2
language: en
status: draft
evidence_review: complete
contradictory_review: complete
---

# Building The Open OpAMP Path

The open OpAMP route is attractive for a simple reason: it separates collector management from a single vendor product. In theory, an enterprise can use OpAMP to manage agents, assign configuration, receive status, and keep the telemetry backend replaceable. In a large estate, that portability matters.

The lab quickly showed the other side of the trade. OpAMP gives useful protocol primitives, and `opamp-go` gives real Go building blocks. `opamp-server-py` is friendly for experimentation. But a large-enterprise control plane is not created by importing a library. Inventory, identity, status, configuration safety, UI, API, persistence, audit, authorization, stale cleanup, and lifecycle orchestration all have to exist somewhere.

The standalone blueprint was deliberately small. An agent wrapper connects to an OpAMP server, reports identity and health, receives a logs-only desired configuration, writes local collector config, supervises the collector process, and reports effective configuration state. The collector tails synthetic logs and exports them to the shared Elastic backend. The reference architecture for that path is represented by `assets/diagrams/opamp-management-loop.png`.

This design keeps OpAMP in its proper layer. OpAMP is the management channel. The collector remains an OpenTelemetry Collector distribution: OCB minimal, EDOT, or upstream `otelcol-contrib`. The backend remains a backend. The supervisor bridges them into something that behaves like a managed agent.

## First Contact Is Not Enough

The first successful connection is satisfying, but it is a weak enterprise signal. A real operator needs to know what connected, where it is running, what version it has, what config it should have, what config it actually applied, and whether its data path is healthy.

The vanilla Go lab exposed that gap. Connected agents initially appeared with raw OpAMP instance identifiers instead of readable operator identities. Some entries had empty version, hostname, or health fields. Remote config status could be unset until the collector reported state. Desired config hash stayed empty until the server actually assigned a desired config, which was expected, but easy to misread in a UI.

The cause was not a single bug. It was the normal friction of turning protocol messages into an operator product. The collector configuration first attempted to send identifying attributes in a shape the deployed Collector build rejected. The accepted path in this lab was `agent_description.non_identifying_attributes`. The Collector OpAMP extension could report a raw instance UID as the agent ID even when richer host and version metadata existed. The server created an early entry from the first message and could later receive richer information that looked like a second logical entry instead of an update to the first.

Those details are not embarrassing. They are the work.

The lab corrected the path by adding useful metadata such as service instance ID, service version, and host name to the accepted agent description fields, then matching those attributes in emitted logs. The server was updated to merge richer agent state into earlier raw entries, expose a readable identity fallback, normalize API and UI representation, and allow lookup or config assignment by a public operator ID while preserving safe internal connection keys.

After redeploying and restarting collectors, active agents exposed readable IDs, version `0.151.0`, non-empty hostnames, healthy status, capabilities, and remote config state. That made the control plane usable for comparison. It also proved the point: the protocol path became clearer only after product work.

The identity correction is carried by the written lab notes rather than a dedicated screenshot. The dashboard screenshots later in this part show the resulting OpAMP inventory and lifecycle evidence.

## OCB And The Supervisor Boundary

OCB, the OpenTelemetry Collector Builder, is useful because it lets a team build a collector distribution with an explicit component set. For a logs-only first version, that is a good discipline. A smaller binary is easier to reason about than a broad distribution that contains many receivers, processors, exporters, and extensions the first rollout does not need.

But OCB does not solve fleet management by itself. It creates a collector. It does not create enrollment, desired state, rollout rings, config validation, rollback, audit, stale cleanup, or operator dashboards. In the lab architecture, those responsibilities move to the supervisor and OpAMP server.

That boundary is important. If the supervisor writes collector config locally, then the supervisor owns safe rendering. If it restarts the collector, it owns service-manager integration and restart policy. If it reports applied configuration, it must distinguish "I wrote the file" from "the collector accepted the file" and "the pipeline is exporting data." If it keeps running during a control-plane outage, it needs a local last-known-good config and understandable logs.

This is where an open path becomes an engineering program. It may still be the right program, especially for organizations that need strong portability and can invest in platform tooling. But it should be budgeted as software product work, not as a weekend integration.

## The Python Path

`opamp-server-py` belongs in the study for a different reason. A Python server can be approachable for experimentation, demos, and teaching the protocol. It is valuable when a team wants to see messages, state transitions, and API behavior without carrying the weight of a production Go service.

The lab posture toward Python should be friendly but realistic. A smaller codebase can accelerate learning, but feature parity is not free. The same enterprise questions still apply: persistence, auth, UI, API compatibility, config assignment, validation, stale cleanup, and operational support. If the Python route is used as a lab reference, that is a good use. If it is used as a production control plane, the team must explicitly own the hardening work.

That is not a criticism of the project. It is the difference between a useful implementation and a large-enterprise product surface.

## UI And API Friction

The lab began with an API-first custom server. That was enough to test messages and state, but not enough to score operator experience. The moment the study compared managed control planes, the custom path needed a UI or at least a normalized public API.

This is a common trap. Engineers can inspect raw JSON and know what it means. Operators need a stable inventory. They need filters by site, OS, rollout ring, health, version, and config hash. They need to see the difference between desired, offered, accepted, applied, failed, disconnected, and stale. They need to know whether a row is a current agent or residue from a prior test. They need audit history when someone asks why a config changed.

The custom Go server became a reference control plane only after these operator-facing needs were made visible. In the final comparison, that work counts against setup and maintenance effort. The open route gives control and portability, but the team owns the shape of the product.

## What The Open Path Proved

The open OpAMP path proved that the management loop is feasible in a public lab. A custom server can receive agent state. A supervisor-managed collector can run a logs-only pipeline. The agent can report status. Elastic can receive synthetic logs. Dashboards can show OpAMP inventory, lifecycle events, config status changes, synthetic log rate, and collector metrics. The publication should use `assets/screenshots/kibana-opamp-overview.png` and `assets/screenshots/kibana-opamp-agent-lifecycle.png` for that story.

It also proved that enterprise readiness is outside the protocol alone. Stable identity had to be shaped. UI and API representation had to be normalized. Config state had to be interpreted. Auth still needed hardening, as Part 4 shows. Stale inventory and connection accounting still needed product work.

The best way to describe the result is not "OpAMP is not ready." That is too blunt and not fair to the protocol. The better statement is: OpAMP is a credible foundation for expert teams and vendors building collector management, but the open-source path tested here still requires significant product engineering before it looks like a large-enterprise control plane.
