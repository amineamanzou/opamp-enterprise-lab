# Exit Drill, Secrets, And Control-Plane Outage Run

## Summary

This run executed the reversible part of the exit drill on 2026-06-19 UTC.

The active host collector before the drill was Bindplane BDOT through `observiq-otel-collector.service`. The prior Fleet OTel-only collector was already stopped, so Fleet exit was documented from previous evidence plus current stale Fleet UI state rather than rerun.

The custom OpAMP Go server initially failed to start because the previous `opamp-server-py` server container owned the OpAMP port. Stopping only that server container freed the port; the `opamp-server-py` UI container was left running.

## Final Conclusion

| Solution | Exit status | Migration effort | Secrets risk | Outage behavior | Scale operations risk |
| --- | --- | --- | --- | --- | --- |
| Fleet OTel-only | Partially immediate | Medium | High around Fleet auth and Elastic API key ownership | Current Fleet rows stayed offline/stale; data-path continuity not rerun because Fleet collector was already stopped | Medium to high because lifecycle remains external |
| Bindplane BDOT | Partial but mechanically executable | Medium to high | High around Bindplane secret key, API key, and destination credentials | Bindplane row became disconnected after BDOT stop; no Bindplane-origin Elastic continuity baseline because BDOT was on minimal `nop` config | High if BDOT and plan limits remain mandatory |
| Custom OpAMP Go | Immediate target for this host | Low migration target, high product ownership | High unless token rotation and audit are productized | Data path continued during OpAMP Go outage; inventory refreshed about 25 seconds after restart | High operational ownership at fleet scale |

## Measurements

| Measurement | Value |
| --- | --- |
| Bindplane BDOT stop time | 2026-06-19T22:37:09Z |
| OpAMP supervisor active time | 2026-06-19T22:37:09Z |
| Time-to-exit, service switch only | less than 1 second to active systemd state |
| OpAMP Go start blocker | `opamp-server-py-server` container occupied the OpAMP port |
| OpAMP Go outage start | 2026-06-19T22:38:47Z |
| OpAMP Go restart | 2026-06-19T22:40:04Z |
| Host-agent inventory recovery | 2026-06-19T22:40:29Z |
| Recovery after restart | about 25 seconds |
| Elastic during outage | 1,898 logs/metrics in `now-2m` for host/supervisor services |
| Elastic after recovery | 1,889 logs/metrics in `now-2m` for host/supervisor services |
| OpAMP inventory scale residue | 10,022 stored agents from prior scale evidence; active connection count API reported zero |
| Invalid OpAMP token drill | Agent still connected and inventory refreshed after replacing `OPAMP_AUTH_TOKEN` with an invalid placeholder |
| Infrastructure destroy | Terraform destroyed 6 resources; Hetzner API returned 0 project lab servers and 0 project lab firewalls |

## Lab State

| Service | Final state | Notes |
| --- | --- | --- |
| Fleet OTel-only collector | stopped | `otelcol-fleet-opamp.service` inactive before and after this run. |
| Bindplane BDOT collector | stopped | `observiq-otel-collector.service` inactive after exit. |
| OpAMP Go server | active | `opamp-poc-server.service` active after recovery test. |
| OpAMP supervisor collector | active | `opampsupervisor-logs.service` active and supervising `otelcol-logs-opamp`. |
| Elastic ingest | verified | Logs and metrics continued during OpAMP outage. |
| opamp-server-py server container | stopped | Stopped because it held the OpAMP port required by OpAMP Go. |
| opamp-server-py UI container | active | Left running; server backend is stopped. |
| Hetzner lab infra | destroyed | Destroyed after the final secrets drill; Terraform state list is empty. |

## Sanitization

Use placeholders only:

- `<redacted-token>`
- `<redacted-host>`
- `<redacted-tenant>`
- `<redacted-email>`
