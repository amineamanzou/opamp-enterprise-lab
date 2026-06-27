# Exit Drill, Secrets, And Control-Plane Outage Run

## Summary

This run is a redacted operational drill package. The drill moves from previously captured Fleet OTel-only and Bindplane BDOT baselines toward the custom OpAMP Go path, then records secrets and outage risk.

## Final Conclusion

| Solution | Exit status | Migration effort | Secrets risk | Outage behavior | Scale operations risk |
| --- | --- | --- | --- | --- | --- |
| Fleet OTel-only | Partially immediate | Medium | High around Fleet auth and Elastic API key ownership | Data path should continue when only OpAMP is lost; verify per collector config | Medium to high because lifecycle remains external |
| Bindplane BDOT | Partial | Medium to high | High around Bindplane secret key, API key, and destination credentials | Control-plane-only conclusion until Elastic destination is finalized | High if BDOT and plan limits remain mandatory |
| Custom OpAMP Go | Immediate target | Low migration target, high product ownership | High unless token rotation and audit are productized | Expected to preserve data path during server outage | High operational ownership at fleet scale |

## Lab State

| Service | Final state | Notes |
| --- | --- | --- |
| Fleet OTel-only collector | documented-stop-or-active | Fill after live drill. |
| Bindplane BDOT collector | documented-stop-or-active | Fill after live drill. |
| OpAMP Go server | documented-active-or-stopped | Fill after live drill. |
| OpAMP supervisor collector | documented-active-or-stopped | Fill after live drill. |
| Elastic ingest | documented-verified-or-not-run | Fill after live drill. |

## Sanitization

Use placeholders only:

- `<redacted-token>`
- `<redacted-host>`
- `<redacted-tenant>`
- `<redacted-email>`
