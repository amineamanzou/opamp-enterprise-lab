# OpAMP Cloud Evidence Run

- Created at: 2026-06-18T19:56:49Z
- Backend: Elastic Cloud trial
- Lab: Hetzner Cloud
- Scope: logs only

## Evidence To Attach

- Terraform outputs redacted to host roles and public IPs.
- Ansible run logs for bootstrap, OpAMP server, collectors, and synthetic logs.
- OpAMP inventory snapshots from `GET /v1/agents` and `GET /v1/opamp/connections`.
- Remote config assignment request and resulting remote config status.
- Elastic Discover or API proof that lab logs arrived.
- Collector binary checksums and measurement CSVs.

## Redaction Rules

- Remove API keys, bearer tokens, private keys, hostnames tied to real clients, and exact private network topology.
- Keep product versions, timestamps, scenario names, and anonymized host roles.
