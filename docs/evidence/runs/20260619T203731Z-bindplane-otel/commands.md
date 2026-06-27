# Commands

Fill with exact commands run during the lab. Redact tokens, public IPs, tenant IDs, and private hostnames.

## UI Baseline

```sh
browser-use --headed --profile Default open "https://app.bindplane.com/"
browser-use --headed --profile Default state > artifacts/browser-use/bindplane-home.state.txt
```

## Runtime Secret Handling

```sh
umask 077
$EDITOR /tmp/bindplane-otel.env
set -a
. /tmp/bindplane-otel.env
set +a
```

## Collector Startup

```sh
otelcol-contrib --config config/otelcol-contrib-bindplane-opamp.yaml
```

## Validation

```sh
curl -fsS "${OTEL_HEALTH_CHECK_URL}"
```
