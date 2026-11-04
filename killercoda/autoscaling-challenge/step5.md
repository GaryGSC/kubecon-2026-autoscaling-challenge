# Round 4 - Spring MVC

## Setup

- Spring MVC, `TOMCAT_THREADS=10` + accept queue
- JVM start under a **500m CPU limit**
- `STARTUP_DELAY_SECONDS=30` warm-up before readiness
- Knative, target 10

The usual enterprise app: slow JVM start, caches to fill, *Ready* only after warm-up.

## Expectations

- How long from "scale up" to a Pod serving traffic?
- How much of the 120 s burst is left by then?
- Does panic mode help?

## Run it

- Argo CD: [challenge-round4]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round4) → CronJob `bench-all` → **Create Job**
- Grafana: [namespace=round4]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge?var-namespace=round4)

```
kubectl -n round4 create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}

Look for: *Pods: desired vs. actual*, running vs. ready Pods - and why that much CPU?

## How to improve

Tune: [Knative Service `app`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round4?resource=&node=serving.knative.dev%2FService%2Fround4%2Fapp%2F0)

- `min-scale` - pay for headroom you can't create in time
- `initial-scale`, `scale-down-delay` - keep expensive Pods around
- lower `target` / utilization → scale **earlier** (does 20 % beat 70 %?)
- more CPU during startup (no limit, in-place resize)
- shorter warm-up - cache from a shared store, CDS / CRaC
- **GraalVM** native image - starts in milliseconds, no JIT warm-up
- startup time is part of your scaling budget - **measure it**
