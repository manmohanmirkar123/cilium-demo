# Cilium Demo Repository

This repository gives you a simple, repeatable way to demo Cilium on a local Kubernetes cluster and then share the setup through GitHub.

The demo focuses on three things:

- Cilium installation on a local `kind` cluster
- Traffic visibility with Hubble
- Network policy enforcement between workloads
- HTTP-aware policy enforcement by method and path

## Demo Story

The application layout is intentionally small:

- `frontend` pod: allowed to call `backend`
- `attacker` pod: should be blocked from calling `backend`
- `backend` service: exposes a tiny HTTP echo app on port `8080`
- `api-backend` service: HTTP application used for L7 method/path policy demos

With the Cilium policy applied:

- `frontend -> backend` works
- `attacker -> backend` is denied
- Hubble shows both allowed and dropped traffic
- `frontend GET /get` to `api-backend` works
- `frontend POST /post` to `api-backend` works
- `frontend GET /headers` is denied because the path is not allowed

## Repo Layout

- `kind-config.yaml`: local cluster definition
- `manifests/`: namespace, app manifests, and Cilium policy
- `scripts/setup.sh`: create cluster, install Cilium, enable Hubble, deploy app
- `scripts/run-demo.sh`: run the demo flow step by step
- `scripts/validate.sh`: verify connectivity and policy behavior
- `scripts/cleanup.sh`: remove cluster and demo resources
- `docs/screenshots/`: optional screenshots for GitHub documentation

## Prerequisites

Install these tools on your machine:

- `docker`
- `kubectl`
- `kind`
- `cilium`

Official docs:

- Cilium CLI: https://docs.cilium.io/en/latest/cmdref/cilium/
- Cilium on kind: https://docs.cilium.io/en/stable/installation/kind/
- Hubble UI: https://docs.cilium.io/en/latest/cmdref/cilium_hubble_ui/

## Quick Start

```bash
./scripts/setup.sh
./scripts/validate.sh
./scripts/run-demo.sh
```

To open Hubble UI in a separate terminal:

```bash
cilium hubble enable --ui
cilium hubble ui --open-browser=false
```

Then open:

```bash
http://localhost:12000
```

## Demo Walkthrough

### 1. Create the cluster and install Cilium

```bash
./scripts/setup.sh
```

### 2. Show Cilium status

```bash
cilium status --wait
kubectl get pods -A
```

### 3. Validate the app before policy discussion

```bash
kubectl -n demo get pods,svc
kubectl -n demo exec deploy/frontend -- curl -sS --max-time 5 http://backend.demo.svc.cluster.local:8080
kubectl -n demo exec deploy/attacker -- curl -sS --max-time 5 http://backend.demo.svc.cluster.local:8080
```

After the policy is present:

- frontend succeeds
- attacker fails

### 4. Show the policy

```bash
kubectl -n demo get ciliumnetworkpolicy
kubectl -n demo describe ciliumnetworkpolicy backend-ingress-policy
```

Policy YAML:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-ingress-policy
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

How to explain it:

- `endpointSelector` picks the protected workload, which is the `backend` pod.
- `fromEndpoints` defines who is allowed to talk to that workload.
- Only pods with label `app=frontend` are allowed.
- `toPorts` restricts the allowed traffic to TCP port `8080`.
- There is no rule allowing `app=attacker`, so that traffic is denied.

Why the attacker is blocked:

- Cilium applies this policy to the `backend` endpoint.
- Once the policy is enforced, traffic to `backend` is only accepted if it matches an allow rule.
- The `attacker` pod does not match `app=frontend`.
- Because it does not match any allowed source rule, the connection is dropped.

### 5. Show Hubble observability

In one terminal:

```bash
cilium hubble enable --ui
cilium hubble ui --open-browser=false
```

Then open `http://localhost:12000` in your browser.

In another terminal:

```bash
kubectl -n demo exec deploy/frontend -- curl -sS http://backend.demo.svc.cluster.local:8080
kubectl -n demo exec deploy/attacker -- curl -sS --max-time 5 http://backend.demo.svc.cluster.local:8080
```

You should see:

- forwarded flow from `frontend`
- dropped flow from `attacker`
- service map and flow details in Hubble UI

### 6. Show HTTP method and path policy

Allowed requests:

```bash
kubectl -n demo exec deploy/frontend -- curl -sS http://api-backend.demo.svc.cluster.local/get
kubectl -n demo exec deploy/frontend -- curl -sS -X POST http://api-backend.demo.svc.cluster.local/post
```

Blocked requests:

```bash
kubectl -n demo exec deploy/frontend -- curl -sS --fail --max-time 5 http://api-backend.demo.svc.cluster.local/headers
kubectl -n demo exec deploy/attacker -- curl -sS --fail --max-time 5 http://api-backend.demo.svc.cluster.local/get
```

Policy YAML:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-http-policy
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: api-backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/get"
              - method: "POST"
                path: "/post"
```

How to explain it:

- This policy protects the `api-backend` pods.
- `frontend` is the only allowed source.
- At L7, only `GET /get` and `POST /post` are allowed.
- A request like `GET /headers` is denied because the path does not match.
- A request from `attacker` is denied even if it uses an allowed method and path, because the source identity is not allowed.

Typical blocked request behavior:

- L7-denied requests often return an HTTP error such as `403 Forbidden`.
- Depending on timing and the client behavior, you may also see a curl failure.
- The important demo point is that only the explicitly allowed method and path combinations succeed.

## Sample Outputs

These are example outputs from the demo commands so you know what to expect while presenting.

### Allowed `frontend -> backend`

```bash
kubectl -n demo exec deploy/frontend -- curl -sS http://backend.demo.svc.cluster.local:8080
```

Expected output:

```text
hello-from-backend
```

![Hubble UI Service Map](docs/screenshots/ss1.png)

### Denied `attacker -> backend`

```bash
kubectl -n demo exec deploy/attacker -- curl -sS --max-time 5 http://backend.demo.svc.cluster.local:8080
```

Expected output:

```text
curl: (28) Connection timed out after 5001 milliseconds
command terminated with exit code 28
```

![Hubble UI Service Map](docs/screenshots/ss2.png)

### Allowed `frontend -> api-backend` with `GET /get`

```bash
kubectl -n demo exec deploy/frontend -- curl -sS http://api-backend.demo.svc.cluster.local/get
```

Expected output:

```json
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "api-backend.demo.svc.cluster.local",
    "User-Agent": "curl/8.12.1",
    "X-Envoy-Expected-Rq-Timeout-Ms": "3600000",
    "X-Envoy-Internal": "true"
  },
  "origin": "10.244.1.240",
  "url": "http://api-backend.demo.svc.cluster.local/get"
}
```

![Hubble UI Service Map](docs/screenshots/ss3.png)

### Allowed `frontend -> api-backend` with `POST /post`

```bash
kubectl -n demo exec deploy/frontend -- curl -sS -X POST http://api-backend.demo.svc.cluster.local/post
```

Expected output:

```json
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Content-Length": "0",
    "Host": "api-backend.demo.svc.cluster.local",
    "User-Agent": "curl/8.12.1",
    "X-Envoy-Expected-Rq-Timeout-Ms": "3600000",
    "X-Envoy-Internal": "true"
  },
  "json": null,
  "origin": "10.244.1.240",
  "url": "http://api-backend.demo.svc.cluster.local/post"
}
```

![Hubble UI Service Map](docs/screenshots/ss3.png)

### Denied `attacker -> api-backend`

```bash
kubectl -n demo exec deploy/attacker -- curl -i --max-time 5 http://api-backend.demo.svc.cluster.local/get
```

Expected output:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0
curl: (28) Connection timed out after 5017 milliseconds
command terminated with exit code 28
```

![Hubble UI Service Map](docs/screenshots/ss4.png)

## Five-Minute Demo Script

Use this flow when you want to present the demo live in a short session.

### 1. Prepare the environment

```bash
./scripts/setup.sh
./scripts/validate.sh
```

Say:

- "This demo uses a local `kind` Kubernetes cluster with Cilium installed as the CNI."
- "We also enabled Hubble so we can see traffic and policy decisions in real time."

### 2. Show the workloads and policy

```bash
kubectl -n demo get pods,svc,ciliumnetworkpolicy
```

Say:

- "The `frontend` pod is the allowed client."
- "The `attacker` pod represents an unauthorized workload."
- "The `backend` service is the application we want to protect."

### 3. Prove allowed traffic

```bash
kubectl -n demo exec deploy/frontend -- curl -sS http://backend.demo.svc.cluster.local:8080
```

Expected output:

```bash
hello-from-backend
```

Say:

- "This request succeeds because the policy allows traffic from `frontend` to `backend` on port `8080`."
- "The source pod matches `app=frontend`, so the traffic matches the allow rule."

### 4. Prove denied traffic

```bash
kubectl -n demo exec deploy/attacker -- curl -sS --fail --max-time 5 http://backend.demo.svc.cluster.local:8080
```

Say:

- "This request fails because Cilium is enforcing the network policy."
- "Only the intended workload can reach the backend."
- "The attacker pod does not match the allowed source label, so Cilium drops the connection."

Typical blocked request output:

```bash
curl: (28) Connection timed out after 5001 milliseconds
```

Depending on timing and environment, you may also see a connection failure message instead of a timeout. The important point is that the request does not reach the backend.

### 5. Show the actual policy

```bash
kubectl -n demo describe ciliumnetworkpolicy backend-ingress-policy
```

Say:

- "This policy selects the backend pods."
- "It only allows ingress from pods labeled `app=frontend` on TCP port `8080`."
- "Everything else trying to reach backend on that path is implicitly denied by policy enforcement."

### 6. Show Hubble observability

Terminal 1:

```bash
cilium hubble enable --ui
cilium hubble ui --open-browser=false
```

Then open `http://localhost:12000` in your browser.

Terminal 2:

```bash
kubectl -n demo exec deploy/frontend -- curl -sS http://backend.demo.svc.cluster.local:8080
kubectl -n demo exec deploy/attacker -- curl -sS --max-time 5 http://backend.demo.svc.cluster.local:8080
```

Say:

- "Hubble shows the successful flow from frontend to backend."
- "It also shows the dropped flow from the attacker pod."
- "That gives us both enforcement and observability from the same platform."

### 7. Optional one-command demo

```bash
./scripts/run-demo.sh
```

Use this when you want a quick walkthrough without typing each command manually.

## Cleanup

```bash
./scripts/cleanup.sh
```
