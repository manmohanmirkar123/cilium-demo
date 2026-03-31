#!/usr/bin/env bash

set -euo pipefail

echo "Checking Cilium status"
cilium status --wait

echo "Checking demo resources"
kubectl -n demo get pods,svc,ciliumnetworkpolicy

echo
echo "Expected: frontend can reach backend"
kubectl -n demo exec deploy/frontend -- curl -sS --fail --max-time 5 http://backend.demo.svc.cluster.local:8080

echo
echo "Expected: attacker is blocked"
if kubectl -n demo exec deploy/attacker -- curl -sS --fail --max-time 5 http://backend.demo.svc.cluster.local:8080; then
  echo "Unexpected result: attacker reached backend"
  exit 1
else
  echo "Blocked as expected"
fi

echo
echo "Expected: frontend GET /get is allowed to api-backend"
kubectl -n demo exec deploy/frontend -- curl -sS --fail --max-time 5 http://api-backend.demo.svc.cluster.local/get >/dev/null
echo "Allowed as expected"

echo
echo "Expected: frontend POST /post is allowed to api-backend"
kubectl -n demo exec deploy/frontend -- curl -sS --fail --max-time 5 -X POST http://api-backend.demo.svc.cluster.local/post >/dev/null
echo "Allowed as expected"

echo
echo "Expected: frontend GET /headers is blocked by HTTP path policy"
if kubectl -n demo exec deploy/frontend -- curl -sS --fail --max-time 5 http://api-backend.demo.svc.cluster.local/headers >/dev/null; then
  echo "Unexpected result: GET /headers was allowed"
  exit 1
else
  echo "Blocked as expected"
fi

echo
echo "Expected: attacker GET /get is blocked by source identity policy"
if kubectl -n demo exec deploy/attacker -- curl -sS --fail --max-time 5 http://api-backend.demo.svc.cluster.local/get >/dev/null; then
  echo "Unexpected result: attacker reached api-backend"
  exit 1
else
  echo "Blocked as expected"
fi
