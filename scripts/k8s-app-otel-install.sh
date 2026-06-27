#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace="${K8S_APP_NAMESPACE:-opamp-app-poc}"
default_kubeconfig="$root/secrets/kubeconfig-opamp-poc.yaml"
kubeconfig="${KUBECONFIG:-$default_kubeconfig}"
if [ ! -f "$kubeconfig" ] && [ -f "$default_kubeconfig" ]; then
  kubeconfig="$default_kubeconfig"
fi

for env_file in "$root/secrets/elastic-cloud.env" "$root/secrets/opamp.env"; do
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [ ! -f "$kubeconfig" ]; then
  echo "kubeconfig not found at $kubeconfig; run task ansible:k3s first" >&2
  exit 1
fi

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

export KUBECONFIG="$kubeconfig"

kubectl apply -f "$root/lab/configs/kubernetes/otelcol-app-opamp.yaml"

kubectl -n "$namespace" create secret generic elastic-otlp \
  --from-literal=endpoint="$ELASTIC_OTLP_ENDPOINT" \
  --from-literal=api-key="$ELASTIC_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$namespace" create secret generic opamp-auth \
  --from-literal=token="$OPAMP_AUTH_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$namespace" create configmap otelcol-app-opamp-env \
  --from-literal=opamp-server-ws-endpoint="wss://$opamp_ws_host:4320/v1/opamp" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$namespace" rollout restart deployment/otelcol-app-opamp
kubectl -n "$namespace" rollout restart deployment/synthetic-otel-app
kubectl -n "$namespace" rollout status deployment/otelcol-app-opamp --timeout=240s
kubectl -n "$namespace" rollout status deployment/synthetic-otel-app --timeout=240s

kubectl -n "$namespace" get pods -o wide
