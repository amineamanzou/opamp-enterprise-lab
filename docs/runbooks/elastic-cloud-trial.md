# Elastic Cloud Trial Runbook

Elastic Cloud is the common log backend for every lab scenario. It is not treated as the target management layer; Elastic Fleet remains a separate benchmark scenario.

## Create The Trial Backend

1. Create an Elastic Cloud trial deployment.
2. Enable OTLP ingest for the deployment.
3. Create an API key scoped to ingest logs for this POC.
4. Store the values with the repo SOPS workflow:

```sh
mkdir -p secrets
cp secrets.encrypted/elastic-cloud.env.example secrets/elastic-cloud.env
$EDITOR secrets/elastic-cloud.env
task secrets:encrypt:elastic
task secrets:render
source scripts/load-cloud-secrets.sh
```

Do not commit deployment IDs, API keys, enrollment tokens, exact tenant names, or screenshots that reveal organization identifiers.

The plaintext local file is `secrets/elastic-cloud.env` and is gitignored. If you encrypt it with SOPS, keep `secrets.encrypted/elastic-cloud.sops.yaml` local; `*.sops.yaml` files are ignored and should not be committed.

Elastic secrets only contain Elastic values:

```sh
ELASTIC_OTLP_ENDPOINT=https://...
ELASTIC_API_KEY=...
ELASTICSEARCH_URL=https://... # optional when derivable from OTLP endpoint
KIBANA_URL=https://...
KIBANA_SPACE=default
```

## Validate Local Variables

```sh
task elastic:verify
```

Set `ELASTIC_PROBE=1` only when you want the script to make a live network request:

```sh
ELASTIC_PROBE=1 task elastic:verify
```

## Configure Elastic Visibility As Code

The regulated observability lab can install Elastic assets through API calls:

```sh
task elastic:visibility:check
task elastic:visibility:setup
task elastic:opamp:snapshot
task elastic:visibility:verify
```

This creates OpAMP control-plane data stream templates, Kibana data views,
starter dashboards/searches, and in-app Elastic Security detection rules. It
also indexes snapshots from the vanilla OpAMP server APIs:

- `/v1/inventory` to `logs-opamp.inventory-lab`
- `/v1/opamp/connections` to `logs-opamp.connections-lab`
- `/v1/stats` to `metrics-opamp.server-lab`

The setup reuses `ELASTIC_API_KEY`. If the key was created only for OTLP ingest,
`elastic:visibility:check` or `elastic:visibility:setup` can fail with `403`.
In that case, create a temporary lab API key with privileges to manage index
templates, create documents in `logs-opamp.*-*` and `metrics-opamp.*-*`, import
Kibana saved objects, and manage Elastic Security detection rules or Kibana
alerting rules. Store it in `secrets/elastic-cloud.env` as `ELASTIC_API_KEY`,
then rerun `task secrets:encrypt:elastic` if the value should be versioned
through SOPS.

Elastic Serverless Observability projects can expose Kibana alerting but not the
Security detection engine. The setup detects this and installs equivalent
in-app `.index-threshold` rules.

## Collector Configuration

The lab configs export logs with `otlphttp/elastic` and the header:

```yaml
Authorization: "ApiKey ${env:ELASTIC_API_KEY}"
```

Use the same backend variables for:

- OCB logs-only collector.
- OCB logs collector with OpAMP extension.
- EDOT Collector.
- Upstream `otelcol-contrib`.
- Elastic Agent / Fleet baseline.

## Evidence To Capture

For each scenario, capture:

- collector distribution and version;
- collector config with secrets redacted;
- OpAMP inventory and remote config status when applicable;
- Elastic proof of ingestion with index/data stream name redacted if needed;
- RSS, CPU, startup time, image size, binary size, and loss/backpressure notes.
