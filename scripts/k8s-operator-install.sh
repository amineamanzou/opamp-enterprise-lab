#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
default_kubeconfig="$root/secrets/kubeconfig-opamp-poc.yaml"
kubeconfig="${KUBECONFIG:-$default_kubeconfig}"
if [ ! -f "$kubeconfig" ] && [ -f "$default_kubeconfig" ]; then
  kubeconfig="$default_kubeconfig"
fi

if [ ! -f "$kubeconfig" ]; then
  echo "kubeconfig not found at $kubeconfig; run task ansible:k3s first" >&2
  exit 1
fi

export KUBECONFIG="$kubeconfig"

cert_manager_version="${CERT_MANAGER_VERSION:-v1.20.2}"
otel_operator_version="${OTEL_OPERATOR_VERSION:-v0.153.0}"

kubectl apply --server-side=true \
  -f "https://github.com/cert-manager/cert-manager/releases/download/${cert_manager_version}/cert-manager.yaml"
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s

kubectl apply --server-side=true \
  -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${otel_operator_version}/opentelemetry-operator.yaml"
kubectl -n opentelemetry-operator-system rollout status deploy/opentelemetry-operator-controller-manager --timeout=180s

kubectl get nodes
kubectl get pods -n cert-manager
kubectl get pods -n opentelemetry-operator-system
