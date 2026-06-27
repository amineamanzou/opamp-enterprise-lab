# Exit Drill, Secrets, And Control-Plane Outage Runbook

This runbook closes the fleet-management study with three operational questions:

- Can an OTel-only Fleet or Bindplane collector be moved to the custom OpAMP Go control plane without rewriting the whole fleet?
- Which secrets become production risks for distribution, rotation, revocation, and audit?
- What happens when the control plane is unavailable while the data path must keep exporting logs?

Scope constraints:

- Do not test Bindplane Enterprise or bring-your-own-collector features.
- Do not add new scale paliers.
- Keep Elastic Agent out of the Fleet OTel-only path.
- Prefer documented and reversible control-plane interruption over destructive credential changes.

## Evidence Hygiene

Commit only sanitized evidence. Redact public addresses, raw tokens, tenant identifiers, emails, private hostnames, and account-specific screenshots.

Keep raw command output outside the repository until redacted. Use placeholders such as `<redacted-token>`, `<redacted-host>`, `<redacted-tenant>`, and `<redacted-email>`.

## Baseline Captures

Before changing a collector, capture:

- active collector process and service state;
- current config file path and redacted effective config;
- control-plane UI or API status;
- Elastic log-ingest query result for the synthetic log dataset;
- exact stop/start commands;
- current Git branch and commit.

## Exit Fleet OTel-Only To OpAMP Go

1. Capture Fleet baseline from the prior OTel-only collector run.
2. Stop the Fleet-managed collector process or service.
3. Deploy the lab OCB collector plus upstream supervisor pointed at the OpAMP Go server.
4. Reuse the same synthetic log source and Elastic OTLP destination.
5. Capture OpAMP inventory, events, effective config, and Elastic log-ingest evidence.
6. Reopen Fleet and record whether the old collector row remains stale or disappears.

Measure:

- time from first stop command to OpAMP-visible healthy collector;
- files and config keys changed;
- secrets replaced;
- data-path downtime;
- stale Fleet state;
- rollback path.

## Exit Bindplane BDOT To OpAMP Go

1. Capture Bindplane baseline for the connected BDOT collector.
2. Stop the BDOT service.
3. Deploy the lab OCB collector plus upstream supervisor pointed at the OpAMP Go server.
4. Reuse the same synthetic log source. Reuse Elastic OTLP only if the Bindplane path had a finalized destination.
5. Capture OpAMP inventory, events, effective config, and Elastic log-ingest evidence when available.
6. Reopen Bindplane and record stale collector state.

Measure:

- replacement binary and service ownership;
- Bindplane-specific source or destination features that are lost;
- config export or reconstruction work;
- stale Bindplane state;
- rollback path to BDOT.

## Secrets Study

Catalog these secrets:

- `OPAMP_AUTH_TOKEN`
- `ELASTIC_API_KEY`
- Fleet OpAMP auth header
- Bindplane secret key
- Bindplane API key
- SOPS age identity and encrypted env files
- Kubernetes Secret objects

For each secret, record:

- creation path;
- storage location;
- distribution mechanism;
- rotation steps;
- revocation steps;
- blast radius;
- UI or API visibility;
- audit evidence.

Only test OpAMP Go token rotation if the lab can do it without breaking the exit drills. For Fleet and Bindplane, document the UI or API rotation path when visible; do not force a destructive rotation.

## Control-Plane Outage

### OpAMP Go

Stop the OpAMP Go server while the collector continues exporting to Elastic. Measure whether logs continue, how collector logs report the outage, and how long inventory/events take to recover after restart.

### Fleet OTel-Only

Simulate loss of Fleet OpAMP connectivity while preserving the Elastic OTLP exporter. Measure log continuity, collector health, and Fleet stale/offline status.

### Bindplane

If Bindplane OpAMP can be interrupted without breaking Elastic ingest, capture the same outage/recovery evidence. If the Elastic destination is not finalized, document Bindplane as a control-plane-only outage with no data-path conclusion.

## Final Lab State

End every run by documenting:

- services left active;
- services left stopped;
- active collector binary and version;
- active control-plane endpoint;
- known stale rows in Fleet or Bindplane;
- rollback command or manual rollback procedure.
