---
series: opamp-enterprise-adoption
part: 3
language: en
status: draft
evidence_review: complete
contradictory_review: complete
---

# Managed Control Planes Change The Question

The open OpAMP lab answered one question: can a team build a vendor-neutral control loop around OpenTelemetry collectors? Yes, with effort.

The managed benchmarks ask a different question: what does a product control plane absorb for operators, and what remains coupled, external, or unfinished for a logs-only OTel path?

This distinction matters because managed products are not just protocol endpoints. They bring UI, onboarding flows, status models, secrets, policy abstractions, documentation, support paths, and commercial terms. They can make day-2 operations much easier. They can also introduce product-specific configuration models that become part of the exit plan.

The lab focused on two managed paths: Elastic Fleet in an OTel-only mode with upstream `otelcol-contrib`, and Bindplane using BDOT. Neither result should be generalized beyond the tested scenarios. The point was not to rank vendors globally. The point was to compare what the lab could prove for a logs-only enterprise question.

## Elastic Fleet OTel-Only

Fleet is normally associated with Elastic Agent, but the lab tested an OTel-only path: upstream `otelcol-contrib` connecting through Fleet's OpAMP flow without installing Elastic Agent. That is an important scenario for teams that want visibility into OpenTelemetry collectors while keeping the collector binary upstream.

The first connection passed. Fleet's Add Collector flow produced configuration. One upstream `otelcol-contrib` collector connected. The UI showed healthy status, and logs were visible in Elastic. The managed experience was immediately useful: inventory, component health, effective configuration inspection, and status were available without building a custom dashboard first.

The screenshot for this section should use the stale-row view in `assets/screenshots/kibana-fleet-agents-table.png`; the healthy first-connection state is described from the retained run notes and CSV evidence.

The caveat was equally important. In the tested OTel-only flow, remote configuration was visible but not editable as a Fleet-managed policy path. Bad config handling belonged to external validation and systemd. Restart, stop, start, install, cleanup, and lifecycle automation were also external operations. Fleet observed the resulting state, but it did not own the full lifecycle of the upstream collector in the way it owns Elastic Agent.

The restart test exposed an identity issue. Without a stable `instance_uid`, duplicate stale rows appeared. After fixing the stable instance identity, subsequent restarts behaved better. A disconnect test passed: stopping the collector for 75 seconds showed it offline, and restart returned it to healthy in about 12 seconds. That is useful control-plane visibility.

Scale onboarding did not pass. The lab attempted extra collectors after correcting initial config and telemetry conflicts, but hit OpAMP `401` responses when reusing a generated credential. That does not prove Fleet cannot scale. It proves this public lab did not establish the onboarding workflow for multiple upstream OTel collectors with reused generated material. The correct evidence label is blocked, not failed at enterprise scale.

The Fleet result is therefore balanced. Fleet gave a strong visibility benchmark for a single stable upstream collector. It did not remove the need for external lifecycle automation in the OTel-only path tested here.

## Bindplane With BDOT

Bindplane approached the problem from a telemetry pipeline management direction. The first pass connected one Linux VM through BDOT `1.101.2` and showed useful UI inventory: status, type, version, operating system, agent ID, remote address, MAC address, labels, fleet, and configuration fields. The install wizard made first-agent onboarding straightforward.

That was meaningful. In the custom OpAMP path, the lab had to build and normalize much of that operator surface. In Bindplane, the operator surface appeared quickly.

There was still friction. The generated install command was product-specific and depended on a secret key. In SSH automation, the public install script failed without a terminal setting; setting `TERM=xterm` fixed the run. That is not a large architectural issue, but it is exactly the sort of thing a POC should record. Day-2 operations are built from small pieces of friction.

The configuration builder looked stronger than the Fleet OTel-only path for day-2 workflow. A File source mapped cleanly to the synthetic log path, and the source was saved. The destination path was more complicated. The Elasticsearch OTLP preset asked for an APM URL and secret token, which did not fit the lab's existing Elastic output credential flow. The portable route appeared to be a Custom destination with raw OTel exporter YAML, but the sanitized rollout was not completed in the tested pass.

That matters for exit. A product model can make configuration authoring easier, but if the destination is represented in product-specific fields, the team must be able to reconstruct portable OTel YAML during migration.

Bindplane UI state is described from the retained browser notes and CSV evidence. No Bindplane screenshot is included in the curated public asset set for this first draft.

## Bring-Your-Own Collector Friction

The most restrictive Bindplane finding appeared in the custom OCB test. The lab built an OCB collector with the upstream OpAMP extension and used the documented endpoint/header shape, labels, and a valid ULID instance UID. The service started, but Bindplane rejected the WebSocket handshake with `403 Forbidden`.

The public docs described non-BDOT collectors as an Enterprise or bring-your-own-collector feature, and the standard OpAMP extension path as visibility-only for remote configuration. In practical terms, that made the custom distribution path a commercial and functional friction point, not just a YAML exercise.

This is not a criticism of Bindplane for having product boundaries. Product boundaries are real. The enterprise lesson is that "OpenTelemetry-compatible" and "bring any collector with full remote config" are not the same claim. Procurement, architecture, and platform teams need to test the exact collector distribution and management workflow they expect to operate.

## What Managed Products Solved

The managed benchmarks solved several problems the open path had to build.

They gave an operator UI quickly. They showed connected and disconnected state. They provided inventory fields that are useful during an incident. They reduced the amount of custom dashboarding needed for the first proof. They provided onboarding flows that were easier than hand-rolling a protocol lab. They made the difference between a control-plane product and a protocol implementation visible.

That value is real. A large enterprise should not dismiss it because an open protocol exists. Paying a product to absorb operational workflow can be rational, especially when the internal platform team is small or already overloaded.

## What Remained External Or Coupled

The same runs showed what remained outside the products in the tested paths.

For Fleet OTel-only, deployment, restart, config validation, upgrade and downgrade, stable collector identity, and multi-collector onboarding remained operator-owned in the lab. Fleet gave visibility, but the upstream collector lifecycle still depended on external automation.

For Bindplane, the UI and day-2 workflow were stronger, but BDOT and the product source/destination model became part of the operating surface. A custom OCB collector was blocked by product boundary and permission behavior in the tested account. Exit required reconstructing endpoint, secret, collector binary path, source and destination YAML, and supervisor configuration.

The managed path therefore changes the question from "can we avoid product engineering?" to "which product engineering do we still own, and which coupling are we accepting?"

## The Benchmark Value

Fleet and Bindplane were useful because they made the open OpAMP bar more concrete. A custom control plane cannot just say it is vendor-neutral. It must show the operator fields, state transitions, failure handling, rollout controls, stale cleanup, and audit path that managed products put in front of users.

At the same time, a managed product cannot just say it supports OpenTelemetry. For a large enterprise, the tested path must prove lifecycle ownership, portable config, secrets rotation, scale onboarding, and exit behavior.

That is the productive middle. Managed control planes are ahead on operator workflow. Open OpAMP is ahead on portability and protocol control. Neither answer is complete unless the enterprise knows exactly which responsibilities remain with its own team.
