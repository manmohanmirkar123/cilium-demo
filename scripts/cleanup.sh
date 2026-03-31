#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="cilium-demo"

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "Deleting kind cluster: ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
else
  echo "No kind cluster found: ${CLUSTER_NAME}"
fi
