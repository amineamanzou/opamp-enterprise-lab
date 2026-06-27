# Functional And Maintainability Scenarios

Do not run OpenLit volumetry paliers in this scenario. OpenLit Fleet Hub uses an OpAMP server implementation underneath; this pass evaluates product completeness, maintainability, and day-2 operator workflow rather than protocol fan-out.

| Area | What to inspect | Result |
| --- | --- | --- |
| Local deployment | Image size, port conflicts, required overrides, startup friction, and health checks. | override-required |
| Authentication | First local account flow, session reuse, and whether screenshots can be sanitized. | session-reused-sanitized |
| Fleet inventory | Collector list fields, stable identity, version, OS, started time, and health status. | lab-proven-single-integrated-collector |
| Collector detail | Detail fields, show-more data, component health, effective config, and custom config editor. | partial-ui-loading-api-rich |
| Remote config safety | YAML validation, non-map rejection, save behavior, timeout behavior, and rollback affordance. | api-guardrail-proven |
| TLS operations | Development TLS, mTLS production mode, certificate extraction, TLS min-version offer, and reconnect behavior. | partial-offer-timeout |
| API/UI alignment | Whether API data and UI panels expose the same effective/custom config information. | gap-api-more-complete-than-ui |
| Exit friction | Endpoint replacement, certificate replacement, config export, and lifecycle ownership outside OpenLit. | to-document-after-external-collector |
