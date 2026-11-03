---
theme: default
colorSchema: 'dark'
title: 'Autoscaling Reality Check'
info: |
  Autoscaling Reality Check: The Hands-On HTTP Optimization Challenge
  KubeCon + CloudNativeCon North America 2026 — David Pech
layout: image
image: /theme/banner.jpeg
backgroundSize: cover
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
  serif: 'Source Serif 4'
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

<!-- cover: the session banner -->

---
layout: center
---

# Who am I

<div class="flex flex-col items-center justify-center gap-6 mt-4">

<img src="/david-pech.jpg" class="rounded-full w-44 h-44 object-cover ring-4 ring-[#B9C6E8] shadow-2xl" />

<div class="text-4xl font-bold tracking-tight">David Pech</div>

<div class="flex items-center gap-12 mt-2">
  <img src="/wrike-logo.svg" class="h-14" style="filter: brightness(0) invert(1);" />
  <img src="/kubestronaut.png" class="h-20" />
</div>

</div>

---

# Once upon a time…

there was a demand to run the cluster *more effectively*. So you ask around:

<div class="mt-6 w-3/4">

<div class="chat"><span class="who human">you:</span> how do I autoscale my app on Kubernetes?</div>
<div class="chat"><span class="who bot">YouTube / ChatGPT / your vendor:</span> super easy!</div>
<div class="chat"><span class="who bot"></span><code>kubectl autoscale deployment app --cpu-percent=80</code></div>
<div class="chat"><span class="who bot"></span>nodes, Pods — it all scales seamlessly 🎉</div>

</div>

<div class="kcd-card kcd-card-bee mt-8 w-3/4">

The demo app: nginx, ~5 MB of RAM, ready in milliseconds, one endpoint, one kind of request.

</div>

---

# …but maybe it's not such a fairy tale

<div class="grid grid-cols-2 gap-8 mt-6">

<div>

**Your app**

- takes a minute or two to start
- *Ready* ≠ ready — caches still warming up
- sidecars with their own startup and resources
- fast *and* slow requests on the same endpoint

</div>

<div>

**Your cluster**

- a new node takes **2–10 minutes**, not 30 s
- scaling up is easy → **90 % of capacity unused**
- Black Friday: peak = 10–20× baseline
- a new release changes the performance profile — one weekend ate months of savings

</div>

</div>

<div class="kcd-card kcd-card-danger mt-8">

Scale up and scale down are **different disciplines**. And every new tool (KEDA, Knative, a service mesh) is something you will run for years.

</div>

---
layout: center
class: section text-center
---

# Let's get some hands-on

## How fast can your Pods *really* scale when the traffic hits?

<div class="mt-6 text-lg opacity-80">Pod-level autoscaling only · single node · no node autoscaling</div>

---

# Get a cluster

<div class="grid grid-cols-[1fr_auto] gap-10 mt-4">

<div>

**Local k3d** — Docker with ~4 CPUs / 8 GB free

```bash
git clone https://github.com/depeche-io/kubecon-2026-autoscaling-challenge
cd kubecon-2026-autoscaling-challenge
./bin/up.sh          # 5-10 minutes
```

**GitHub Codespaces** — *Code* → *Codespaces* → *Create codespace on main* (`up.sh` runs on start)

**Killercoda** — *Autoscaling Reality Check* scenario (tight for the full stack)

<div class="mt-4">

Argo CD <code>:30080</code> · Grafana <code>:30030</code> · Prometheus <code>:30090</code> — <code>admin</code> / <code>@utoSc4ling</code>

</div>

</div>

<div class="flex flex-col items-center">
  <QRCode
    :width="230"
    :height="230"
    type="svg"
    data="https://github.com/depeche-io/kubecon-2026-autoscaling-challenge"
    :margin="6"
    :dotsOptions="{ color: '#113E82' }"
    :backgroundOptions="{ color: '#ffffff' }"
  />
  <div class="mt-2 text-sm opacity-80">github.com/depeche-io/<br/>kubecon-2026-autoscaling-challenge</div>
</div>

</div>

---

# The technology doesn't matter

<div class="grid grid-cols-[1fr_1fr] gap-10 mt-4">

<div>

What's in the box — all of it is **plumbing**:

- **Argo CD** — GitOps
- **Istio + Knative Serving** — the second autoscaler
- **kube-prometheus-stack** — 5 s scrapes, one dashboard
- **k6** — the load, as suspended CronJobs

Flux instead of Argo CD, KEDA instead of Knative, Datadog instead of Prometheus — **same lessons**.

</div>

<div>

```text
k6 Job ──► Service ─────────────► Pods   (round1-cpu, HPA)
       └─► Istio ─► Knative ────► Pods   (all other rounds, KPA)
                         ▲
Prometheus ◄── scrape ───┘  ──►  Grafana
```

<div class="kcd-card kcd-card-bee mt-6">

What we care about: **which signal** you scale on, **how long** a new Pod takes to be useful, **what** is in a Pod, and **how requests wait**.

</div>

</div>

</div>

---

# Seven rounds, side by side

Every round is its own namespace + Argo CD app (`challenge-<round>`), all running at once.

| Round | App | Autoscaler | Lesson |
|---|---|---|---|
| `round1-cpu` | nginx, static page | HPA, CPU 80 % | does CPU tell you anything? |
| `round1-in-flight` | nginx, static page | Knative, 10 in flight | same app, other signal |
| `round2` | Go, 10 workers | Knative | saturation at ~0 % CPU |
| `round3` | nginx + php-fpm, one Pod | Knative | the Pod is the scaling unit |
| `round4` | Spring MVC, 30 s warm-up | Knative | startup time is your budget |
| `round5` | nginx, scale to zero | Knative | cold starts |
| `round6` | BFF → backend | Knative × 2 | timeouts along the chain |

---

# Testing methodology — the benchmark

All scenarios call `http://app.<namespace>/?minWait=<min>&maxWait=<max>` (k6 `constant-vus`):

| Scenario | Duration | Parallel (VUs) | Wait per request |
|---|---:|---:|---|
| `fast` | 120 s | 50 | 10 – 100 ms |
| `slow` | 120 s | 5 | 1 – 3 s |
| `all` | one after another, 240 s | 50 / 5 | mixed |

<div class="grid grid-cols-2 gap-6 mt-6">

<div class="kcd-card">

**Closed model:** each VU sends the next request only after the answer → at most 50 requests in flight. A slow app gets *fewer* requests, not more.

</div>

<div class="kcd-card kcd-card-warn">

**5 s client timeout** — anything slower counts as a failure.

</div>

</div>

---

# Testing methodology — what we measure

<div class="grid grid-cols-2 gap-8 mt-6">

<div class="kcd-card kcd-card-ok">

**User view** (k6)

- availability = success / total
- p50 / p90 / p99 latency

</div>

<div class="kcd-card kcd-card-warn">

**Cost view** (cluster)

- CPU efficiency = usage / requests
- memory efficiency = usage / requests
- avg. number of app Pods

</div>

</div>

<div class="mt-8">

Grafana → *Autoscaling Reality Check* → `namespace` = your round. Plus per-app panels: busy workers, queues, Knative desired vs. actual Pods.

</div>

<div class="mt-6 text-xl text-center">
Good autoscaling = <strong>users don't notice</strong> and you <strong>don't pay for idle</strong>.
</div>

---

# Testing methodology — the loop

<div class="grid grid-cols-[1fr_1fr] gap-10 mt-4">

<div>

1. **Pick** the round — open its Argo CD app
2. **Tune** — autoscaling resource → *Live manifest* → *Edit*<br/>
   <span class="text-sm opacity-80">self-heal is off; *Sync* resets the round</span>
3. **Run** — CronJob `bench-all` → *⋯* → **Create Job**
4. **Read** — Grafana, `namespace` = the round
5. **Tune it** — one knob at a time
6. **Rerun**

```bash
kubectl -n round2 create job --from=cronjob/bench-all bench-$(date +%s)
```

</div>

<div class="kcd-card kcd-card-bee">

**Leaderboard rules** 🏆

1. availability **≥ 99.9 %** — otherwise you're out
2. lowest **p99** latency
3. tie-breaker: fewest **avg. app Pods**

<div class="kcd-source">One <code>bench-all</code> run. Every cluster remote-writes to a central Prometheus — results compared across clusters, anonymized.</div>

</div>

</div>

---

# Round 1 · CPU HorizontalPodAutoscaler — setup

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

- `nginx:1.29-alpine`, the same static page for any `?minWait=&maxWait=` — the waits are **ignored**
- `worker_processes 1`, 512 connections
- nginx: request `50m`, limit `100m`
- + 2 exporter sidecars (`5m`, `25m` requested)
- plain Deployment + Service, no Knative

</div>

```yaml
# rounds/round1-cpu/hpa.yaml
minReplicas: 1
maxReplicas: 10
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 80
behavior:
  scaleDown:
    stabilizationWindowSeconds: 120
```

</div>

---

# Round 1 · CPU HPA — expectations

<div class="text-xl mt-4 leading-loose">

- Does it scale at all? How many Pods at the peak?
- How long until the first new Pod serves traffic?
- 80 % of *what* exactly?
- Does p99 get better with more Pods?

</div>

<div v-click class="guess mt-6">

**My guess:** scales up within ~30–60 s and keeps going toward 10 — nginx is pinned at its `100m` limit. Utilization is Pod usage ÷ the **sum of all containers' requests** (80m), so the sidecars count too. Scale-down only 2 min after the run.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 1 · CPU HPA

<div class="mt-6 text-lg">

Argo CD `challenge-round1-cpu` → `bench-all` → **Create Job** · Grafana `namespace=round1-cpu`

</div>

---

# Round 1 · CPU HPA — results

<Shot src="/results/round1-cpu.png" />

---

# Round 1 · CPU HPA — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- **Right-size requests** — utilization is relative to them; wrong requests = wrong scaling
- **`type: ContainerResource`** on `nginx` — ignore the sidecars
- drop the CPU **limit** — throttling makes latency, not throughput
- `worker_processes auto`

</div>

<div>

- `behavior.scaleUp` policies — how many Pods per period
- higher `minReplicas` instead of reacting
- do you need to scale at all? One nginx with a full CPU beats ten throttled ones

</div>

</div>

---

# Round 1 · requests in flight — setup

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

- the **same nginx** Pod as `round1-cpu`
- Knative Service instead of Deployment + HPA
- KPA scales on **concurrency** (requests in flight per Pod), measured by the queue-proxy sidecar
- no `containerConcurrency` limit (0 = unlimited)

</div>

```yaml
# rounds/round1-in-flight/ksvc.yaml
autoscaling.knative.dev/class: kpa.autoscaling.knative.dev
autoscaling.knative.dev/metric: concurrency
autoscaling.knative.dev/target: "10"
autoscaling.knative.dev/window: "60s"
autoscaling.knative.dev/min-scale: "1"
autoscaling.knative.dev/max-scale: "10"
```

</div>

---

# Round 1 · requests in flight — expectations

<div class="text-xl mt-4 leading-loose">

- 50 VUs, target 10 → how many Pods?
- Does CPU matter at all now?
- Same app as `round1-cpu` — same result?

</div>

<div v-click class="guess mt-6">

**My guess:** 2–3 Pods. Requests take ~1 ms, so few of them are *in flight* at once even with 50 VUs. The real target is 10 × 70 % (`target-utilization-percentage` default) = **7**. KPA reacts to load, not to CPU — the throttled nginx doesn't trigger anything.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 1 · requests in flight

<div class="mt-6 text-lg">

Argo CD `challenge-round1-in-flight` → `bench-all` → **Create Job** · Grafana `namespace=round1-in-flight`

</div>

---

# Round 1 · requests in flight — results

<Shot src="/results/round1-in-flight.png" />

---

# Round 1 · requests in flight — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- set `target` to what one Pod **really** handles — measure it
- `target-utilization-percentage` — headroom vs. Pods
- `metric: rps` for uniform, short requests
- `containerConcurrency` — hard limit, the rest waits in the activator

</div>

<div>

- `window` — shorter reacts faster, flaps more
- panic settings — next slides
- compare with `round1-cpu`: same app, two signals, which one is right?

</div>

</div>

---

# Knative — the request flow

<div class="grid grid-cols-[3fr_2fr] gap-6 mt-2 items-center">

<div class="diagram-card">
  <img src="/knative-request-flow.png" />
</div>

<div class="text-sm">

- **Queue-proxy** sidecar counts requests in flight, enforces `containerConcurrency`, reports to the autoscaler
- **Activator** buffers requests when there are too few (or zero) Pods and pokes the autoscaler
- **Proxy mode** — activator in the path when<br/>`demand + target-burst-capacity > Pods × target`
- **Serve mode** — enough spare capacity, router → Pods directly
- `target-burst-capacity` default **200**; `-1` = activator always in the path

</div>

</div>

<div class="kcd-source">Diagram: knative.dev/docs/serving/request-flow (CC BY 4.0)</div>

---

# Knative — stable vs. panic window

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

- **Stable mode** — average concurrency over the **60 s** window
- **Panic window** = 10 % of it = **6 s**
- **Panic** when the 6 s window wants **≥ 200 %** of the ready Pods
- in panic: scale on the 6 s average, **never scale down**
- back to stable after a full stable window without the need

</div>

<div class="text-sm">

| Setting | Default | Annotation |
|---|---:|---|
| `stable-window` | 60s | `…/window` |
| `panic-window-percentage` | 10 | `…/panic-window-percentage` |
| `panic-threshold-percentage` | 200 | `…/panic-threshold-percentage` |

<div class="text-sm mt-3 opacity-80">

Global: ConfigMap `config-autoscaler` in `knative-serving`. Per revision: `autoscaling.knative.dev/*` annotations on the template.

</div>

</div>

</div>

<div class="kcd-card kcd-card-bee mt-3 text-sm">

Panic is Knative's answer to bursts: react within seconds, then hold the Pods. HPA's closest knob is `behavior.scaleUp`.

</div>

---

# Round 2 · Go, 10 workers — setup

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

```go
sem <- struct{}{}                   // one of WORKERS (10) slots
time.Sleep(rand(minWait..maxWait))  // I/O-like wait, no CPU
<-sem
```

- 10 requests in flight per Pod, the rest **queue** inside the app
- request `50m`, limit `200m`
- Knative, target 10, min 1, max 10

</div>

<div class="kcd-card kcd-card-warn">

Think: a DB connection pool, a thread pool, a downstream API. The app is **full** long before the CPU is busy.

</div>

</div>

---

# Round 2 · Go, 10 workers — expectations

<div class="text-xl mt-4 leading-loose">

- What would a CPU HPA do here?
- `fast`: 50 VUs × ~55 ms — how many Pods?
- `slow`: 5 VUs × 1–3 s — queue or not?
- Where do the requests wait?

</div>

<div v-click class="guess mt-6">

**My guess:** CPU stays near zero — a CPU HPA would **never** scale. Knative sees the requests in flight: ~7–8 Pods during `fast` (50 in flight ÷ 7), 1 Pod is enough for `slow` (5 in flight < 10 workers). p99 ≈ the wait itself, unless Pods arrive late.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 2 · Go, 10 workers

<div class="mt-6 text-lg">

Argo CD `challenge-round2` → `bench-all` → **Create Job** · Grafana `namespace=round2`

</div>

---

# Round 2 · Go, 10 workers — results

<Shot src="/results/round2.png" />

---

# Round 2 · Go, 10 workers — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- `target` = `WORKERS` — **match the app's real capacity**
- `containerConcurrency: 10` — the queue moves from the app to the activator, which can route to new Pods
- `target-utilization-percentage` — how early to add a Pod

</div>

<div>

- `WORKERS` itself — more slots per Pod, fewer Pods?
- `min-scale` for the known baseline
- watch *Busy workers vs. capacity* and *Queued requests*, not CPU

</div>

</div>

---

# Round 3 · nginx + php-fpm — setup

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

- **two app containers**, one scaling unit
- php-fpm `pm = static`, `FPM_WORKERS=10`
- extra requests wait in the php-fpm **listen backlog**
- Knative, target 10

</div>

```text
Pod                       requests
├── nginx      :8080 ─┐     50m
├── php-fpm    :9000 ◄┘     50m   (10 workers)
├── nginx-exporter           5m
├── log-exporter            25m
├── fpm-exporter             5m
└── queue-proxy (Knative)
```

</div>

---

# Round 3 · nginx + php-fpm — expectations

<div class="text-xl mt-4 leading-loose">

- Which container is the bottleneck?
- What does one more replica cost?
- What would a CPU HPA average over?

</div>

<div v-click class="guess mt-6">

**My guess:** behaves like round 2 — php-fpm's 10 workers are the limit, nginx is idle. But every replica brings 5 containers + queue-proxy: ~135m requested per Pod. A CPU HPA would average idle nginx and sidecars into the signal.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 3 · nginx + php-fpm

<div class="mt-6 text-lg">

Argo CD `challenge-round3` → `bench-all` → **Create Job** · Grafana `namespace=round3`

</div>

---

# Round 3 · nginx + php-fpm — results

<Shot src="/results/round3.png" />

---

# Round 3 · nginx + php-fpm — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- `target` = `FPM_WORKERS` — the worker pool is the capacity
- right-size **per container** — nginx and the exporters need little
- fewer sidecars per replica — do you need all of them?

</div>

<div>

- `pm = dynamic` vs. `static` — memory vs. readiness
- CPU HPA? → `ContainerResource` on `php-fpm`
- watch *php-fpm listen queue* and *busy vs. capacity*

</div>

</div>

---

# Round 4 · Spring MVC — setup

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

- Spring MVC, `TOMCAT_THREADS=10` + accept queue
- JVM start under a **500m CPU limit**
- `STARTUP_DELAY_SECONDS=30` warm-up before readiness
- request `250m` / `256Mi`, limit `500m` / `384Mi`
- Knative, target 10

</div>

<div class="kcd-card kcd-card-warn">

The usual enterprise app: slow JVM start, caches to fill, *Ready* only after warm-up.

</div>

</div>

---

# Round 4 · Spring MVC — expectations

<div class="text-xl mt-4 leading-loose">

- How long from "scale up" to a Pod serving traffic?
- How much of the 120 s burst is left by then?
- Does panic mode help?

</div>

<div v-click class="guess mt-6">

**My guess:** 45–60 s per new Pod (JVM boot under the limit + 30 s warm-up). Panic asks for Pods within seconds, they arrive when half the burst is over — p99 spikes, then Pods stay for a minute after.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 4 · Spring MVC

<div class="mt-6 text-lg">

Argo CD `challenge-round4` → `bench-all` → **Create Job** · Grafana `namespace=round4`

</div>

---

# Round 4 · Spring MVC — results

<Shot src="/results/round4.png" />

---

# Round 4 · Spring MVC — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- `min-scale` — pay for headroom you can't create in time
- `initial-scale`, `scale-down-delay` — keep expensive Pods around
- lower `target` / utilization → scale **earlier**

</div>

<div>

- more CPU during startup (no limit, in-place resize)
- shorter warm-up — cache from a shared store, CDS / CRaC
- startup time is part of your scaling budget — **measure it**

</div>

</div>

---

# Round 5 · scale to zero — setup

<div class="grid grid-cols-[1fr_1fr] gap-8 mt-2">

<div>

- round 1 nginx again
- `min-scale: "0"` — idle ~60 s → **0 Pods**
- `imagePullPolicy: Always` on all 3 containers
- next request waits in the **activator** for a cold start

</div>

```yaml
# rounds/round5/ksvc.yaml
autoscaling.knative.dev/min-scale: "0"
autoscaling.knative.dev/max-scale: "10"
...
image: nginx:1.29-alpine
imagePullPolicy: Always
```

</div>

<div class="kcd-source">A CPU HPA can't do this: no Pod = no CPU metric (<code>minReplicas: 0</code> needs the alpha <code>HPAScaleToZero</code> gate).</div>

---

# Round 5 · scale to zero — expectations

<div class="text-xl mt-4 leading-loose">

- How long does the first request wait?
- How many requests pay the cold start?
- What does it do to p99?
- Is one 80m Pod worth it?

</div>

<div v-click class="guess mt-6">

**My guess:** 2–5 s for the first ~50 requests (one per VU) — registry round-trip × 3 images, container start, readiness. Images stay cached on one node, so this is the *good* case. p99 of a short run is mostly cold start.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 5 · scale to zero

<div class="mt-6 text-lg">

Argo CD `challenge-round5` → wait for 0 Pods → `bench-all` → **Create Job** · Grafana `namespace=round5`

</div>

---

# Round 5 · scale to zero — results

<Shot src="/results/round5.png" />

---

# Round 5 · scale to zero — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- `min-scale: "1"` — honestly, usually the answer
- `imagePullPolicy: IfNotPresent`, smaller images
- fewer containers to start

</div>

<div>

- `scale-to-zero-pod-retention-period`, `scale-down-delay` — stay warm longer
- scale to zero where nobody waits: previews, batch, dev
- cherry on top — only after everything else works

</div>

</div>

---

# Round 6 · BFF → backend — setup

```text
k6 ──► BFF (app, MODE=bff, 10 workers) ──► backend (10 workers, sleeps minWait..maxWait)
        TIMEOUT_MS=3000                      deadline: BACKEND_TIMEOUT_MS=2500
```

<div class="grid grid-cols-2 gap-8 mt-6">

<div>

- both tiers = the round 2 Go app
- two Knative Services, **autoscale independently**, target 10 each
- per-request override: `?timeout=` / `?backend_timeout=`

</div>

<div class="kcd-card kcd-card-danger">

The BFF holds a worker while it waits for the backend. A stuck backend fills the BFF too.

</div>

</div>

---

# Round 6 · BFF → backend — expectations

<div class="text-xl mt-4 leading-loose">

- Which tier saturates first?
- `slow` waits 1–3 s, backend deadline 2.5 s — what happens?
- Scale only the BFF — does it help?

</div>

<div v-click class="guess mt-6">

**My guess:** ~¼ of the `slow` requests (wait > 2.5 s) end as **504** — that's the config, not autoscaling. Both tiers scale on requests in flight; scaling just one only moves the queue.

</div>

---
layout: center
class: section text-center
---

# 🎬 Demo time

## Round 6 · BFF → backend

<div class="mt-6 text-lg">

Argo CD `challenge-round6` → `bench-all` → **Create Job** · Grafana `namespace=round6`

</div>

---

# Round 6 · BFF → backend — results

<Shot src="/results/round6.png" />

---

# Round 6 · BFF → backend — how to improve

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

- timeouts **shrink along the chain**: client > BFF > backend
- timeouts follow the SLO, not the defaults
- propagate deadlines — don't work for callers who are gone (499)

</div>

<div>

- `target` and `WORKERS` per tier
- retries need a budget, or they multiply load
- watch *BFF → backend calls by result* (`timeout` vs. `504`)

</div>

</div>

---

# Leaderboard 🏆

<div class="mt-6 text-xl">

1. availability **≥ 99.9 %** — otherwise you're out
2. lowest **p99** latency
3. tie-breaker: fewest **avg. app Pods**

</div>

<div class="kcd-source">One <code>bench-all</code> run. Every cluster remote-writes to a central Prometheus — results compared across clusters, anonymized.</div>

---

# Takeaways

<div class="mt-6 text-xl leading-relaxed">

1. **CPU is not throughput.** Scale on what saturates: workers, requests in flight, queue.
2. **Startup time is part of your scaling budget.** A Pod that's ready in 40 s didn't help the 2-minute burst.
3. **Pods are scaling units, not containers.** Sidecars and co-located processes change the math.
4. **Timeouts and autoscaling are one design.** Measure the whole call chain.

</div>

---
layout: center
class: section text-center
---

# Thank you 📈

<div class="mt-2 text-xl">
  Questions? Find me in the hallway.
</div>

<div class="flex flex-col items-center mt-6">
  <QRCode
    :width="200"
    :height="200"
    type="svg"
    data="https://github.com/depeche-io/kubecon-2026-autoscaling-challenge"
    :margin="6"
    :dotsOptions="{ color: '#113E82' }"
    :backgroundOptions="{ color: '#ffffff' }"
  />
  <div class="mt-3 text-lg font-bold">Repo + slides</div>
</div>
