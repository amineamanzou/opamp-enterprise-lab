---
series: opamp-enterprise-adoption
part: 4
language: en
status: draft
evidence_review: complete
contradictory_review: complete
---

# The Exit Drill: Secrets, Stale Rows, And Outage Behavior

The most useful POC tests are the ones that make a comfortable architecture uncomfortable. For collector fleet management, that means testing exit, secrets, and control-plane outage behavior.

The final lab drill used a simple question: if we move away from a managed control plane toward the custom OpAMP Go path, what breaks, what keeps running, and what evidence remains after teardown?

The run was intentionally limited. The exit target was custom OpAMP Go. Bindplane Enterprise or bring-your-own-collector paths were excluded. New scale paliers were excluded. The lab did not claim a 100k-host production test. It used the existing public lab evidence and a final live drill to measure the mechanics that matter for enterprise adoption.

Part 4 should be the most visual article in the series. The screenshots should include `assets/screenshots/kibana-opamp-overview.png`, `assets/screenshots/kibana-opamp-agent-lifecycle.png`, `assets/screenshots/kibana-opamp-volumetry-capacity.png`, and `assets/screenshots/kibana-fleet-agents-table.png`. These images show the control-plane story without exposing tenant identifiers, personal accounts, private hostnames, URLs, or credentials.

## Exit Is Not One Thing

"Can we exit?" sounds binary. The lab showed it is made of several smaller questions.

Can the collector binary be replaced? Can the endpoint and auth material be changed? Can the previous product's inventory be cleaned up? Can the old configuration model be reconstructed as portable OTel YAML? Can dashboards continue to work? Can the data path continue? Can operators prove what happened later?

Fleet OTel-only and Bindplane answered those questions differently.

For Fleet OTel-only, the prior run had already stopped the collector before the live drill. That means the final exit run did not produce a fresh downtime measurement. The useful finding was stale control-plane state: the Fleet UI still showed three offline `otelcol-contrib` rows from the earlier run. The upstream collector and Elastic OTLP data path were portable in principle, but Fleet state and lifecycle automation remained outside the exit target.

For Bindplane, the drill was mechanically executable. The active BDOT service was stopped, and the supervisor-managed OCB collector became active immediately at the systemd service-state level. The measured time to active state was less than one second. But continuity from BDOT to OCB could not be measured as an application-log continuity result because BDOT was running a minimal `nop` configuration. Bindplane retained the old agent row as disconnected, so stale inventory cleanup remained a product or API task.

The right conclusion is precise: Bindplane-to-OpAMP exit was partial but executable. Fleet-to-OpAMP exit was documented from prior evidence and stale UI state, not rerun as a fresh live migration.

## The Secrets Test

Secrets are where lab demos often become production problems. Initial enrollment is the easy part. The hard part is safe distribution, overlapping rotation, revocation, audit evidence, and blast-radius control.

The production-sensitive categories in this study included the OpAMP bearer token, Elastic output credentials, Fleet-generated OpAMP auth material, Bindplane secret material, Bindplane API automation credentials, SOPS age identity, and Kubernetes Secret objects. The article does not need to publish exact names or values. It needs to explain the operational shape.

For the custom OpAMP Go path, a single shared token is not a production-grade access-control model for a large estate. At minimum, an enterprise needs token segmentation by cohort or environment, overlapping validity during rotation, revocation, audit events for auth failures, and a way to roll agents safely from old to new credentials.

The destructive token drill found a stricter issue. The host agent token was replaced with an invalid value and the supervisor was restarted. The supervisor stayed active, local collector health returned quickly, and the host-agent inventory timestamp refreshed after the restart. In the tested Go implementation, the server did not enforce the OpAMP authorization header as an access-control boundary.

That finding changes the readiness verdict. Token rotation cannot be treated as a runbook until token validation exists. Without server-side bearer validation, the token is configuration ceremony, not enforcement. Before production use, the custom path needs actual authentication, token lifecycle, rotation, revocation, and auditable failure behavior.

The visual companion for this section should be the sanitized OpAMP overview and lifecycle screenshots, with the written evidence carrying the token finding.

## Control-Plane Outage

The expected resilience property is straightforward: once a collector has a valid local configuration, telemetry export should continue if only the management plane goes down. The control plane should be allowed to be unavailable without immediately breaking the data path.

The custom OpAMP Go outage confirmed that property in the lab. The OpAMP server was stopped while the supervisor-managed collector continued running. The supervisor logged connection failures to the OpAMP endpoint, but Elastic continued receiving host logs, host metrics, collector logs, and collector metrics. A query during the outage returned 1,898 events in the measured two-minute window. Data path downtime was recorded as zero for that outage scenario.

After the server restarted, the host-agent inventory timestamp refreshed about 25 seconds later. That is a useful recovery signal. It proves the agent could reconnect and report state after a control-plane outage.

It also exposed an observability gap. The custom server's connection endpoint and connected-agent stats reported zero active connections even while inventory was refreshing. That cannot be waved away in an enterprise setting. If operators cannot trust active connection accounting, they will struggle during incident response, capacity planning, and reconnect-storm analysis.

This section should use `assets/screenshots/kibana-opamp-volumetry-capacity.png` to show the data path and control-plane metrics side by side.

## Stale Rows Are A Real Operational Problem

Stale inventory sounds minor until the fleet is large. At 100k assets, stale rows can turn dashboards into fiction. Operators need to know whether an agent is disconnected, decommissioned, replaced, duplicated, or simply reporting under a new identity.

The final drill had stale state in every direction.

Fleet retained three offline upstream collector rows after the previous OTel-only run. Bindplane retained the old BDOT row as disconnected after the service was stopped and replaced. The custom OpAMP inventory still contained 10,022 prior scale-test agents. That number was evidence residue, not an active fleet. But it showed the cleanup problem clearly: inventory compaction, stale-agent TTL, decommission workflows, and audit semantics are product requirements.

The custom OpAMP path should not be judged harshly for retaining lab residue by default. It should be judged realistically. A large enterprise needs rules for when an agent disappears, when a replacement inherits identity, when historical inventory is retained, and when a stale row stops affecting operational status.

This is one of the places where managed products often feel better because they already have a UI state model. The lab still showed stale rows there too, which is a useful reminder: state retention is not solved by having a product. It is solved by having the right lifecycle semantics for the organization.

## Teardown As Evidence

After the final token drill, the lab infrastructure was destroyed. Terraform removed four servers, one firewall, and one SSH key. The state was empty, and cloud label queries returned zero remaining lab servers and firewalls.

That teardown matters for public evidence. It keeps the study clean, reduces the chance of forgotten test infrastructure, and proves the screenshots and API summaries are historical artifacts rather than live access paths. Elastic still held historical dashboard and aggregate evidence after teardown: synthetic app logs, host and Kubernetes metrics, OpAMP inventory, OpAMP lifecycle events, and Fleet agent-status documents.

The publication should avoid raw browser state and raw screenshots that might expose account or project chrome. The sanitized dashboard references are enough.

## What The Drill Changed

Before the exit drill, the custom OpAMP path looked like a promising portable route with known product gaps. After the drill, the verdict became sharper.

The data path behavior was encouraging. During an OpAMP control-plane outage, local collection continued and Elastic received events. The migration mechanics from Bindplane BDOT to a supervisor-managed OCB collector were fast at the service-state level. The lab could preserve useful historical evidence after teardown.

The control-plane product gaps were not small. Server-side auth enforcement was missing in the tested implementation. Connection accounting was unreliable. Stale inventory needed cleanup semantics. Managed products left stale rows too. Exit required reconstructing configuration and ownership around lifecycle, dashboards, secrets, and service management.

For enterprises, this is the lesson: exit is not just changing an endpoint. It is proving that data keeps flowing, secrets are enforceable, old state is understandable, and operators can trust what the control plane says.
