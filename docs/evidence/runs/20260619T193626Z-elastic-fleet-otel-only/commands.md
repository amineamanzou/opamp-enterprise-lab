# Commands

Exact commands are represented with redacted hosts, endpoints, and tokens. Real secrets were stored temporarily under `/tmp` and not committed.

## Source/UI Baseline

```sh
browser-use --headed --profile Default open "<kibana-url>/app/fleet"
browser-use --headed --profile Default state > artifacts/browser-use/fleet-home.state.txt
```

## Collector Startup

```sh
ssh root@<host-agent> 'mkdir -p /opt/elastic-fleet-otel-only /etc/elastic-fleet-otel-only /var/log/elastic-fleet-otel-only'
ssh root@<host-agent> 'curl -LfsS -o /tmp/otelcol-contrib.tar.gz https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.151.0/otelcol-contrib_0.151.0_linux_amd64.tar.gz'
scp lab/configs/elastic-fleet-otel-only/otelcol-contrib-fleet-opamp.yaml root@<host-agent>:/etc/elastic-fleet-otel-only/
scp /tmp/fleet-otel-collector.env root@<host-agent>:/etc/elastic-fleet-otel-only/collector.env
ssh root@<host-agent> 'systemctl enable --now otelcol-fleet-opamp'
```

## Validation

```sh
ssh root@<host-agent> 'set -a; . /etc/elastic-fleet-otel-only/collector.env; set +a; /opt/elastic-fleet-otel-only/otelcol-contrib validate --config /etc/elastic-fleet-otel-only/otelcol-contrib-fleet-opamp.yaml'
ssh root@<host-agent> 'curl -fsS http://127.0.0.1:14133/ >/dev/null'
bash -lc 'source scripts/elastic-lib.sh && elastic_load_env && elastic_es_api GET "logs-*-*/_search?size=3" "<redacted-query>"'
browser-use --headed --profile Default state > artifacts/browser-use/fleet-agents-after-connect.state.txt
browser-use --headed --profile Default state > artifacts/browser-use/fleet-agent-detail.state.txt
```

## Functional Scenarios

```sh
ssh root@<host-agent> 'systemctl restart otelcol-fleet-opamp'
ssh root@<host-agent> 'systemctl stop otelcol-fleet-opamp; sleep 75'
ssh root@<host-agent> 'systemctl start otelcol-fleet-opamp'
ssh root@<host-agent> 'otelcol-contrib validate --config /tmp/otelcol-fleet-bad.yaml'
```

## Scale Attempts

```sh
ssh root@<host-agent> 'for i in $(seq -w 1 10); do timeout 180s /opt/elastic-fleet-otel-only/otelcol-contrib --config /opt/elastic-fleet-otel-only/scale-10c/collector-$i.yaml & done'
browser-use --headed --profile Default state > artifacts/browser-use/fleet-agents-scale-10c.state.txt
ssh root@<host-agent> 'tail -n 80 /opt/elastic-fleet-otel-only/scale-10c/collector-*.log'
```
