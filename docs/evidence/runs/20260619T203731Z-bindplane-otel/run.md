# Bindplane OpenTelemetry Evidence Run

This run evaluates Bindplane as a fleet-management control plane for OpenTelemetry collectors only.

Hard rule: do not install or enroll Elastic Agent.

## Summary

- Branch: `scenario/bindplane-otel-experience`
- Collector: upstream `otelcol-contrib` preferred; BDOT only if required
- Elastic Agent used: no
- Bindplane role: OTel collector onboarding, config, health, lifecycle, and scale-management candidate

## Notes

## Result Summary

- Browser-use account session opened `https://app.bindplane.com/` and landed on the Agents page.
- First-collector onboarding is product-led and BDOT-first: the Install Agent wizard defaulted to `BDOT 1.x (Stable)`, not upstream `otelcol-contrib`.
- Linux install command used OpAMP endpoint `wss://app.bindplane.com/v1/opamp`, a secret key, and BDOT version `1.101.2`.
- The install script failed silently in the first SSH attempts when `TERM` was not set; setting `TERM=xterm` allowed the script to pass prerequisites and install.
- The VM service `observiq-otel-collector.service` started successfully and Bindplane showed `opamp-poc-agent` as `Connected`, type `BDOT 1.x (Stable)`, version `v1.101.2`, OS `Ubuntu 24.04`.
- Agent detail exposes useful inventory fields: status, type, version, host name, platform, OS, Agent ID, remote address, MAC address, fleet, configuration, labels, health, and configuration tabs.
- Health tab initially showed CPU Usage and Memory Usage panels, but both were `No Data` during the first short observation window.
- Restart test passed: systemd restart returned active and Bindplane still showed `Connected`.
- Disconnect/reconnect test passed: after stopping BDOT for 25s, Bindplane showed `Disconnected`; after service start, it returned to `Connected`.
- Configuration builder is UI/product-model driven: configuration details -> sources -> destination. A `File` source for `/var/log/opamp-poc/synthetic.log` was created successfully in the draft.
- Destination friction: preset `Elasticsearch (OTLP)` expects APM Server URL plus Secret Token. The lab currently uses Elastic OTLP endpoint plus `ApiKey`, so this preset is not directly compatible with the existing backend secret model.
- Destination fallback: `Custom` destination allows inserting a supported OpenTelemetry exporter YAML, which is likely the portable path for the lab, but it was not saved/deployed in this run to avoid placing Elastic secrets into UI captures before the redaction path is automated.
- Custom OCB attempt: the lab `otelcol-logs-opamp` distro was deployed as a separate systemd service with the OpenTelemetry OpAMP extension, WebSocket endpoint `wss://app.bindplane.com/v1/opamp`, `Authorization: Secret-Key <redacted>`, `X-Bindplane-Labels`, and a valid ULID `instance_uid`.
- Custom OCB result: the collector process started and read the synthetic log file, but Bindplane rejected the OpAMP WebSocket handshake with `403 Forbidden` / `websocket: bad handshake`; the UI continued to show only the BDOT agent.
- Source baseline for this result: Bindplane's "Connect OpenTelemetry Collectors Using the OpAMP Extension" documentation says other OTel distributions require Enterprise licensing, do not accept remote configuration through the standard OpAMP extension, do not show "Choose Another Configuration", do not show "View Recent Telemetry", and do not populate OS/MAC fields like the Bindplane Collector.
- No scale paliers were executed yet; the current run proves single-agent onboarding and basic lifecycle visibility.

## Verdict

Replaceability by OpAMP: partial.

Bindplane provides a much stronger managed UI workflow than Elastic Fleet OTel-only for collector onboarding and configuration modeling, but the observed path is not a neutral upstream collector path. The default runtime is BDOT, installation is product-specific, and configuration is represented through Bindplane source/destination resources. Exiting to OpAMP is plausible only if the team can export or reconstruct the generated OTel YAML, replace the OpAMP endpoint/secret, and own lifecycle/rollout semantics outside Bindplane.

With the current account/plan, using the lab's own OCB distro is blocked at the OpAMP handshake. Even if enabled through Enterprise/BYOC, Bindplane documents that the standard OpAMP extension path is visibility-only and cannot receive remote configuration.

## Open Items

- Complete destination setup through `Custom` OTLP exporter YAML using sanitized secret handling.
- Assign and roll out the configuration to the connected agent.
- Validate ingest in Elastic.
- Test bad config validation and rollback.
- Test upgrade/downgrade controls exposed by Bindplane.
- Run paliers `10`, `50`, `100` before attempting larger scale.
