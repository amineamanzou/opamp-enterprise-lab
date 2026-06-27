# Vanilla OpAMP UI Evidence Run

- Created at: 2026-06-18T22:18:56Z
- Scenario: custom Go OpAMP vanilla server
- Evidence label: custom-go-opamp
- UI base URL: `http://127.0.0.1:54321`

## Screenshots To Attach

- `screenshots/vanilla-root.png`: root Agents page.
- `screenshots/vanilla-agent-detail.png`: agent detail page after redaction.

## API/HTML Artifacts

- `artifacts/root.html`
- `artifacts/inventory.json`
- `artifacts/connections.json`

## Feature Notes

- Implemented: agent list, agent detail, effective config display, remote config form, links to JSON inventory/connections.
- Not implemented in vanilla POC V1: client certificate rotation, OpAMP connection settings offers, and custom messages from the upstream example UI.

## Redaction Rules

- Remove public IP addresses, private hostnames, tokens, Cloud IDs, kubeconfig content, and tenant identifiers before publishing screenshots or copied logs.
- Keep product versions, scenario labels, command counts, anonymized host roles, and relative timestamps.
