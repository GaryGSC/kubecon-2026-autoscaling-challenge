# The platform and the benchmark

## Open the UIs

Login `admin` / `@utoSc4ling` (public, tutorial only):

- [Argo CD]({{TRAFFIC_HOST1_30080}}) - port `30080`
- [Grafana]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge) - dashboard **Autoscaling Reality Check**, port `30030`
- [Prometheus]({{TRAFFIC_HOST1_30090}}) - port `30090`

All three are NodePorts on `controlplane`; the links use Killercoda's traffic port forwarding.

## Six rounds, side by side

Every round is its own namespace + Argo CD app (`challenge-<round>`), all running at once.

| Round | App | Autoscaler | Lesson |
|---|---|---|---|
| `round1-cpu` | nginx, static page | HPA, CPU 80 % | does CPU tell you anything? |
| `round2` | Go, 10 workers | Knative | saturation at ~0 % CPU |
| `round3` | nginx + php-fpm, one Pod | Knative | the Pod is the scaling unit |
| `round4` | Spring MVC, 30 s warm-up | Knative | startup time is your budget |
| `round5` | nginx, scale to zero | Knative | cold starts |
| `round6` | BFF → backend | Knative × 2 | timeouts along the chain |

## The benchmark

All scenarios call `http://app.<namespace>/?minWait=<min>&maxWait=<max>` (k6 `constant-vus`):

| Scenario | Duration | Parallel (VUs) | Wait per request |
|---|---:|---:|---|
| `fast` | 120 s | 50 | 10 – 100 ms |
| `slow` | 120 s | 5 | 1 – 3 s |
| `all` | one after another, 240 s | 50 / 5 | mixed |

- **Closed model:** each VU sends the next request only after the answer → at most 50 requests in flight. A slow app gets *fewer* requests, not more.
- **5 s client timeout** - anything slower counts as a failure.

## What we measure

- **User view** (k6): availability = success / total, p50 / p90 / p99 latency
- **Cost view** (cluster): CPU and memory efficiency = usage / limits, avg. number of app Pods

Good autoscaling = **users don't notice** and you **don't pay for idle**.

## The loop

1. **Pick** the round - open its Argo CD app
2. **Run** - CronJob `bench-all` → *⋯* → **Create Job**
3. **Read** - Grafana, `namespace` = the round
4. **Tune** - autoscaling resource → *Live manifest* → *Edit* (self-heal is off; *Sync* resets the round)
5. **Rerun**

Starting a benchmark from the terminal works too:

```
kubectl -n round1-cpu create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{copy}}
