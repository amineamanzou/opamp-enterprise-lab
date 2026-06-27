# Source Baseline

Access date: 2026-06-19

This run is OTel-only. Do not install, enroll, or test Elastic Agent.

## Official Elastic Sources

| Source | Dated finding | Evidence status |
| --- | --- | --- |
| https://www.elastic.co/docs/reference/fleet/monitor-otel-collectors | Fleet can centrally monitor EDOT and third-party OpenTelemetry Collectors through OpAMP. Fleet Server acts as the OpAMP server. Fleet does not deploy OTel Collectors; operators install/run them separately and configure the OpAMP extension. Supported upstream/community collectors start at version 0.103.0; EDOT starts at 9.2. | source-only |
| https://www.elastic.co/docs/reference/fleet/add-otel-collector | The Fleet UI has an Add collector flow for `Collector (OpAMP)`. The flow asks for group/display/service metadata and generates an OTel Collector YAML with OpAMP, OTLP receiver, Elasticsearch exporter/pipelines, and internal telemetry. Existing collectors should merge the generated blocks instead of replacing the whole working config. | source-only |
| https://www.elastic.co/docs/reference/fleet/view-otel-collectors | OTel Collectors appear in the Fleet Agents list alongside Elastic Agents. Fleet exposes status, CPU/memory when internal telemetry is enabled, host/tags/version/last activity, capabilities, component health, and effective configuration. OTel Collectors use managed policies that cannot be modified and do not appear in the Agent policies tab. | source-only |

## Test Implications

- This scenario must not use Elastic Agent enrollment; the target process is `otelcol-contrib`.
- Fleet is expected to provide visibility and generated configuration, not deployment, restart, upgrade, or uninstall lifecycle for OTel collectors.
- Remote config mutability is expected to be limited because the docs describe managed, non-modifiable policies for OTel Collectors; verify in UI before marking as lab-proven.
- Switching to another OpAMP server should mainly require replacing the OpAMP endpoint/auth and removing Elastic-specific exporter/internal telemetry blocks, but dashboard/data stream coupling must be measured in the lab.
