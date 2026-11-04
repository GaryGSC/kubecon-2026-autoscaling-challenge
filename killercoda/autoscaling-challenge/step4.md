# Round 3 - nginx + php-fpm

## Setup

- **two app containers**, one scaling unit
- php-fpm `pm = static`, `FPM_WORKERS=2` - **on purpose** only 2
- extra requests wait in the php-fpm **listen backlog**
- Knative, target 10

```text
k6 client   50 parallel (fast), then 5 (slow)
   │
   ▼
Pod  (Knative target 10)  requests
├── queue-proxy (Knative)
├── nginx      :8080 ─┐     25m   (512 connections, default)
└── php-fpm    :9000 ◄┘     50m   (2 workers!)
```

## Expectations

- Which container is the bottleneck?
- What does one more replica cost?
- What would a CPU HPA average over?

## Run it

- Argo CD: [challenge-round3]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round3) → CronJob `bench-all` → **Create Job**
- Grafana: [namespace=round3]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge?var-namespace=round3)

```
kubectl -n round3 create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}

Look for: failed requests - status `0` = no response within the 5 s k6 timeout, during `slow` with only 5 parallel requests.
How "full" is the system? Compare client latency (k6) with server latency (Knative queue-proxy) - where do the requests go when the client times out?

## How to improve

Tune: [Knative Service `app`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round3?resource=&node=serving.knative.dev%2FService%2Fround3%2Fapp%2F0)

- `target` = `FPM_WORKERS` - the worker pool is the capacity (try target 2)
- right-size **per container** - nginx needs little
- `pm = dynamic` vs. `static` - memory vs. readiness
- CPU HPA? → `ContainerResource` on `php-fpm`
- watch *php-fpm listen queue* and *busy vs. capacity*
