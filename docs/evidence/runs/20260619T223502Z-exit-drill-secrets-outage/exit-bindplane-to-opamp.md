# Exit Bindplane BDOT To OpAMP Go

| Measurement | Result | Evidence |
| --- | --- | --- |
| Baseline collector visible in Bindplane | observed | UI showed one BDOT 1.x Stable agent before the switch in prior evidence; current post-stop UI shows the same agent disconnected. |
| Baseline Elastic synthetic logs visible | not applicable | Active BDOT config was Bindplane's minimal `nop` config, so there was no Bindplane-origin Elastic data-path baseline to preserve. |
| Stop command | done | `systemctl stop observiq-otel-collector.service`. |
| OCB supervisor deployed | done | Unit already installed; `systemctl start opampsupervisor-logs.service` made it active immediately. |
| OpAMP inventory visible | done | Host-agent row updated with version `0.151.0`, health `StatusOK`, remote config `APPLIED`. |
| OpAMP events visible | partial | Server event API retained generic recent events; connection accounting reported zero active connections despite host-agent inventory refresh. |
| Elastic logs visible after exit | done | Post-exit Elastic query found host logs, host metrics, collector logs, and collector metrics. |
| Data-path downtime | not measurable from BDOT baseline | BDOT source path had no Elastic exporter; the replacement collector produced Elastic telemetry after start. |
| Stale Bindplane row | observed | Bindplane Agents page showed `opamp-poc-agent` as `Disconnected`, type `BDOT 1.x (Stable)`, version `v1.101.2`. |

## Expected Changes

| Area | Bindplane BDOT | OpAMP Go |
| --- | --- | --- |
| Collector binary | BDOT | Lab OCB distro |
| OpAMP endpoint | Bindplane WebSocket endpoint | Custom OpAMP Go endpoint |
| Auth | Bindplane secret key | `OPAMP_AUTH_TOKEN` |
| Config model | Bindplane source/destination graph | OTel YAML assigned by lab server |
| Rollout | Product workflow when configured | Lab-owned rollout and validation |

## Interim Verdict

Exit is partial but mechanically executable. Replacing BDOT with the supervisor-managed OCB collector took less than one second at the systemd service-state level, but it did not preserve a Bindplane-origin data path because the BDOT agent was running a minimal `nop` configuration. Bindplane retained the old BDOT row as disconnected, so stale inventory cleanup remains a product/API task.
