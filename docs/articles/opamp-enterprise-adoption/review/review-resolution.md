# Review Resolution

These resolutions were used as the integration checklist for the first article-series draft. The article files still use `status: draft`, but the evidence and contradictory-review gates are marked complete.

| ID | Objection | Resolution status | Integrated resolution language |
| --- | --- | --- | --- |
| O01 | Small lab presented as enterprise evidence | Accept | "This series is a logs-only lab study against enterprise-shaped requirements. It is not production validation of an enterprise fleet." |
| O02 | No real 100k scale run | Accept | "The 100,000-asset scenario is a design target and modeling frame. Current lab evidence does not prove 100k connected collectors; scale conclusions are limited to measured paliers and clearly marked extrapolations." |
| O03 | Fleet OTel-only testing incomplete | Accept | "Fleet OTel-only was lab-proven for visibility of one stable upstream collector. In this lab, editable remote policy, product-managed lifecycle, scale onboarding, and fresh outage behavior remain unproven." |
| O04 | Bindplane testing incomplete | Accept | "Bindplane evidence currently proves single BDOT onboarding and basic lifecycle visibility. Custom distro support, portable Elastic exporter rollout, bad config safety, upgrade/downgrade, and scale require additional runs." |
| O05 | Synthetic logs weaken production claims | Accept | "All V1 evidence uses synthetic logs for safety and repeatability. The results compare control-plane behavior, not production log-source diversity or ingest reliability under real-world log complexity." |
| O06 | Elastic backend bias | Partially accept | "Elastic Cloud was the shared lab destination for comparability. Dashboard and document-count evidence should be read as Elastic-backed lab evidence, not as a claim that the architecture requires Elastic or that other backends behave identically." |
| O07 | Custom `opamp-go` production gaps | Accept | "The custom Go server is a protocol-level reference, not a hardened platform. Production use would require enforced bearer validation, token segmentation and rotation, audit logs, stale cleanup, connection accounting, rollout safety, persistence hardening, and operator APIs/UI." |
| O08 | `opamp-server-py` unfilled evidence cells and lab patches | Accept | "`opamp-server-py` is evaluated as an experimental UI/prototyping base. Upstream baseline evidence and vendored lab-build evidence remain separate because several day-2 capabilities required local feature work." |
| O09 | Credential deletion is not asset hygiene | Accept | "Exit hygiene includes credentials, generated configs, service units, stale inventory rows, dashboards/data views, encrypted secret recipients, Kubernetes Secret objects, audit evidence, and historical backend data. Rotating or deleting one key is not a complete cleanup." |
| O10 | Screenshots are anecdotal without artifacts | Reject | "Keep sanitized screenshots because they help readers understand UI state, but treat them as illustrative. Claims should be grounded in committed CSVs, configs, runbooks, timestamps, aggregate API artifacts, and explicit evidence labels." |
| O11 | Exit drill is asymmetric | Accept | "The final exit drill was intentionally asymmetric: Fleet was already stopped, Bindplane BDOT used a minimal `nop` config, and custom OpAMP had the live supervisor path. Time-to-exit and continuity numbers are scenario-specific and should not be ranked as equivalent product measurements." |
| O12 | Pricing evidence dated and incomplete | Accept | "Pricing notes are dated to the 2026-06-19 access window and are not procurement advice. Authenticated plan limits and account-specific terms need separate capture before making commercial recommendations." |
| O13 | Identity and stale inventory understated | Accept | "Stable identity, stale-agent cleanup, and inventory compaction are core fleet-management requirements. Duplicate rows, disconnected rows, and raw UID entries are correctness and auditability risks, not just UI clutter." |
| O14 | External automation mistaken for product lifecycle | Accept | "Each lifecycle result should identify whether the action was product-managed, externally automated through SSH/systemd/supervisor scripts, or not tested. Observation in a UI is not the same as lifecycle control." |
| O15 | Data-path outage resilience overread | Accept | "The custom OpAMP outage drill proves only that a collector with a valid local config continued exporting while the control plane was down. It does not prove secure enrollment, config rollout, auditability, scale behavior, or production recovery correctness." |

## Coordinator Integration Notes

Use the following baseline paragraph near the start of the series:

> The lab is deliberately narrow: logs-only, synthetic data, a shared Elastic Cloud backend, and a small number of real collectors plus limited mock-agent pressure. It is useful because it exposes control-plane responsibilities that are easy to hide in architecture diagrams: identity, remote config, bad config safety, rollout ownership, stale inventory, secrets, exit hygiene, and evidence capture. It should not be read as a production-scale benchmark.

Use this language before any Fleet/Bindplane/custom comparison table:

> The comparison separates what the product or implementation directly managed from what the lab handled externally through systemd, SSH, supervisor scripts, generated configs, or manual UI/API checks. A row marked "observed" does not necessarily mean the control plane owned the lifecycle action.

Use this language around the 100k architecture:

> The 100k architecture is a reference design for the kinds of controls a large estate would need. The current repository evidence does not contain a 100k production or lab run, so the architecture is a target for future validation rather than a result.

Use this language around screenshots:

> Sanitized screenshots are included to show what an operator saw. The claims rely on committed runbooks, CSVs, redacted configs, timestamps, and aggregate API evidence wherever possible.

Use this language around secrets and exit drills:

> Credential rotation is only one part of exit hygiene. A credible exit also removes or documents generated configs, stale control-plane inventory, local service state, dashboards/data views, encrypted secret recipients, Kubernetes secrets, and audit trails. The custom OpAMP invalid-token drill also showed that a configured token is not an access-control boundary unless the server enforces it.
