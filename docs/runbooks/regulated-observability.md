# Regulated Observability Runbook

This runbook extends the OpAMP lab telemetry sent to Elastic for a regulated/SIEM-oriented scenario.

## Signals

- Host infra logs: `data_stream.dataset=infra.host`
- Host security logs: `data_stream.dataset=security.host`
- Collector logs: `data_stream.dataset=observability.collector`
- Kubernetes pod infra logs: `data_stream.dataset=infra.kubernetes`
- Kubernetes audit logs: `data_stream.dataset=security.kubernetes_audit`
- Host metrics: `data_stream.dataset=hostmetricsreceiver`
- Kubernetes kubelet metrics: `data_stream.dataset=kubeletstatsreceiver`
- Kubernetes state metrics: `data_stream.dataset=k8sclusterreceiver`
- Collector self-metrics: `data_stream.dataset=metrics.collector`

Kubernetes audit policy is Metadata-level by default. This is intentional: it captures who did what to which resource without collecting full request/response payloads.

## Deploy

```sh
task ocb:build
task collector:env
./scripts/opamp-assign-config.sh dev lab/configs/opamp-regulated/noop-remote-config.yaml
task ansible:collector:supervisor
task ansible:k3s:audit
task k8s:logs:install
```

The no-op OpAMP config reset is intentional. The previous day-2 operations scenario
can leave a ring-level remote config that references the older single `logs`
pipeline and base `resource`/`attributes` processors. If that stale config is
still assigned, `opampsupervisor` merges it with the regulated multi-pipeline
collector config and the child collector refuses to start.

The Kubernetes DaemonSet collector runs as root in this lab scenario because
k3s writes `/var/lib/rancher/k3s/server/logs/audit.log` as a root-only file.
The container drops Linux capabilities and disables privilege escalation; the
remaining elevated permission is the file ownership needed to read host audit
logs.

Generate audit events:

```sh
KUBECONFIG=secrets/kubeconfig-opamp-poc.yaml kubectl get pods -A
KUBECONFIG=secrets/kubeconfig-opamp-poc.yaml kubectl -n opamp-logs-poc get configmap
```

## Verify Elastic

```sh
task elastic:regulated:verify
```

Default query window is `now-30m`. Override with:

```sh
REGULATED_VERIFY_WINDOW=now-2h task elastic:regulated:verify
```

## Elastic Visibility As Code

Install and verify Elastic-side lab assets through the API:

```sh
task elastic:visibility:check
task elastic:visibility:setup
task elastic:opamp:snapshot
task elastic:visibility:verify
```

The setup adds:

- OpAMP control-plane data streams for inventory, connections, and server stats.
- Kibana data views for lab logs, metrics, and OpAMP control-plane snapshots.
- Starter dashboards/searches for inventory and SIEM review, plus the panel
  catalog in `lab/configs/elastic/opamp-visibility-queries.json`.
- In-app Elastic Security detection rules without external connectors when the
  Security detection API is available. Elastic Serverless Observability projects
  can return `404` for that API; in that case the setup installs equivalent
  Kibana `.index-threshold` alerting rules.

`task elastic:opamp:snapshot` reads `OPAMP_ADMIN_URL` or
`OPAMP_VANILLA_UI_URL`, defaulting to `http://127.0.0.1:4321`.

## Elastic Infra Inventory Enrichment

The upstream Elastic onboarding flow adds `onboarding.id` to OTel resources. The
lab keeps the upstream Collector distribution, but mirrors the important
resource attributes:

- all host and Kubernetes pipelines add `onboarding.id`;
- host metrics add `host.id`, `host.name`, and `service.instance.id`;
- Kubernetes logs and metrics add `k8s.cluster.name`, `k8s.node.name`,
  `orchestrator.type=kubernetes`, `host.id`, and `service.instance.id`;
- the Kubernetes DaemonSet enables the upstream `kubeletstats` receiver with
  `node`, `pod`, and `container` metric groups so Elastic receives pod/container
  metrics, not only pod logs.

The lab default onboarding id is stored as `ELASTIC_ONBOARDING_ID` and defaults
to the placeholder value `00000000-0000-0000-0000-000000000000`.

## Kibana

Import the starter saved objects:

```sh
KIBANA_URL=https://<kibana-host> \
KIBANA_API_KEY=<api-key> \
task kibana:regulated:setup
```

If Kibana env vars are not set, the task prints the NDJSON path for manual import:

```text
lab/configs/elastic/regulated-observability-kibana.ndjson
```

Use `lab/configs/elastic/regulated-observability-queries.json` as the panel/query catalog.

## Evidence

```sh
task evidence:regulated-observability
```

This copies the collector, Kubernetes, Kibana, query, and Elastic verification artifacts into a timestamped evidence directory.

## Rollback

- Host collector: redeploy the previous OCB/config branch or restore previous `logs-supervised-elastic.yaml.j2`, then `task ansible:collector:supervisor`.
- Kubernetes collector: restore the previous DaemonSet manifest, then `task k8s:logs:install`.
- K3s audit: remove `/etc/rancher/k3s/config.yaml.d/90-audit.yaml` and restart `k3s`; keep the audit log files as evidence if needed.

## Redaction

Audit logs can include usernames, groups, namespaces, object names, source IPs, user agents, and request URIs. Redact public IPs, private hostnames, tokens, Cloud IDs, kubeconfigs, and non-synthetic identities before publishing evidence.
