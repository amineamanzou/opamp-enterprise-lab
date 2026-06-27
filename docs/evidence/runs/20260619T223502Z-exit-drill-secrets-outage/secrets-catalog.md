# Secrets Catalog

| Secret | Creation | Storage | Distribution | Rotation | Revocation | Blast radius | UI/API visibility | Auditability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `OPAMP_AUTH_TOKEN` | Lab env or secret render path | Local secret env, optionally SOPS | Service env or rendered config | Replace token and restart/reload server plus agents | Remove old token from server allow-list or env | All custom OpAMP agents using token | Custom API/UI only if implemented | Low until explicit audit events exist |
| `ELASTIC_API_KEY` | Elastic Cloud UI/API | SOPS encrypted env and service env | Rendered collector config or env expansion | Create new key, update collectors, revoke old key | Delete/revoke key in Elastic | Elastic ingest for assigned privileges | Elastic UI/API | High in Elastic, lower in local deployment history |
| Fleet OpAMP auth header | Fleet add-collector flow | Collector config/service env | Generated config or automation | Generate replacement in Fleet flow if supported | Invalidate old enrollment/auth material if supported | Fleet OpAMP connection for affected collectors | Fleet UI/API | Product-dependent |
| Bindplane secret key | Bindplane install/onboarding flow | Service env or install script output | Generated BDOT command/config | Rotate from Bindplane UI/API if available | Revoke old key in Bindplane | Bindplane collector enrollment/config access | Bindplane UI/API | Product-dependent |
| Bindplane API key | Bindplane account/API key flow | Operator secret store | CLI/API automation env | Create replacement key and update automation | Delete old API key | Bindplane automation scope | Bindplane UI/API | Product-dependent |
| SOPS age identity | Operator workstation or CI secret | Local key file or CI secret | Decryption step only | Add new recipient, re-encrypt, retire old identity | Remove old recipient and key access | All encrypted env files for recipient | Git diff shows recipients, not private key use | Medium via Git history and CI logs |
| Kubernetes Secret objects | `kubectl`, Helm, or manifests | Kubernetes API/etcd | Mounted env or volume | Apply new Secret and restart/reload workloads | Delete old Secret and remove mounts | Namespace or cluster depending RBAC | Kubernetes API | Medium to high if audit logs enabled |

## Rotation Test

The final destructive drill replaced the host agent's `OPAMP_AUTH_TOKEN` with `exit-drill-invalid-token` and restarted `opampsupervisor-logs.service`.

Result: the supervisor stayed active, local collector health returned within five seconds, and the OpAMP Go host-agent inventory timestamp refreshed after the restart. The server accepted the invalid token because the current Go implementation does not enforce the OpAMP `Authorization` header.

Production conclusion: `OPAMP_AUTH_TOKEN` is currently configuration ceremony, not an access-control boundary. Before production use, OpAMP Go needs server-side bearer validation, token segmentation, overlapping token rotation, revocation, and auditable auth failures.

Fleet and Bindplane destructive rotations were not performed. They remain product UI/API procedures to document without changing account-level credentials in this lab.
