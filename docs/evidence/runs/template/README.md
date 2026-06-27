# Evidence Run Template

Copy this directory for each reproducible run and rename it with an ISO date plus a short slug, for example `2026-06-18-local-ci-smoke`.

Each evidence run should include:

- `run.md` with commands, environment, result summary, and follow-up notes.
- Relevant logs or excerpts with secrets, tokens, hostnames, personal names, and public IP addresses removed.
- Links or relative paths to source inputs used for the run.
- A short explanation for any skipped task or non-blocking failure.

Do not commit raw cloud credentials, inventory secrets, private hostnames, external customer data, or complete terminal captures that may include local machine paths outside this repository.
