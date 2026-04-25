#!/usr/bin/env bash

set -euo pipefail

CLUSTER1_NAME="cilium-west"
CLUSTER2_NAME="cilium-east"
CLUSTER1_CONTEXT="kind-${CLUSTER1_NAME}"
CLUSTER2_CONTEXT="kind-${CLUSTER2_NAME}"

for cmd in docker kubectl kind cilium; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
done

create_cluster_if_missing() {
  local cluster_name="$1"
  local config_file="$2"

  if ! kind get clusters | grep -qx "${cluster_name}"; then
    echo "Creating kind cluster: ${cluster_name}"
    kind create cluster --name "${cluster_name}" --config "${config_file}"
  else
    echo "kind cluster already exists: ${cluster_name}"
  fi
}

install_cilium_if_missing() {
  local context="$1"
  local cluster_name="$2"
  local cluster_id="$3"

  if kubectl --context "${context}" -n kube-system get daemonset cilium >/dev/null 2>&1; then
    echo "Cilium already installed in ${context}"
    cilium status --context "${context}" --wait
  else
    echo "Installing Cilium in ${context}"
    cilium install \
      --context "${context}" \
      --set cluster.name="${cluster_name}" \
      --set cluster.id="${cluster_id}" \
      --set kubeProxyReplacement=true \
      --wait \
      --wait-duration 10m
  fi

  echo "Enabling Hubble in ${context}"
  cilium hubble enable --context "${context}"
  cilium status --context "${context}" --wait
}

enable_clustermesh_if_needed() {
  local context="$1"

  if kubectl --context "${context}" -n kube-system get deploy clustermesh-apiserver >/dev/null 2>&1; then
    echo "ClusterMesh already enabled in ${context}"
  else
    echo "Enabling ClusterMesh in ${context}"
    cilium clustermesh enable --context "${context}" --service-type NodePort
  fi

  cilium clustermesh status --context "${context}" --wait
}

create_cluster_if_missing "${CLUSTER1_NAME}" "kind-clustermesh-cluster1.yaml"
create_cluster_if_missing "${CLUSTER2_NAME}" "kind-clustermesh-cluster2.yaml"

install_cilium_if_missing "${CLUSTER1_CONTEXT}" "${CLUSTER1_NAME}" "1"
install_cilium_if_missing "${CLUSTER2_CONTEXT}" "${CLUSTER2_NAME}" "2"

enable_clustermesh_if_needed "${CLUSTER1_CONTEXT}"
enable_clustermesh_if_needed "${CLUSTER2_CONTEXT}"

echo "Connecting clusters"
cilium clustermesh connect --context "${CLUSTER1_CONTEXT}" --destination-context "${CLUSTER2_CONTEXT}" --allow-mismatching-ca
cilium clustermesh status --context "${CLUSTER1_CONTEXT}" --wait
cilium clustermesh status --context "${CLUSTER2_CONTEXT}" --wait

echo "Deploying ClusterMesh demo workloads"
kubectl --context "${CLUSTER1_CONTEXT}" apply -f manifests/clustermesh/namespace.yaml
kubectl --context "${CLUSTER2_CONTEXT}" apply -f manifests/clustermesh/namespace.yaml
kubectl --context "${CLUSTER1_CONTEXT}" apply -f manifests/clustermesh/global-service-cluster1.yaml
kubectl --context "${CLUSTER2_CONTEXT}" apply -f manifests/clustermesh/global-service-cluster2.yaml

kubectl --context "${CLUSTER1_CONTEXT}" -n clustermesh-demo rollout status deploy/global-echo --timeout=180s
kubectl --context "${CLUSTER1_CONTEXT}" -n clustermesh-demo rollout status deploy/client --timeout=180s
kubectl --context "${CLUSTER2_CONTEXT}" -n clustermesh-demo rollout status deploy/global-echo --timeout=180s
kubectl --context "${CLUSTER2_CONTEXT}" -n clustermesh-demo rollout status deploy/client --timeout=180s

echo "ClusterMesh setup complete"
