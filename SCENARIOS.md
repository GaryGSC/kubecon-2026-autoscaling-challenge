# Scenarios

Every round comes in two variants, each in its own namespace:

| Variant | Namespace | Autoscaler | Argo CD app |
|---|---|---|---|
| CPU-based | `cpu-hpa` | `HorizontalPodAutoscaler`, CPU utilization 80 % | [challenge-cpu-hpa](http://localhost:30080/applications/argocd/challenge-cpu-hpa) |
| Requests in flight | `knative-kpa` | Knative KPA, concurrency target 10 | [challenge-knative-kpa](http://localhost:30080/applications/argocd/challenge-knative-kpa) |

Links assume the local k3d setup (`localhost:30080`). In Codespaces / Killercoda replace the host with the forwarded port URL.

## Workflow

1. **Pick the round** - Argo CD app -> *Details* -> *Edit* -> *Path* `rounds/roundN/<variant>` -> *Save*, or:
   ```bash
   kubectl -n argocd patch application challenge-cpu-hpa --type merge \
     -p '{"spec":{"source":{"path":"rounds/round2/cpu-hpa"}}}'
   ```
   The app prunes the previous round automatically.
2. **Tune** - open the autoscaling resource (links per round below) -> *Live manifest* -> *Edit*.
   Self-heal is off for the challenge apps, so your change sticks; the app shows *OutOfSync*, *Sync* resets the round to its defaults.
3. **Benchmark** - Argo CD app `platform-benchmark-<variant>` -> CronJob `bench-all` (or `bench-fast` / `bench-slow` / `bench-random`) -> *...* -> **Create Job**.
4. **Read the result** - Grafana dashboard *Autoscaling Reality Check*, `namespace` = your variant:
   [cpu-hpa](http://localhost:30030/d/autoscaling-challenge?var-namespace=cpu-hpa) /
   [knative-kpa](http://localhost:30030/d/autoscaling-challenge?var-namespace=knative-kpa).

Benchmark CronJobs: [cpu-hpa `bench-all`](http://localhost:30080/applications/argocd/platform-benchmark-cpu-hpa?resource=&node=batch%2FCronJob%2Fcpu-hpa%2Fbench-all%2F0) /
[knative-kpa `bench-all`](http://localhost:30080/applications/argocd/platform-benchmark-knative-kpa?resource=&node=batch%2FCronJob%2Fknative-kpa%2Fbench-all%2F0)

## The benchmark

All scenarios call `http://app.<namespace>/?ms=<wait>` (k6 `shared-iterations`):

| Scenario | Requests | Parallel (VUs) | `ms` per request |
|---|---:|---:|---|
| `fast` | 1000 | 20 | 10 - 100 |
| `slow` | 200 | 5 | 1000 - 2000 |
| `random` | 300 | 10 | 200 - 1500 |
| `all` | the three above in parallel | 35 | mixed |

Results land in Prometheus (k6 remote write) and in the Job log (`kubectl -n <variant> logs job/<name>`).

## Rounds

### Round 1 - nginx, static page

nginx serves the same static page for any `?ms=` (the requested wait is ignored). Sidecars export stub_status and access-log metrics.

- Watch: does anything scale? *CPU usage* vs. *requests*, *CPU efficiency*, nginx *Connections*.
- cpu-hpa: [HPA `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fapp%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fapp%2F0)
- knative-kpa: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fapp%2F0)

### Round 2 - Go app, 10 workers

[app-go](app-go/): each request waits `ms` (sleep, no CPU) holding one of `WORKERS=10` slots; the rest queue.

- Lesson: workers saturate at ~0 % CPU - the CPU HPA never sees it, Knative's requests-in-flight does.
- Watch: *Busy workers vs. capacity*, *Queued requests*, k6 *p99*, *Avg. app Pods*.
- Knobs: HPA target / `behavior`, container CPU requests, Knative `target`, `WORKERS`.
- cpu-hpa: [HPA `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fapp%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fapp%2F0)
- knative-kpa: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fapp%2F0)

### Round 3 - nginx + php-fpm, two containers in one Pod

[app-php](app-php/): nginx and php-fpm (`pm = static`, `FPM_WORKERS=5`) are two containers of the same Pod - they always scale together. Excess requests wait in the php-fpm listen backlog.

- Lesson: the Pod is the scaling unit. The HPA averages CPU utilization over *all* containers' requests - sidecars and the idle nginx dilute the signal.
- Watch: *php-fpm busy vs. capacity*, *php-fpm listen queue*, nginx *Requests by response code*.
- Knobs: per-container requests, `FPM_WORKERS`, HPA `ContainerResource` metric (target only the php-fpm container), Knative `target` (= php-fpm workers?).
- cpu-hpa: [HPA `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fapp%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fapp%2F0)
- knative-kpa: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fapp%2F0)

### Round 4 - Spring MVC, slow startup

[app-java](app-java/): 10 Tomcat threads + accept queue; JVM start under a 500m CPU limit plus `STARTUP_DELAY_SECONDS=30` warm-up before readiness.

- Lesson: new Pods arrive after the burst is over - startup time is part of your scaling budget.
- Watch: *Pods: desired vs. actual* (Knative), *App Pods* running vs. ready, *Tomcat busy vs. capacity*.
- Knobs: `minReplicas` / `min-scale`, HPA `behavior.scaleUp`, Knative `initial-scale` / `scale-down-delay`, CPU limit during startup, `STARTUP_DELAY_SECONDS`.
- cpu-hpa: [HPA `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fapp%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fapp%2F0)
- knative-kpa: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fapp%2F0)

### Round 5 - scale to zero

Round 1 nginx with `imagePullPolicy: Always`; the Knative variant uses `min-scale: "0"`.

- Lesson: idle ~60 s -> 0 Pods; the next request waits in the activator for a cold start (image pull check + container start). The CPU HPA can't scale to zero at all (no Pod, no CPU metric; `minReplicas: 0` needs the alpha `HPAScaleToZero` gate and object/external metrics).
- Note: on a single node the image layers stay cached, so `Always` adds "only" a registry round-trip.
- Watch: *Queued & buffered requests* (activator), k6 *p99* of the first requests, *Pods: desired vs. actual*.
- Knobs: `scale-to-zero-pod-retention-period`, `scale-down-delay`, `min-scale`, `imagePullPolicy`.
- cpu-hpa: [HPA `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fapp%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fapp%2F0)
- knative-kpa: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fapp%2F0)

### Round 6 - BFF -> microservice

Two tiers of the round 2 Go app: the BFF (`app`, `MODE=bff`) calls the backend (`backend`, default `/` endpoint). Timeouts per request: `?timeout=` (BFF deadline) and `?backend_timeout=` (passed to the backend); the BFF's `TIMEOUT_MS=3000` / `BACKEND_TIMEOUT_MS=2500` are the defaults when k6 sends none.

- Lesson: timeouts must shrink along the chain (BFF > backend), otherwise the BFF holds workers for answers nobody waits for. Both tiers autoscale independently - scale the wrong one and you only move the queue.
- Watch: *BFF -> backend calls by result* (`timeout` vs. `504`), *Requests by tier and code* (499 = caller gave up), *Queued requests*.
- Knobs: `TIMEOUT_MS`, `BACKEND_TIMEOUT_MS`, `WORKERS` per tier, per-tier HPA / Knative `target`.
- cpu-hpa: [HPA `app` (BFF)](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fapp%2F0) · [HPA `backend`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fcpu-hpa%2Fbackend%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fapp%2F0) · [Deployment `backend`](http://localhost:30080/applications/argocd/challenge-cpu-hpa?resource=&node=apps%2FDeployment%2Fcpu-hpa%2Fbackend%2F0)
- knative-kpa: [Knative Service `app` (BFF)](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fapp%2F0) · [Knative Service `backend`](http://localhost:30080/applications/argocd/challenge-knative-kpa?resource=&node=serving.knative.dev%2FService%2Fknative-kpa%2Fbackend%2F0)
