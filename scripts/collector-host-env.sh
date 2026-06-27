#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for env_file in "$root/secrets/elastic-cloud.env" "$root/secrets/opamp.env"; do
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [ -z "${ELASTIC_OTLP_ENDPOINT:-}" ] || [ -z "${ELASTIC_API_KEY:-}" ] || [ -z "${OPAMP_AUTH_TOKEN:-}" ]; then
  echo "ELASTIC_OTLP_ENDPOINT, ELASTIC_API_KEY, and OPAMP_AUTH_TOKEN are required" >&2
  echo "Run task secrets:render first." >&2
  exit 1
fi

case "$ELASTIC_OTLP_ENDPOINT" in
  http://*|https://*) ;;
  *) ELASTIC_OTLP_ENDPOINT="https://$ELASTIC_OTLP_ENDPOINT" ;;
esac

case "$ELASTIC_API_KEY" in
  "ApiKey "*)
    ELASTIC_API_KEY="${ELASTIC_API_KEY#ApiKey }"
    ;;
  *:*)
    ELASTIC_API_KEY="$(printf '%s' "$ELASTIC_API_KEY" | base64 | tr -d '\n')"
    ;;
esac

opamp_host="$(
  cd "$root/lab/infra/hcloud"
  terraform output -json servers | jq -r '.opamp.public_host'
)"

if [ -z "$opamp_host" ] || [ "$opamp_host" = "null" ]; then
  echo "could not resolve opamp public_host from Terraform outputs" >&2
  exit 1
fi

case "$opamp_host" in
  *:*) opamp_ws_host="[$opamp_host]" ;;
  *) opamp_ws_host="$opamp_host" ;;
esac

collector_version="${COLLECTOR_VERSION:-0.151.0}"
elastic_onboarding_id="${ELASTIC_ONBOARDING_ID:-00000000-0000-0000-0000-000000000000}"

out="$root/tmp/collector-host.env"
mkdir -p "$(dirname "$out")"
umask 077
cat > "$out" <<EOF
ELASTIC_OTLP_ENDPOINT=$ELASTIC_OTLP_ENDPOINT
ELASTIC_API_KEY=$ELASTIC_API_KEY
OPAMP_AUTH_TOKEN=$OPAMP_AUTH_TOKEN
OTEL_OTLP_GRPC_ENDPOINT=0.0.0.0:4317
OTEL_OTLP_HTTP_ENDPOINT=0.0.0.0:4318
OTEL_HEALTH_CHECK_ENDPOINT=0.0.0.0:13133
OTEL_SELF_METRICS_HOST=127.0.0.1
OTEL_SELF_METRICS_PORT=8888
LOG_FILE_PATHS=/var/log/opamp-poc/synthetic.log
INFRA_LOG_FILE_PATHS=/var/log/syslog,/var/log/opamp-poc/synthetic.log
SECURITY_LOG_FILE_PATHS=/var/log/auth.log
COLLECTOR_LOG_FILE_PATHS=/var/log/opamp-poc/otelcol-logs-opamp.log,/var/log/opamp-poc/opampsupervisor-logs.log
SERVICE_NAME=opamp-poc-host-logs
SERVICE_INSTANCE_ID=opamp-poc-host-agent
COLLECTOR_VERSION=$collector_version
HOST_NAME=opamp-poc-host-agent
HOST_ID=opamp-poc-host-agent
DEPLOYMENT_ENVIRONMENT=lab
POC_NAME=opamp-fleet-logs
ELASTIC_ONBOARDING_ID=$elastic_onboarding_id
OTEL_LOG_LEVEL=info
OTEL_MEMORY_LIMIT_MIB=256
OTEL_MEMORY_SPIKE_LIMIT_MIB=64
OTEL_BATCH_TIMEOUT=1s
OTEL_BATCH_SEND_SIZE=1024
OTEL_BATCH_SEND_MAX_SIZE=2048
ELASTIC_EXPORT_TIMEOUT=30s
OTEL_EXPORT_TIMEOUT=30s
OTEL_EXPORT_QUEUE_CONSUMERS=4
OTEL_EXPORT_QUEUE_SIZE=8192
OPAMP_SERVER_WS_ENDPOINT=wss://$opamp_ws_host:4320/v1/opamp
OPAMP_TLS_INSECURE_SKIP_VERIFY=true
OPAMP_RING=dev
OPAMP_AGENT_EXECUTABLE=/usr/local/bin/otelcol-logs-opamp
OPAMP_AGENT_CONFIG_FILE=/etc/otelcol/logs-opamp-elastic.yaml
OPAMP_SUPERVISED_COLLECTOR=/usr/local/bin/otelcol-logs-opamp
OPAMP_SUPERVISED_CONFIG=/etc/otelcol/logs-opamp-elastic.yaml
EOF

echo "$out"
