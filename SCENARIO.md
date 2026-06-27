# Python OpAMP Server Scenario

This branch is the guide branch for the `opamp-server-py` comparison notes and
the custom OpAMP feature-gap analysis.

## Run

```sh
task ci:local
task evidence:vanilla-ui
task opamp:test
```

Then read `docs/study/vanilla-opamp-lab-notes.md` and compare the feature gaps
against `lab/opamp-server/`.

## Evidence Goal

Capture the product work required around a protocol-level OpAMP server:
persistence, stable identity, remote config status, validation, UI/API support,
restart/lifecycle commands, stale cleanup, and auditability.
