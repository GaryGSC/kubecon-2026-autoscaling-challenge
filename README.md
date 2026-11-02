# Autoscaling Reality Check: The Hands-On HTTP Optimization Challenge

KubeCon + CloudNativeCon North America 2026 tutorial - [session](https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/program/schedule/?id=1250326) by David Pech (Wrike).

You get a pre-configured Pod-level autoscaling setup, hit it with a mixed fast/slow HTTP benchmark and iterate
until the efficiency is no longer terrible. Node-level autoscaling is out of scope - the cluster is a single node.

- **Scenarios / rounds, tuning and links:** [SCENARIOS.md](SCENARIOS.md)
- **Slides:** [slides/](slides/) (`cd slides && npm install && npm run dev`)

## Credentials (public, tutorial only)

| UI | URL (local) | User / password |
|---|---|---|
| Argo CD | http://localhost:30080 | `admin` / `@utoSc4ling` |
| Grafana | http://localhost:30030 | `admin` / `@utoSc4ling` |
| Prometheus | http://localhost:30090 | - |

## Get a cluster

All three options run the same k3d cluster and the same bootstrap (`bin/up.sh`, 5-10 minutes).

### Local k3d

Requirements: Docker with ~4 CPUs / 8 GB RAM free, [k3d](https://k3d.io) v5.9+, kubectl.

```bash
git clone https://github.com/depeche-io/kubecon-2026-autoscaling-challenge.git
cd kubecon-2026-autoscaling-challenge
./bin/up.sh      # creates k3d cluster "autoscaling" and switches kubectl to it
./bin/down.sh    # deletes it
```

`up.sh` itself only talks to the `k3d-autoscaling` context. The docs use `k` for `kubectl` - locally run
`alias k=kubectl` (Codespaces and Killercoda get it from `bin/install-tools.sh`).

### GitHub Codespaces

*Code* -> *Codespaces* -> *Create codespace on main*. The dev container (4 cores / 16 GB) installs the tools
(`bin/install-tools.sh`) and runs `up.sh` on start; ports 30080 / 30030 / 30090 are forwarded and open in a browser tab.

### Killercoda

Scenario in [killercoda/autoscaling-challenge](killercoda/autoscaling-challenge/) (Ubuntu backend, runs `up.sh` in the
background). Killercoda environments are small - fine to follow along, tight for the full stack.

## What's inside

```text
gitops/                 # Argo CD (v3.5.6) - plain Application manifests, Kustomize only for Argo CD's own install
├── bootstrap/          #   Argo CD itself (Kustomize, non-HA, NodePort 30080, admin password) + root app of apps
├── projects/           #   AppProjects: platform, challenge
├── applications/       #   one Application per file, synced by the root app
│   ├── platform-istio.yaml                  # Istio 1.29.10 (base, istiod, ingress gateway), single replica
│   ├── platform-knative-serving.yaml        # Knative Serving + net-istio v1.24.0
│   ├── platform-kube-prometheus-stack.yaml  # 92.17.0, no Alertmanager, 5s scrapes, k6 remote write, dashboard
│   └── challenge-<round>.yaml               # 7 apps (round1-cpu, round1-in-flight, round2..6), one namespace each:
│                                            #   rounds/<round> + the k6-bench chart (CronJobs) in the same app
├── charts/
│   └── k6-bench/       #   local Helm chart: k6 script (files/bench.js) + 4 suspended CronJobs (fast, slow, medium, all)
└── manifests/          #   plain YAML used by the Applications
    ├── knative-serving/    # vendored upstream YAML (HA HPAs/PDBs removed, metrics on) + ServiceMonitors
    └── grafana-dashboard/  # the dashboard ConfigMap
rounds/round1-cpu  rounds/round1-in-flight   # round 1 as CPU HPA / as Knative requests in flight
rounds/round2..6                              # rounds 2-6 as Knative (plain YAML, no Kustomize)
app-go/  app-php/  app-java/             # demo apps (images built by .github/workflows, linux/amd64 + arm64)
k3d/cluster.yaml  bin/  .devcontainer/  killercoda/  slides/
```

Everything runs single-instance (no HA) to leave the most CPU for the tutorial workloads.

### How GitOps is wired

`up.sh` installs Argo CD (`kubectl apply -k gitops/bootstrap/argo-cd` - the only Kustomize in the repo) and applies
`gitops/bootstrap/{argo-cd,root,cluster-resources}.yaml`. The `root` Application then syncs `gitops/projects` and
`gitops/applications`, so a new app is just another `kind: Application` file in `gitops/applications`. Plain YAML
the apps deploy lives in `gitops/manifests`; third-party Helm charts are referenced directly in the Application
(`chart` + `helm.valuesObject`). With a fork, replace the repo URL in `gitops/` first.

The rounds are plain YAML too: apply one by hand with `kubectl apply -n <round> -f rounds/<round>` (e.g. `-n round2 -f rounds/round2`).

## Container images

| App | Image | Workflow |
|---|---|---|
| Go (rounds 2, 6) | `ghcr.io/depeche-io/kubecon-2026-autoscaling-challenge/app-go:main` | `.github/workflows/app-go-image.yml` |
| nginx + php-fpm (round 3) | `ghcr.io/depeche-io/kubecon-2026-autoscaling-challenge/app-php:main` | `.github/workflows/app-php-image.yml` |
| Spring MVC (round 4) | `ghcr.io/depeche-io/kubecon-2026-autoscaling-challenge/app-java:main` | `.github/workflows/app-java-image.yml` |

Multi-arch (`linux/amd64`, `linux/arm64`). GHCR packages are private on first push - make them public in the
package settings. To use another registry, change `IMAGE` in the workflows and the image references in `rounds/`.

## Project status

### How we got here (summary)

The repo was built in one working session, starting from the session abstract:

- **Format** - a KubeCon Tutorial (80 min, hands-on on attendees' laptops). Conference Wi-Fi is unreliable, so
  everything runs locally on a single-node k3d cluster; Codespaces and Killercoda are fallbacks running the same
  `up.sh`. Shared-cloud options (EKS / GKE / OKE, ~$200-475 for a 512 vCPU day) were considered and dropped.
- **Scope** - Pod-level autoscaling only, no node autoscaling. Round 1 in two variants side by side: CPU-based HPA
  (`round1-cpu`) vs. Knative requests-in-flight (`round1-in-flight`); every round (1 in two variants, 2-6) runs at
  the same time in its own namespace and Argo CD app (`challenge-<round>`), together with its own benchmark CronJobs.
- **Platform** - Argo CD with plain `Application` manifests, Istio + Knative, kube-prometheus-stack (no Alertmanager,
  5s scrapes for dense data). Everything single-instance to leave the CPU to the workloads. Public credentials.
- **Benchmark** - k6 with three 90 s scenarios (fast 20 VUs, slow 5, medium 10) plus `all` (the three in series), as
  suspended CronJobs started from the Argo CD UI - no extra UI. Results go to Prometheus via remote write.
- **Rounds** - nginx static (1), Go app with 10 workers (2), nginx + php-fpm as two containers in one Pod (3),
  Spring MVC with slow startup (4), scale to zero + `imagePullPolicy: Always` (5), BFF -> microservice with
  per-request timeouts (6). The demo apps were generated by sub-agents and checked locally (`go vet`, `mvn package`,
  curl tests of worker limits, timeouts and warm-up).
- **Observability** - one Grafana dashboard (resources, k6 client view, availability / latency / CPU & memory
  efficiency / Pod count, nginx, app workers & queues, Knative autoscaler and queue-proxy) and per-round PodMonitors.

### Leaderboard (planned)

Each attendee's local Prometheus will **remote-write to a central Prometheus/Grafana** so all runs can be compared
in one leaderboard dashboard. Draft ranking: availability >= 99.9 % (gate), then lowest p99, then fewest avg. app Pods.

Needed for that:

- a unique `k8s_cluster` value per attendee (today hardcoded to `k3d-autoscaling` in the scrape class and the k6 tags)
- `remoteWrite` in the kube-prometheus-stack values (endpoint + credentials), probably filtered to k6 and a few
  recording rules to keep the traffic small on conference Wi-Fi
- the central stack itself and a leaderboard dashboard

### What is missing / not verified yet

- **Not pushed / no images yet** - Argo CD syncs from GitHub `main`, and the images are built by the workflows
  only after a push. GHCR packages must then be made public.
- **No full end-to-end run** - the platform was deployed on k3d piece by piece (Argo CD login, Istio, Knative,
  kube-prometheus-stack came up), then local Docker storage failed. Not yet run: Argo syncing everything from git,
  any benchmark, rounds 2-6 on a cluster, Grafana with real data.
- **Dashboard queries are unverified** - k6 metric names/units (remote write output) and the Knative >= 1.19
  OpenTelemetry metric names (`kn_*`) come from docs and must be checked against a live Prometheus.
- **Argo CD deep links** in [SCENARIOS.md](SCENARIOS.md) use an assumed `?node=` format - check in Argo CD v3.5.
- **Codespaces and Killercoda** setups are untested; Killercoda resources are likely too small for the full stack.
- **Knative ksvc readiness / scraping** - sidecar metrics are scraped via `__address__` relabeling (Knative allows
  only one declared port); verify the targets come up.
- **Slides** build (`npm run build`) but haven't been reviewed visually; the leaderboard and score are drafts.
- **"Efficiency score"** from the abstract is not defined as a single number yet - the dashboard shows its parts.
- **Memory leak scenario** mentioned in the abstract has no round yet.
