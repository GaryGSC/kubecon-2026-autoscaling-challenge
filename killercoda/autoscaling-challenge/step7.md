# Round 6 - BFF (Backend-For-Frontend) → backend

## Setup

```text
k6 ──► BFF (app, MODE=bff, 10 workers) ──► backend (10 workers, sleeps minWait..maxWait)
        TIMEOUT_MS=3000                      deadline: BACKEND_TIMEOUT_MS=2500
```

- both tiers = the round 2 Go app
- the BFF does **not** sleep itself - it forwards the wait to the backend
- two Knative Services, **autoscale independently**, target 10 each
- per-request override: `?timeout=` / `?backend_timeout=`

The BFF holds a worker while it waits for the backend. A stuck backend fills the BFF too.

## Expectations

- Which tier saturates first?
- `slow` waits 1–3 s, backend deadline 2.5 s - what happens?
- Scale only the BFF - does it help?

## Run it

- Argo CD: [challenge-round6]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round6) → CronJob `bench-all` → **Create Job**
- Grafana: [namespace=round6]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge?var-namespace=round6)

```
kubectl -n round6 create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}

Look for: errors on slow requests while fast is OK.

- backend (`work`) deadline **2.5 s**, but `slow` waits up to 3 s → ~25 % of requests run out of time
- **`504` Gateway Timeout** - the backend hit its own 2.5 s deadline
- **`502` Bad Gateway** - the BFF got that `504` from upstream and passes it on (its own 3 s deadline never fires)

## How to improve

Tune: [Knative Service `app` (BFF)]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round6?resource=&node=serving.knative.dev%2FService%2Fround6%2Fapp%2F0) · [Knative Service `backend`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round6?resource=&node=serving.knative.dev%2FService%2Fround6%2Fbackend%2F0)

- timeouts **shrink along the chain**: client > BFF > backend
- timeouts follow the SLO, not the defaults
- **backend deadline 2.5 s → 3.1 s** - `slow` waits up to 3 s (quick fix - now backend 3.1 s > BFF 3 s, breaks the rule above)
- propagate deadlines - don't work for callers who are gone (499)
- `target` and `WORKERS` per tier
- retries need a budget, or they multiply load
- watch *BFF → backend calls by result* (`timeout` vs. `504`)

**But** BFF queue + backend queue + 1–3 s work can still exceed the **5 s client timeout**.
