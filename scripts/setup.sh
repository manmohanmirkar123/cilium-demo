#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="cilium-demo"

print_rollout_debug() {
  local deployment_name="$1"
  echo "Rollout failed for deployment: ${deployment_name}"
  kubectl -n demo get pods -o wide || true
  kubectl -n demo describe deployment "${deployment_name}" || true
  kubectl -n demo describe pod -l "app=${deployment_name}" || true
}

for cmd in docker kubectl kind cilium; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
done

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "Creating kind cluster: ${CLUSTER_NAME}"
  kind create cluster --config kind-config.yaml --name "${CLUSTER_NAME}"
else
  echo "kind cluster already exists: ${CLUSTER_NAME}"
fi

echo "Using kubectl context: kind-${CLUSTER_NAME}"
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

if kubectl -n kube-system get daemonset cilium >/dev/null 2>&1; then
  echo "Cilium is already installed"
  cilium status --wait
else
  echo "Installing Cilium"
  cilium install --wait
fi

echo "Enabling Hubble"
cilium hubble enable
cilium status --wait

echo "Deploying demo workloads"
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/demo-app.yaml
kubectl rollout status -n demo deploy/backend --timeout=120s
kubectl rollout status -n demo deploy/frontend --timeout=120s
kubectl rollout status -n demo deploy/api-backend --timeout=120s || {
  print_rollout_debug "api-backend"
  exit 1
}
kubectl rollout status -n demo deploy/attacker --timeout=120s

echo "Applying Cilium network policies"
kubectl apply -f manifests/backend-ingress-policy.yaml
kubectl apply -f manifests/api-http-policy.yaml

echo "Setup complete"
