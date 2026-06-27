# OpenLit To OpAMP Switching Frictions

| Area | What to inspect | Friction level | Evidence |
| --- | --- | --- | --- |
| Collector binary | Upstream `otelcol-contrib` versus OpenLit-specific distribution requirement. | pending | pending |
| OpAMP endpoint | Endpoint, auth headers, TLS/mTLS, tenancy, and generated config shape. | pending | pending |
| Remote config | Exportability and portability of generated configs. | pending | pending |
| Rollout safety | Validation, staged rollout, rollback, and bad config behavior. | pending | pending |
| Identity | Stable collector IDs across restart/reinstall/scale. | pending | pending |
| Health | Component health, last check-in, error text, and stale state. | pending | pending |
| Lifecycle | Deploy, restart, upgrade, downgrade, uninstall ownership. | pending | pending |
| Controller coupling | Whether OpenLit Controller concepts are required for collector fleet management. | pending | pending |
| Data model | OpenLit-specific attributes, metadata, labels, and API entities. | pending | pending |
| Pricing | Collector, telemetry volume, user, support, cloud, and self-hosting limits. | pending | pending |
| Scale operations | API/UI usability and onboarding model at paliers. | pending | pending |

Verdict format:

- Replaceable by OpAMP: yes/no/partial.
- Exit work required: config export, endpoint/auth replacement, identity mapping, dashboards, deploy tooling.
- At-scale risk: plan limits, credential lifecycle, TLS/mTLS operations, rollout blast radius, stale inventory, API rate limits, and support dependency.
