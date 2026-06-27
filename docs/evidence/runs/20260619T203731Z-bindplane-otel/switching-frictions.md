# Bindplane To OpAMP Switching Frictions

| Area | What to inspect | Friction level | Evidence |
| --- | --- | --- | --- |
| Collector binary | Upstream `otelcol-contrib` versus BDOT requirement. | high | UI defaulted to `BDOT 1.x (Stable)` and generated a BDOT install command. A separate lab OCB distro attempt used the documented OpAMP extension pattern but was rejected with `403 Forbidden`; Bindplane docs describe non-BDOT collectors as Enterprise/BYOC and visibility-limited. |
| OpAMP endpoint | Endpoint, auth headers, TLS, tenancy, and generated config shape. | medium | Wizard generated WebSocket OpAMP endpoint `wss://app.bindplane.com/v1/opamp` plus a secret key. Secret handling is easy for one host but must be automated/redacted for scale. |
| Remote config | Exportability and portability of generated configs. | medium | Builder uses Bindplane resources: configuration details, sources, destinations. `Custom` destination accepts exporter YAML, but config export/rollout still needs testing. |
| Rollout safety | Validation, staged rollout, rollback, and bad config behavior. | pending | Not tested; draft File source was saved but no configuration was rolled out. |
| Identity | Stable collector IDs across restart/reinstall/scale. | medium | Agent detail exposes Agent ID plus host/network metadata. Restart kept the same visible agent row during this short run; reinstall and scale identity remain untested. |
| Health | Component health, last check-in, error text, and stale state. | medium | Status showed Connected/Disconnected. Health tab had CPU/Memory panels but showed `No Data` during the first observation window. |
| Lifecycle | Deploy, restart, upgrade, downgrade, uninstall ownership. | medium | Install wizard generated a host command and systemd service. Restart/stop/start remained SSH/systemd operations in the lab; upgrade/downgrade UI/API not tested. |
| Data model | Bindplane-specific attributes, metadata, labels, and API entities. | medium | Agent detail includes type, version, platform, OS, Agent ID, remote address, MAC address, fleet, configuration, and labels. Evidence must redact host/network identifiers. |
| Pricing | Collector, telemetry volume, user, support, and self-hosting limits. | pending | Public pricing captured as source-only. Authenticated account billing/usage page still needs screenshot/state capture. |
| Scale operations | API/UI usability and onboarding model at paliers. | pending | Not tested beyond one connected BDOT collector. |

Verdict format:

- Replaceable by OpAMP: partial for BDOT-managed fleets; low for using arbitrary custom OCB under the current account because the handshake is blocked.
- Exit work required: export or reconstruct OTel YAML, replace endpoint/secret, map Bindplane identity/resources to OpAMP inventory, replace source/destination builder workflows, own deploy/restart/upgrade tooling, and update dashboards.
- At-scale risk: BDOT coupling, Enterprise/BYOC licensing for custom distributions, secret distribution, pricing limits, rollout blast radius, stale inventory, API rate limits, and support dependency.
