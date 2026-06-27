# Fleet Management Comparison

Access date for pricing and public-source notes: 2026-06-19.

This document compares fleet-management options for OpenTelemetry collectors in the lab. It separates license or subscription price from the engineering work required to operate collector lifecycle at scale.

## Pricing Snapshot

| Option | Public pricing signal | Lab interpretation |
| --- | --- | --- |
| Elastic Fleet OTel-only | Elastic Cloud pricing is organized around hosted and serverless Elastic offerings for Search, Observability, and Security. Source: https://www.elastic.co/pricing | The Fleet OTel-only path did not expose a separate per-collector management price in the lab. Cost is mainly the Elastic Cloud deployment, ingest, storage, retention, and feature tier. |
| Bindplane | The Bindplane pricing page lists Free, Growth, and Enterprise plans for telemetry pipeline management. The page describes Free at $0/month, Growth as a paid monthly plan with included telemetry and connected-collector limits, Enterprise as custom pricing, and additional usage dimensions for telemetry volume and collectors. Source: https://bindplane.com/pricing | Bindplane has an explicit fleet-management commercial surface. The lab must record the exact plan limits shown in the authenticated account because trial/account terms can differ from the public page. |
| OpenLit | OpenLit public documentation and pricing pages describe an observability product surface with OpenTelemetry and Fleet Hub documentation. Sources: https://docs.openlit.io/latest/overview, https://docs.openlit.io/latest/openlit/observability/fleet-hub, and https://openlit.io/pricing | OpenLit is a new source-only candidate in this study. The lab must record whether Fleet Hub is usable self-hosted or cloud-hosted, which plan limits apply, and whether Controller is separate from collector fleet management. |
| Custom OpAMP Go | `opamp-go` is open source. Source: https://github.com/open-telemetry/opamp-go | No product license cost, but the team owns server development, UI/API, persistence, security, rollout safety, support, and on-call. |
| opamp-server-py | Upstream project is open source. Source: https://github.com/agardnerIT/opamp-server-py | No product license cost, but the lab modifications showed that feature parity requires direct product engineering in a smaller codebase with less production hardening. |

Pricing changes frequently. Treat the values above as a dated study input, not procurement advice.

## Fleet Management Limits Observed

| Capability | Elastic Fleet OTel-only | Bindplane | OpenLit Fleet Hub | Custom OpAMP Go | opamp-server-py lab |
| --- | --- | --- | --- | --- | --- |
| OTel-only collector path | Lab-proven with upstream `otelcol-contrib` 0.151.0 and no Elastic Agent. | Lab-proven through BDOT 1.101.2. Lab OCB distro attempt was blocked with OpAMP `403 Forbidden`; docs describe non-BDOT collectors as Enterprise/BYOC and standard OpAMP extension as visibility-only. | Source-only; to test with upstream `otelcol-contrib` first and document any OpenLit distribution or Controller requirement. | Lab-controlled through the custom agent and OpAMP server. | Lab-controlled after vendored modifications. |
| Central inventory | Lab-proven for a single stable collector. Duplicate stale rows appeared when `instance_uid` was not stable. | Lab-proven for one BDOT collector, with status, type, version, OS, Agent ID, remote address, MAC address, labels, fleet, and configuration fields. | Source-only; Fleet Hub UI/API evidence required. | Implemented as part of the lab reference. | Implemented in the modified lab version. |
| Remote config | Effective config is visible, but no editable remote policy path was found for the OTel collector flow. | Partial: source/destination builder tested and File source saved; rollout not completed. | Source-only; test desired/effective state, bad config, rollback, and TLS/mTLS interactions. | Implemented for the lab scenarios. | Added as lab feature work after upstream baseline gaps. |
| Bad config handling | External validation and systemd own the failure. Fleet observes resulting health/connectivity. | Not tested yet; requires a known-good Bindplane rollout first. | Not tested yet; requires a known-good OpenLit Fleet Hub rollout first. | Lab owns validation and rollback behavior. | Lab owns added validation behavior. |
| Restart and lifecycle | Restart, stop/start, install, and cleanup were external SSH/systemd operations. | Restart and stop/start were external SSH/systemd operations; Bindplane observed Connected/Disconnected state. Install is product-generated command. | Not tested yet; record whether OpenLit owns lifecycle or only observes externally managed collectors. | Lab feature surface can expose commands, but operators own safety controls. | Added only where needed for the lab scenarios. |
| Upgrade/downgrade | Not proven for OTel-only collector management. | To test explicitly. | To test explicitly after first connection and remote config are proven. | Lab scenario supported by deployment automation, not by a mature packaged product. | To test only where the lab build/deploy path supports it. |
| Scale onboarding | Scale-10 was blocked by OpAMP credential reuse returning `401`; a per-collector or API onboarding workflow may be required. | Not tested beyond one collector. The generated secret must be automated and redacted before paliers. | Not planned for this product pass; OpenLit should be judged first on functional completeness, UI/API alignment, TLS operations, and maintainability because protocol volumetry belongs to the underlying OpAMP implementation. | Mock-agent scale evidence exists for protocol/server pressure. | Scale evidence exists for lab-modified server behavior. |
| Exit friction | Medium to high: endpoint/auth replacement is simple, but lifecycle automation, stable identity, dashboards, generated Elastic config, and credential model remain team-owned. | Medium to high: BDOT coupling, Bindplane source/destination model, endpoint/secret replacement, config export/reconstruction, and pricing limits must be handled. | Medium to high in the tested self-host path: Fleet Hub config export, endpoint/auth/TLS replacement, Controller boundary, identity mapping, lifecycle ownership, and browser asset packaging must be handled. The lab observed a CDN-backed Monaco editor blocked by the self-host CSP, which matters in airgapped or Artifactory-mediated platforms. | Low vendor lock-in, high build-and-maintain burden. | Low vendor lock-in, higher maturity and maintenance risk. |

## Exit Drill, Secrets, And Outage Control-Plane

Evidence packages:

- Planning skeleton: `docs/evidence/runs/20260619T222104Z-exit-drill-secrets-outage`.
- Live drill: `docs/evidence/runs/20260619T223502Z-exit-drill-secrets-outage`.

The final drill is scoped to an exit target of custom OpAMP Go. Bindplane Enterprise/BYOC and new scale paliers are excluded. The live drill stopped the active Bindplane BDOT service, started the supervisor-managed OCB collector against OpAMP Go, and ran a control-plane outage test.

| Dimension | Fleet OTel-only to OpAMP Go | Bindplane BDOT to OpAMP Go | Custom OpAMP Go |
| --- | --- | --- | --- |
| Exit status | Partially immediate. The upstream collector and Elastic OTLP data path are portable, but Fleet state and lifecycle automation remain external. In the live drill, Fleet collector rows were already stale/offline. | Partial but mechanically executable. BDOT was stopped and the lab OCB supervisor became active immediately; Bindplane kept the old BDOT row disconnected. | Immediate target for the host-agent exit, with no product exit friction. |
| Time-to-exit measurement | Not rerun because the Fleet collector was already stopped before the live drill. | Less than one second to active systemd state for `opampsupervisor-logs.service`; Elastic continuity from BDOT could not be measured because BDOT was running a minimal `nop` config. | OpAMP outage recovery was about 25 seconds from server restart to refreshed host-agent inventory. |
| Files and configs to modify | Collector service unit, OpAMP endpoint/header, stable `instance_uid`, supervisor config, and possibly Elastic dashboard/data-view ownership. | BDOT service replacement, OpAMP endpoint/header, collector binary path, source/destination YAML reconstruction, and supervisor config. | Server auth config, remote config assignment, supervisor config, and persistence/audit implementation. |
| Collection interruption risk | Expected to be short if the Elastic exporter config is reused; not measured in the live drill. | Higher until the Bindplane destination is reproduced as portable OTel YAML; live drill proved replacement export after start, not continuity from BDOT. | Live drill confirmed data-path continuity during OpAMP Go outage: Elastic received 1,898 host/supervisor events in the outage window. |
| Secrets to replace | Fleet OpAMP auth header and any generated Fleet enrollment material; keep or rotate `ELASTIC_API_KEY` separately. | Bindplane secret key, Bindplane API key for automation, and any destination credentials embedded in generated config. | `OPAMP_AUTH_TOKEN`; Elastic and Kubernetes credentials stay independent. |
| Stale agents left behind | Fleet UI showed three offline `otelcol-contrib` rows from the prior run. | Bindplane UI showed `opamp-poc-agent` disconnected after BDOT stop. | Custom cleanup and stale-agent TTL are product work; live OpAMP inventory still contained 10,022 prior scale-test agents. |
| Maintainer friction | Medium to high: Fleet is useful visibility, but deployment, rollback, validation, and upgrades are still operator-owned. | Medium to high: day-2 UI is stronger, but BDOT/product-model coupling increases exit work. | High: maximum portability, but rollout safety, audit, token lifecycle, stale cleanup, and UI/API are owned by the team. |

### Secrets Conclusions

The production-sensitive secrets are `OPAMP_AUTH_TOKEN`, `ELASTIC_API_KEY`, Fleet OpAMP auth material, Bindplane secret key, Bindplane API key, SOPS age identity, and Kubernetes Secret objects. The common operational problem is not initial creation; it is safe distribution, overlapping rotation, revocation, and audit evidence.

For the custom OpAMP Go path, token rotation should be treated as a product requirement before production use. A single shared `OPAMP_AUTH_TOKEN` has a large blast radius unless agents can be segmented by token, old and new tokens can overlap during rollout, and auth failures are auditable. Fleet and Bindplane rotation should be documented from UI/API paths, not forced during the final drill.

The final destructive token drill showed a stricter issue: replacing the host agent token with an invalid placeholder did not prevent the supervisor from connecting or refreshing inventory. In the current Go implementation, `OPAMP_AUTH_TOKEN` is not an enforced access-control boundary. Production use requires server-side bearer validation before any rotation or revocation workflow can be meaningful.

### Control-Plane Outage Conclusions

The expected control-plane outage property is that collectors continue exporting to Elastic when only OpAMP/Fleet/Bindplane connectivity is lost. The live custom OpAMP Go drill confirmed that behavior after the collector had a valid local config: stopping `opamp-poc-server.service` produced supervisor connection errors, but Elastic continued receiving host logs, host metrics, collector logs, and collector metrics. Fleet OTel-only should have the same data-path behavior when OTLP export is independent from Fleet OpAMP connectivity, but the live drill only captured stale/offline UI state because the Fleet collector was already stopped. Bindplane remains control-plane-only until its Elastic destination is finalized as portable OTel YAML.

Custom OpAMP Go has an immediate production gap: the live drill showed `/v1/opamp/connections` and `connected_agents` reporting zero even while the host-agent inventory timestamp refreshed. Connection accounting, stale-agent TTL, and inventory compaction need product work before this can be operated at scale.

After the final token drill, the Hetzner lab infrastructure was destroyed. Terraform removed four servers, one firewall, and one SSH key; state is empty and Hetzner API label queries returned zero remaining lab servers and firewalls.

## Elastic Fleet OTel-Only Findings

The Elastic OTel-only run proved that Fleet can observe an upstream OpenTelemetry Collector through OpAMP without installing Elastic Agent. The UI was useful for inventory, status, component health, and effective config inspection.

The same run also showed that this is not a full replacement for a fleet-management plane when constrained to upstream OTel collectors. The team still owns deployment, restart, config validation, upgrade/downgrade, collector identity, credential lifecycle, and scale onboarding. The strongest switching risk is not the collector binary; it is the operational glue around identity, rollout, and dashboards.

## Maintainer Burden

For a team operating collector fleets at scale, the main decision is whether to pay a product to absorb fleet-management workflow complexity or to build those workflows around OpAMP.

Custom OpAMP gives maximum portability and protocol control, but every feature becomes product work: persistence, auth, audit, rollout safety, UI, metrics, stale-agent cleanup, API compatibility, and support tooling. `opamp-server-py` can accelerate experimentation, but the lab evidence should keep tracking feature effort because parity with the Go reference is not free.

Elastic Fleet OTel-only lowers UI friction for visibility, but the lab evidence says it does not remove the need for external lifecycle automation. Bindplane should be evaluated primarily on whether it materially reduces that day-2 burden while keeping collector configs and data pipelines portable enough to exit back to OpAMP.

OpenLit should be evaluated with the same discipline. Fleet Hub may reduce day-2 friction if it provides inventory, remote config, health, and TLS/mTLS workflows around standard OpenTelemetry collectors. The first evidence pass must prove first connection, config rollout, bad-config behavior, and whether Controller is a separate optional surface or a required part of the collector-management path.

The self-hosted OpenLit pass also adds a maintainability check that is easy to miss in internet-connected labs: the Fleet Hub config editor depends on Monaco browser assets. In the tested image, the editor attempted to load Monaco from `cdn.jsdelivr.net` while the application CSP allowed only self-hosted scripts, leaving the config panels stuck on `Loading...` even though the API returned effective config data. For airgapped or Artifactory-mediated deployments, this is enterprise friction: Monaco assets need to be vendored or served from an approved internal origin, and CSP must be aligned with that packaging choice.

## Bindplane Initial Findings

The first Bindplane pass connected one Linux VM through BDOT 1.101.2 and showed useful inventory/status in the UI. The install wizard made first-agent onboarding straightforward, but the generated command is product-specific and depends on a secret key. In SSH automation, the public install script failed without `TERM`; setting `TERM=xterm` fixed the run.

The configuration builder is more complete than Elastic Fleet OTel-only for day-2 workflow, but it introduces product-model coupling. The File source mapped cleanly to the synthetic log path. The Elasticsearch OTLP preset did not fit the lab's existing Elastic `ApiKey` flow because it asked for APM URL and secret token. The portable route appears to be the Custom destination with raw OTel exporter YAML, which still needs a sanitized rollout test.

The follow-up custom distro test is more restrictive. Our OCB collector included the upstream OpAMP extension and used Bindplane's documented WebSocket endpoint/header shape, labels, and valid ULID instance UID. Bindplane rejected the handshake with `403 Forbidden`. The public docs state that using other OpenTelemetry distributions is an Enterprise feature and that the standard OpAMP extension path cannot receive remote configuration. That makes "bring our own distro" a commercial and functional friction point, not just a config exercise.
