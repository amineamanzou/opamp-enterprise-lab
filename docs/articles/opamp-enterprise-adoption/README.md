# OpAMP Enterprise Adoption Article Series

This directory coordinates a five-part bilingual article series answering:

> Is OpAMP ready for large enterprises, or is it still a protocol for expert teams and vendors to productize?

The series is grounded in the public POC evidence under `docs/study/` and `docs/evidence/`. It should stay vendor-neutral: compare tested management paths, operational responsibilities, and exit friction without turning the series into a global vendor ranking.

## Publication Order

| Part | Working title | English draft | French draft |
| --- | --- | --- | --- |
| 1 | The enterprise-readiness question | `part-01-question-methodology.en.md` | `part-01-question-methodology.fr.md` |
| 2 | Building the open OpAMP path | `part-02-building-open-opamp.en.md` | `part-02-building-open-opamp.fr.md` |
| 3 | Managed control planes as benchmarks | `part-03-managed-benchmarks.en.md` | `part-03-managed-benchmarks.fr.md` |
| 4 | Exit drill, secrets, and outages | `part-04-exit-secrets-outage.en.md` | `part-04-exit-secrets-outage.fr.md` |
| 5 | Adoption guidance for large enterprises | `part-05-enterprise-verdict.en.md` | `part-05-enterprise-verdict.fr.md` |

Use `claim-ledger.md` as the shared source of approved claims, labels, sources, allowed parts, and caveats.

## Evidence Label Rules

- `lab-proven`: reproduced in this lab with retained public-safe evidence such as sanitized configs, commands, screenshots, logs, metrics, or API summaries.
- `source-only`: supported by public documentation or project-owned source code, but not reproduced in this lab.
- `not-tested`: deliberately outside the current lab phase or left as an empty measurement row.
- `blocked`: intended for the lab but blocked by access, licensing, scale limits, missing features, or reproducibility gaps.

Do not upgrade a claim to `lab-proven` unless another engineer can inspect or replay the evidence from committed public POC materials.

## Lab Status

The final exit-drill run ended with infrastructure teardown. The Hetzner lab was destroyed, Terraform state was empty, and the follow-up provider checks showed zero remaining lab servers and firewalls. No new infrastructure runs are expected for this article series. Treat any missing measurements as `not-tested` or `blocked`, not as implied positive evidence.

## Visual Asset Policy

Prefer sanitized screenshots under the evidence package. Raw screenshots may only be used after visual review confirms that they do not expose account chrome, project identifiers, URLs, user details, hostnames, tokens, enrollment material, or other sensitive values. If the visual cannot be sanitized confidently, cite the API summary or written evidence instead.
