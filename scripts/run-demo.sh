#!/usr/bin/env bash

set -euo pipefail

echo "Step 1: show the demo namespace"
kubectl -n demo get pods -o wide

echo
echo "Step 2: show the Cilium policy"
kubectl -n demo get ciliumnetworkpolicy

echo
echo "Step 3: frontend request should succeed"
kubectl -n demo exec deploy/frontend -- curl -sS --max-time 5 http://backend.demo.svc.cluster.local:8080

echo
echo "Step 4: attacker request should fail"
if kubectl -n demo exec deploy/attacker -- curl -sS --fail --max-time 5 http://backend.demo.svc.cluster.local:8080; then
  echo "Unexpected result: attacker reached backend"
  exit 1
else
  echo "Traffic denied as expected"
fi

echo
echo "Step 5: suggested Hubble commands"
echo "Run: cilium hubble port-forward &"
echo "Then: hubble observe --namespace demo --follow"
echo "Or: cilium hubble ui"

echo
echo "Step 6: frontend GET /get should succeed"
kubectl -n demo exec deploy/frontend -- curl -sS --max-time 5 http://api-backend.demo.svc.cluster.local/get

echo
echo "Step 7: frontend POST /post should succeed"
kubectl -n demo exec deploy/frontend -- curl -sS --max-time 5 -X POST http://api-backend.demo.svc.cluster.local/post

echo
echo "Step 8: frontend GET /headers should fail because path is not allowed"
if kubectl -n demo exec deploy/frontend -- curl -sS --fail --max-time 5 http://api-backend.demo.svc.cluster.local/headers; then
  echo "Unexpected result: GET /headers was allowed"
  exit 1
else
  echo "Traffic denied as expected"
fi
