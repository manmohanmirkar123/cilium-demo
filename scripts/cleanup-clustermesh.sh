#!/usr/bin/env bash

set -euo pipefail

for cluster_name in cilium-west cilium-east; do
  if kind get clusters | grep -qx "${cluster_name}"; then
    echo "Deleting kind cluster: ${cluster_name}"
    kind delete cluster --name "${cluster_name}"
  else
    echo "No kind cluster found: ${cluster_name}"
  fi
done
