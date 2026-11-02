# Scenarios

Every round is its own Argo CD app in its own namespace, and all seven run side by side. Round 1 comes in two variants; rounds 2-6 are Knative services:

| Round | Namespace | Autoscaler | Argo CD app |
|---|---|---|---|
| 1 - CPU-based | `round1-cpu` | `HorizontalPodAutoscaler`, CPU utilization 80 % | [challenge-round1-cpu](http://localhost:30080/applications/argocd/challenge-round1-cpu) |
| 1 - requests in flight | `round1-in-flight` | Knative KPA, concurrency target 10 | [challenge-round1-in-flight](http://localhost:30080/applications/argocd/challenge-round1-in-flight) |
| 2 | `round2` | Knative KPA | [challenge-round2](http://localhost:30080/applications/argocd/challenge-round2) |
| 3 | `round3` | Knative KPA | [challenge-round3](http://localhost:30080/applications/argocd/challenge-round3) |
| 4 | `round4` | Knative KPA | [challenge-round4](http://localhost:30080/applications/argocd/challenge-round4) |
| 5 | `round5` | Knative KPA | [challenge-round5](http://localhost:30080/applications/argocd/challenge-round5) |
| 6 | `round6` | Knative KPA | [challenge-round6](http://localhost:30080/applications/argocd/challenge-round6) |

Links assume the local k3d setup (`localhost:30080`). In Codespaces / Killercoda replace the host with the forwarded port URL.

## Workflow

Each Argo CD app shows the round's manifests (`rounds/<namespace>`) and its benchmark (CronJobs `bench-*` from the shared Helm chart `gitops/charts/k6-bench`) in one place.

1. **Pick the round** - open its Argo CD app (table above); nothing to switch or deploy.
2. **Tune** - open the autoscaling resource (links per round below) -> *Live manifest* -> *Edit*.
   Self-heal is off for the challenge apps, so your change sticks; the app shows *OutOfSync*, *Sync* resets the round to its defaults.
3. **Benchmark** - in the same app: CronJob `bench-all` (or `bench-fast` / `bench-slow` / `bench-random`) -> *...* -> **Create Job**. Run them one at a time.
4. **Read the result** - Grafana dashboard *Autoscaling Reality Check*, `namespace` = the round's namespace, e.g.
   [round1-cpu](http://localhost:30030/d/autoscaling-challenge?var-namespace=round1-cpu) /
   [round1-in-flight](http://localhost:30030/d/autoscaling-challenge?var-namespace=round1-in-flight) /
   [round2](http://localhost:30030/d/autoscaling-challenge?var-namespace=round2) (same pattern for `round3` .. `round6`).

Benchmark CronJob example: [round1-cpu `bench-all`](http://localhost:30080/applications/argocd/challenge-round1-cpu?resource=&node=batch%2FCronJob%2Fround1-cpu%2Fbench-all%2F0).

## The benchmark

All scenarios call `http://app.<namespace>/?minWait=<min>&maxWait=<max>` (k6 `constant-vus`, 90 s per scenario):

| Scenario | Duration | Parallel (VUs) | `minWait` - `maxWait` (ms, random per request) |
|---|---:|---:|---|
| `fast` | 90 s | 20 | 10 - 100 |
| `slow` | 90 s | 5 | 1000 - 2000 |
| `random` | 90 s | 10 | 200 - 1500 |
| `all` | the three above one after another (fast, slow, random) = 270 s | 20 / 5 / 10 | mixed |

The profiles are values of the Helm chart (`gitops/charts/k6-bench/values.yaml`; override per round in the Application's `helm.valuesObject`).

Results land in Prometheus (k6 remote write) and in the Job log (`kubectl -n <namespace> logs job/<name>`).

## Rounds

### Round 1 - nginx, static page

nginx serves the same static page for any `?minWait=&maxWait=` (the requested wait is ignored). Sidecars export stub_status and access-log metrics.

- Watch: does anything scale? *CPU usage* vs. *requests*, *CPU efficiency*, nginx *Connections*.
- round1-cpu (CPU HPA): [HPA `app`](http://localhost:30080/applications/argocd/challenge-round1-cpu?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fround1-cpu%2Fapp%2F0) · [Deployment `app`](http://localhost:30080/applications/argocd/challenge-round1-cpu?resource=&node=apps%2FDeployment%2Fround1-cpu%2Fapp%2F0)
- round1-in-flight (Knative): [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-round1-in-flight?resource=&node=serving.knative.dev%2FService%2Fround1-in-flight%2Fapp%2F0)

### Round 2 - Go app, 10 workers

[app-go](app-go/): each request waits a random `minWait`-`maxWait` ms (sleep, no CPU) holding one of `WORKERS=10` slots; the rest queue.

- Lesson: workers saturate at ~0 % CPU - CPU is the wrong signal here (a CPU HPA would never see it), requests in flight is the right one.
- Watch: *Busy workers vs. capacity*, *Queued requests*, k6 *p99*, *Avg. app Pods*.
- Knobs: Knative `target`, `min-scale` / `max-scale`, container CPU requests, `WORKERS`.
- Argo CD: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-round2?resource=&node=serving.knative.dev%2FService%2Fround2%2Fapp%2F0)

### Round 3 - nginx + php-fpm, two containers in one Pod

[app-php](app-php/): nginx and php-fpm (`pm = static`, `FPM_WORKERS=5`) are two containers of the same Pod - they always scale together. Excess requests wait in the php-fpm listen backlog.

- Lesson: the Pod is the scaling unit - nginx and php-fpm always scale together, and a CPU-based autoscaler would average over *all* containers' requests (sidecars and the idle nginx dilute the signal).
- Watch: *php-fpm busy vs. capacity*, *php-fpm listen queue*, nginx *Requests by response code*.
- Knobs: per-container requests, `FPM_WORKERS`, Knative `target` (= php-fpm workers?).
- Argo CD: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-round3?resource=&node=serving.knative.dev%2FService%2Fround3%2Fapp%2F0)

### Round 4 - Spring MVC, slow startup

[app-java](app-java/): 10 Tomcat threads + accept queue; JVM start under a 500m CPU limit plus `STARTUP_DELAY_SECONDS=30` warm-up before readiness.

- Lesson: new Pods arrive after the burst is over - startup time is part of your scaling budget.
- Watch: *Pods: desired vs. actual* (Knative), *App Pods* running vs. ready, *Tomcat busy vs. capacity*.
- Knobs: `min-scale`, Knative `initial-scale` / `scale-down-delay`, CPU limit during startup, `STARTUP_DELAY_SECONDS`.
- Argo CD: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-round4?resource=&node=serving.knative.dev%2FService%2Fround4%2Fapp%2F0)

### Round 5 - scale to zero

Round 1 nginx with `imagePullPolicy: Always` and Knative `min-scale: "0"`.

- Lesson: idle ~60 s -> 0 Pods; the next request waits in the activator for a cold start (image pull check + container start). (A CPU HPA can't scale to zero at all - no Pod, no CPU metric; `minReplicas: 0` needs the alpha `HPAScaleToZero` gate and object/external metrics.)
- Note: on a single node the image layers stay cached, so `Always` adds "only" a registry round-trip.
- Watch: *Queued & buffered requests* (activator), k6 *p99* of the first requests, *Pods: desired vs. actual*.
- Knobs: `scale-to-zero-pod-retention-period`, `scale-down-delay`, `min-scale`, `imagePullPolicy`.
- Argo CD: [Knative Service `app`](http://localhost:30080/applications/argocd/challenge-round5?resource=&node=serving.knative.dev%2FService%2Fround5%2Fapp%2F0)

### Round 6 - BFF -> microservice

Two tiers of the round 2 Go app: the BFF (`app`, `MODE=bff`) calls the backend (`backend`, default `/` endpoint). Timeouts per request: `?timeout=` (BFF deadline) and `?backend_timeout=` (passed to the backend); the BFF's `TIMEOUT_MS=3000` / `BACKEND_TIMEOUT_MS=2500` are the defaults when k6 sends none.

- Lesson: timeouts must shrink along the chain (BFF > backend), otherwise the BFF holds workers for answers nobody waits for. Both tiers (two Knative Services) autoscale independently - scale the wrong one and you only move the queue.
- Watch: *BFF -> backend calls by result* (`timeout` vs. `504`), *Requests by tier and code* (499 = caller gave up), *Queued requests*.
- Knobs: `TIMEOUT_MS`, `BACKEND_TIMEOUT_MS`, `WORKERS` per tier, per-tier Knative `target`.
- Argo CD: [Knative Service `app` (BFF)](http://localhost:30080/applications/argocd/challenge-round6?resource=&node=serving.knative.dev%2FService%2Fround6%2Fapp%2F0) · [Knative Service `backend`](http://localhost:30080/applications/argocd/challenge-round6?resource=&node=serving.knative.dev%2FService%2Fround6%2Fbackend%2F0)
