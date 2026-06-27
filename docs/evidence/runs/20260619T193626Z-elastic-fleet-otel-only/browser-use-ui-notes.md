# Browser-Use UI Notes

Use the local Chrome profile and capture only sanitized state.

```sh
browser-use --headed --profile Default open "<kibana-url>/app/fleet"
browser-use --headed --profile Default state > artifacts/browser-use/fleet-home.state.txt
browser-use --headed --profile Default screenshot
```

Required pages:

- Fleet agents list filtered to OpenTelemetry collectors.
- Add Collector / OpAMP flow.
- Generated collector configuration page.
- Collector detail page.
- Any status, health, effective config, or error panels.

Capture:

- number of UI actions to find the OTel collector flow;
- fields required before Fleet can generate config;
- whether the UI clearly says Fleet does not deploy the collector;
- whether remote config is editable from Fleet for OTel collectors;
- labels for Healthy, Unhealthy, Offline, and config errors;
- friction caused by Elastic-specific names, tokens, or integrations.

## Observations

- Fleet Agents initially showed zero agents and an Add menu with two entries: `Ajouter un agent` and `Collecteur (OpAMP)`.
- The Add Collector flyout asks for collector group display name, group slug, service name, collector display name, optional config name/description, tags, and environment.
- The generated config uses OpAMP `server.http`, not WebSocket. This required a scenario template correction.
- Fleet creates or accepts an API key in the flyout. The generated key was treated as secret evidence and redacted.
- The flyout confirmed the first collector connection with `1 collector has been connected`.
- The Agents list showed `otelcol-contrib`, status `Sain`, version `0.151.0`, and CPU/memory `N/A`.
- The detail page exposed capabilities `ReportsAvailableComponents`, `ReportsEffectiveConfig`, `ReportsHealth`, and `ReportsStatus`.
- Effective configuration was visible from the detail page.
- No editable policy workflow was visible for the OTel collector; the Agent policy field was empty/managed.
- Missing `instance_uid` caused duplicate stale Fleet rows after restart.
- Scale attempts showed operational friction before UI scale could be measured: OTel requires a valid pipeline, default collector telemetry port conflicts on multi-process hosts, and reused generated OpAMP credentials returned `401`.
