# OpAMP Operations Experience Evidence Run

- Created at: 2026-06-18T23:33:04Z
- Scenario: vanilla custom Go OpAMP server with opampsupervisor-managed VM collector
- Evidence label: custom-go-opamp-ops
- Branch: main
- Commit: 43fbbccccc62448bbc763bd3d58af80fe8dde21f

## Operations Under Test

| Operation | Target | Expected evidence |
| --- | --- | --- |
| Remote config update | VM supervisor ring | desired hash, APPLIED status, ingest phase marker, effective config visibility note |
| Bad config and recovery | VM supervisor ring | FAILED status, operator rollback, APPLIED after recovery |
| Restart command | VM supervisor agent | pending command, disconnect/reconnect, health returns OK |
| Downgrade/upgrade | VM collector binary | version visible changes, ingest continuity notes |
| Pre-sweep volumetry | VM collector path | 1k/5k/10k generated count, CPU/RSS, backpressure notes |

## Friction and Corrections

| Issue | Cause | Correction | Comparative impact |
| --- | --- | --- | --- |
| Sparse capabilities on direct extension agents | Direct collector extension did not expose usable version, hostname, health, config status, or hash in the vanilla server inventory | Use `opampsupervisor` for the VM host-agent day-2 scenario | Adds setup work but makes operations evidence measurable |
| Server restart command missing | Vanilla custom Go server had no restart API/UI and did not send `ServerToAgentCommand` | Added pending restart state, API/UI actions, and tests in `server.go` | Counts as custom maintenance effort for vanilla |
| Supervisor config rejected `agent.access_dirs` | `opampsupervisor` 0.151.0 rejected the key at startup | Removed the key from the deployed supervisor config | Documented compatibility friction |
| Versioned deploy override brittle | Environment override of the OCB binary path was unreliable in escalated Ansible runs | Added explicit `task ansible:collector:supervisor:version VERSION=...` using an Ansible extra var | Makes downgrade/upgrade repeatable |
| Effective config body incomplete | Server path has desired hash/status, but no full effective config body for supervisor-managed agent | Treat as a vanilla visibility limitation and capture hashes/status instead | Penalizes inventory/config observability |

## Redactions

- Redact public IPs, tokens, Cloud IDs, kubeconfig content, tenant identifiers, and non-synthetic hostnames before publishing.
- Keep anonymized roles, versions, hashes, relative timings, command counts, and status transitions.
