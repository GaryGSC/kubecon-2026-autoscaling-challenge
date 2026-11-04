# Round 5 - scale to zero

## Setup

- round 1 nginx again
- `min-scale: "0"` - idle ~60 s → **0 Pods**
- `imagePullPolicy: Always`
- next request waits in the **activator** for a cold start

```yaml
# rounds/round5/ksvc.yaml
autoscaling.knative.dev/min-scale: "0"
autoscaling.knative.dev/max-scale: "10"
...
image: nginx:1.29-alpine
imagePullPolicy: Always
```

A CPU HPA can't do this: no Pod = no CPU metric (`minReplicas: 0` needs the alpha `HPAScaleToZero` gate).

## Expectations

- How long does the first request wait?
- How many requests pay the cold start?
- What does it do to p99?
- Is one idle Pod worth it?

## Run it

Wait for 0 Pods first:

```
kubectl -n round5 get pods -w
```{{exec}}

- Argo CD: [challenge-round5]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round5) → CronJob `bench-all` → **Create Job**
- Grafana: [namespace=round5]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge?var-namespace=round5)

```
kubectl -n round5 create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}

## How to improve

Tune: [Knative Service `app`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round5?resource=&node=serving.knative.dev%2FService%2Fround5%2Fapp%2F0)

- `min-scale: "1"` - honestly, usually the answer
- `imagePullPolicy: IfNotPresent`, smaller images
- `scale-to-zero-pod-retention-period`, `scale-down-delay` - stay warm longer
- scale to zero where nobody waits: previews, batch, dev
- cherry on top - only after everything else works

Knative's edge over HPA: the activator holds the first request while a Pod starts. HPA has no queue - with 0 Pods the request just fails.
