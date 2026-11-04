# Knative + Round 2 - Go Demo App

## Knative - the request flow

- **Queue-proxy** sidecar counts requests in flight, enforces `containerConcurrency`, reports to the autoscaler
- **Activator** buffers requests when there are too few (or zero) Pods and pokes the autoscaler
- **Proxy mode** - activator in the path when `demand + target-burst-capacity > Pods × target`
- **Serve mode** - enough spare capacity, router → Pods directly
- `target-burst-capacity` default **200**; `-1` = activator always in the path

Diagram: [knative.dev/docs/serving/request-flow](https://knative.dev/docs/serving/request-flow/)

## Knative - stable vs. panic window

- **Stable mode** - average concurrency over the **60 s** window
- **Panic window** = 10 % of it = **6 s**
- **Panic** when the 6 s window wants **≥ 200 %** of the ready Pods
- in panic: scale on the 6 s average, **never scale down**; back to stable after a full stable window without the need

| Setting | Default | Annotation |
|---|---:|---|
| `stable-window` | 60s | `autoscaling.knative.dev/window` |
| `panic-window-percentage` | 10 | `autoscaling.knative.dev/panic-window-percentage` |
| `panic-threshold-percentage` | 200 | `autoscaling.knative.dev/panic-threshold-percentage` |

Global: ConfigMap `config-autoscaler` in `knative-serving`. Per revision: `autoscaling.knative.dev/*` annotations on the template.
HPA's closest knob is `behavior.scaleUp`.

## Round 2 setup

```go
sem <- struct{}{}                   // one of WORKERS (10) slots
time.Sleep(rand(minWait..maxWait))  // I/O-like wait, no CPU
<-sem
```

- 10 requests in flight per Pod, the rest **queue** inside the app
- Knative, target 10, window 60s, min 1, max 10

Think: a DB connection pool, a thread pool, a downstream API. The app is **full** long before the CPU is busy.

## Expectations

- What would a CPU HPA do here?
- `fast`: 50 VUs × ~55 ms - how many Pods?
- `slow`: 5 VUs × 1–3 s - queue or not?
- Where do the requests wait?

## Run it

- Argo CD: [challenge-round2]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round2) → CronJob `bench-all` → **Create Job**
- Grafana: [namespace=round2]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge?var-namespace=round2)

```
kubectl -n round2 create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}

Look for: why 8 Pods when there are 50 parallel requests?

## How to improve

Tune: [Knative Service `app`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round2?resource=&node=serving.knative.dev%2FService%2Fround2%2Fapp%2F0)

- `containerConcurrency: 10` - the queue moves from the app to the activator, which can route to new Pods
- `target-utilization-percentage` - how early to add a Pod
- `window` - try 20 s instead of 60 s
- `WORKERS` itself - more slots per Pod, fewer Pods?
- `min-scale` for the known baseline
- watch *Busy workers vs. capacity* and *Queued requests*, not CPU
