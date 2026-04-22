#!/usr/bin/env bash

set -euo pipefail

CLUSTER1_CONTEXT="kind-cilium-west"
CLUSTER2_CONTEXT="kind-cilium-east"

echo "Checking ClusterMesh status"
cilium clustermesh status --context "${CLUSTER1_CONTEXT}" --wait
cilium clustermesh status --context "${CLUSTER2_CONTEXT}" --wait

echo
echo "Checking demo resources in both clusters"
kubectl --context "${CLUSTER1_CONTEXT}" -n clustermesh-demo get pods,svc
kubectl --context "${CLUSTER2_CONTEXT}" -n clustermesh-demo get pods,svc

echo
echo "Calling the global service from cluster 1"
for i in 1 2 3 4 5 6; do
  kubectl --context "${CLUSTER1_CONTEXT}" -n clustermesh-demo exec deploy/client -- \
    curl -sS --max-time 5 http://global-echo.clustermesh-demo.svc.cluster.local
done

echo
echo "Calling the global service from cluster 2"
for i in 1 2 3 4 5 6; do
  kubectl --context "${CLUSTER2_CONTEXT}" -n clustermesh-demo exec deploy/client -- \
    curl -sS --max-time 5 http://global-echo.clustermesh-demo.svc.cluster.local
done
