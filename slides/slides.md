---
theme: default
colorSchema: 'dark'
title: 'Autoscaling Reality Check'
info: |
  Autoscaling Reality Check: The Hands-On HTTP Optimization Challenge
  KubeCon + CloudNativeCon North America 2026 — David Pech
class: text-center
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
addons:
  - slidev-addon-qrcode
fonts:
  sans: 'Inter'
  mono: 'JetBrains Mono'
css: ./style.css
vite:
  server:
    hmr:
      overlay: false
    fs:
      allow:
        - '.'
        - '/'

---

# Autoscaling Reality Check 📈

## The Hands-On HTTP Optimization Challenge

<div class="mt-10 text-lg opacity-90">
  <strong>David Pech</strong> — Wrike
</div>

<div class="abs-bl m-6 text-sm opacity-75">
  KubeCon + CloudNativeCon North America 2026 · Tutorial
</div>

<div class="abs-br m-6 text-sm opacity-75">
  #KubeCon #CloudNativeCon #Kubernetes #Autoscaling
</div>

---

# Who

<div class="flex flex-col items-center justify-center h-[80%] gap-6">

<img src="/david-pech.jpg" class="rounded-full w-44 h-44 object-cover ring-4 ring-blue-400 shadow-2xl" />

<div class="text-4xl font-bold tracking-tight">David Pech</div>

<div class="flex items-center gap-12 mt-2">
  <img src="/wrike-logo.svg" class="h-16" style="filter: brightness(0) invert(1);" />
  <img src="/kubestronaut.png" class="h-24" />
</div>

</div>

---

# The gap

<div class="grid grid-cols-2 gap-10 mt-8">

<div class="kcd-card">

**Vendor demo**

- `kubectl autoscale deployment app --cpu-percent=80`
- one endpoint, one request type
- graph goes up, Pods go up 🎉

</div>

<div class="kcd-card kcd-card-danger">

**Production**

- fast *and* slow requests on the same Pods
- workers saturate at **~0% CPU**
- Pods take seconds (or minutes) to be useful
- memory creeps, timeouts pile up

</div>

</div>

<div class="mt-10 text-xl text-center">
How fast can your Pods <em>really</em> scale when the traffic hits?
</div>

---

# Today

<div class="grid grid-cols-[1fr_1fr] gap-10 mt-6">

<div>

## You get

- a pre-configured cluster (Pod-level autoscaling only)
- every round in its own namespace + Argo CD app, all running side by side:
  - <span class="kcd-pill">round1-cpu</span> Deployment + **CPU HPA**
  - <span class="kcd-pill">round1-in-flight</span> Knative **requests-in-flight**
  - <span class="kcd-pill">round2</span> … <span class="kcd-pill">round6</span> Knative
- a 4-minute mixed benchmark (k6)
- one Grafana dashboard

</div>

<div>

## You do

1. deploy a round
2. run the benchmark
3. read the dashboard
4. tune → repeat
5. leaderboard 🏆

</div>

</div>

---

# Get a cluster (pick one)

<div class="grid grid-cols-3 gap-6 mt-6">

<div class="kcd-card">

**Local k3d**

```bash
git clone https://github.com/\
depeche-io/kubecon-2026-\
autoscaling-challenge
cd kubecon-2026-autoscaling-challenge
./bin/up.sh
```

</div>

<div class="kcd-card">

**GitHub Codespaces**

Open the repo → *Code* → *Codespaces*.

`up.sh` runs on start (4 cores / 16 GB).

</div>

<div class="kcd-card">

**Killercoda**

Scenario *Autoscaling Reality Check*.

Smallest option — fine for watching, tight for the full stack.

</div>

</div>

<div class="mt-8 text-center text-lg">

Argo CD <code>:30080</code> · Grafana <code>:30030</code> · Prometheus <code>:30090</code> — <code>admin</code> / <code>@utoSc4ling</code>

</div>

---

# The platform

<div class="grid grid-cols-[1fr_1fr] gap-10 mt-6">

<div>

Argo CD (plain `Application` manifests), everything single-instance:

- **Istio** 1.29 — ingress for Knative
- **Knative Serving** 1.24 — KPA, concurrency
- **kube-prometheus-stack** — 5s scrapes
- **k6** benchmarks — suspended CronJobs

</div>

<div>

```text
gitops/
├── bootstrap/          # Argo CD itself
├── projects/           # AppProjects
├── applications/       # one Application per round
├── charts/k6-bench/    # benchmark CronJobs (Helm), in every round's app
└── manifests/          # plain YAML (Knative, dashboard)
rounds/round1-cpu  rounds/round1-in-flight
rounds/round2 … rounds/round6
```

</div>

</div>

---

# The benchmark

| Scenario | Duration | Parallel (VUs) | Wait per request |
|---|---:|---:|---|
| `fast` | 90 s | 20 | 10 – 100 ms |
| `slow` | 90 s | 5 | 1 – 3 s |
| `medium` | 90 s | 10 | 200 ms – 1 s |
| `all` | one after another, 270 s | 20 / 5 / 10 | mixed |

<div class="mt-6">

Run it from **Argo CD** → the round's app (`challenge-<round>`) → `bench-all` → **Create Job**

```bash
kubectl -n round1-cpu create job --from=cronjob/bench-all bench-all-$(date +%s)
```

</div>

---

# What we measure

<div class="grid grid-cols-2 gap-8 mt-6">

<div class="kcd-card kcd-card-ok">

**User view**

- availability = success / total
- p50 / p90 / p99 latency

</div>

<div class="kcd-card kcd-card-warn">

**Cost view**

- CPU efficiency = usage / requests
- MEM efficiency = usage / requests
- avg. number of app Pods

</div>

</div>

<div class="mt-8 text-center text-xl">
Good autoscaling = <strong>users don't notice</strong> and you <strong>don't pay for idle</strong>.
</div>

---

# Round 1 — nginx, static page

Argo CD apps `challenge-round1-cpu` and `challenge-round1-in-flight` (`rounds/round1-cpu`, `rounds/round1-in-flight`)

- nginx serves the same page for any `?minWait=&maxWait=` — the benchmark's waits are ignored
- CPU HPA at 80 %, Knative target 10 requests in flight

<div class="kcd-card mt-6">

**Question:** does anything scale at all? Should it?

</div>

---

# Round 2 — Go app, 10 workers

```go
sem <- struct{}{}          // wait for one of WORKERS (10) slots
time.Sleep(rand(minWait..maxWait)) // I/O-like wait, no CPU
<-sem
```

- throughput is capped at 10 requests in flight per Pod
- CPU stays near zero → CPU is the wrong signal (**a CPU HPA never notices**)
- Knative scales on requests in flight → it does

<div class="kcd-card kcd-card-warn mt-6">

Watch: *Busy workers vs. capacity* and *Queued requests* while CPU is flat.

</div>

---

# Round 3 — nginx + php-fpm in one Pod

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-4">

<div>

- two app containers, **one scaling unit**
- php-fpm `pm = static`, 10 workers
- extra requests wait in the php-fpm listen backlog

</div>

<div>

```text
Pod
├── nginx      :8080  ─┐ fastcgi
├── php-fpm    :9000  ◄┘
├── nginx-exporter
├── log-exporter
└── fpm-exporter
```

</div>

</div>

<div class="kcd-card kcd-card-danger mt-6">

One Pod, two app containers: which one is the bottleneck? Whose requests did you size?

</div>

---

# Round 4 — Spring MVC, slow startup

- 10 Tomcat threads, accept queue behind them
- JVM start under a 500m CPU limit **+ 30 s warm-up** before readiness
- new Pods arrive after the burst is over

<div class="kcd-card kcd-card-warn mt-6">

Knobs: `min-scale`, Knative `initial-scale`, CPU limits during startup.

</div>

---

# Round 5 — scale to zero

```yaml
autoscaling.knative.dev/min-scale: "0"
imagePullPolicy: Always
```

- idle ~60 s → 0 Pods; the next request waits in the **activator**
- the CPU HPA can't do this at all (no Pod = no CPU metric)
- `Always` adds a registry round-trip to every cold start

<div class="kcd-card mt-6">

Is the cold start worth the saved Pod? Check p99 of the first requests.

</div>

---

# Round 6 — BFF → microservice

```text
k6 ──► BFF (/bff?minWait=…&maxWait=…&timeout=…&backend_timeout=…) ──► backend (/?minWait=…&maxWait=…&timeout=…)
```

- both tiers are the round 2 app, both autoscale independently
- timeouts must **shrink along the chain**: BFF timeout > backend timeout
- otherwise the BFF holds workers for answers nobody waits for

<div class="kcd-card kcd-card-danger mt-6">

Scale the wrong tier and you just move the queue.

</div>

---

# Knobs cheat sheet

<div class="grid grid-cols-2 gap-8 mt-4 text-sm">

<div>

**HPA** (round1-cpu)

- `metrics[].target.averageUtilization`
- `minReplicas` / `maxReplicas`
- `behavior.scaleUp.stabilizationWindowSeconds`, `policies`
- container `resources.requests` (utilization is relative to them!)

</div>

<div>

**Knative (KPA)**

- `autoscaling.knative.dev/target`, `target-utilization-percentage`
- `metric: concurrency | rps`, `containerConcurrency`
- `window`, `panic-window-percentage`, `panic-threshold-percentage`
- `min-scale`, `initial-scale`, `scale-down-delay`

</div>

</div>

---

# Leaderboard 🏆

<div class="mt-6 text-xl">

1. availability **≥ 99.9 %** — otherwise you're out
2. lowest **p99** latency
3. tie-breaker: fewest **avg. app Pods**

</div>

<div class="kcd-source">Draft. All numbers from the "Autoscaling Reality Check" dashboard, one <code>bench-all</code> run - planned: every cluster remote-writes to a central Grafana leaderboard.</div>

---

# Takeaways

<div class="mt-6 text-xl leading-relaxed">

1. **CPU is not throughput.** Scale on what saturates: workers, requests in flight, queue.
2. **Startup time is part of your scaling budget.** A Pod that's ready in 40 s didn't help the 4-minute burst.
3. **Pods are scaling units, not containers.** Sidecars and co-located processes change the math.
4. **Timeouts and autoscaling are one design.** Measure the whole call chain.

</div>

---
class: text-center
---

# Thank you 📈

<div class="mt-4 text-xl">
  Questions? Find me in the hallway.
</div>

<div class="flex flex-col items-center mt-8">
  <QRCode
    :width="220"
    :height="220"
    type="svg"
    data="https://github.com/depeche-io/kubecon-2026-autoscaling-challenge"
    :margin="4"
    :dotsOptions="{ color: '#ffffff' }"
    :backgroundOptions="{ color: '#003a99' }"
  />
  <div class="mt-3 text-lg font-bold">Repo + slides</div>
</div>

<div class="abs-bl m-6 text-sm opacity-75">
  KubeCon + CloudNativeCon North America 2026 · #KubeCon #CloudNativeCon
</div>
