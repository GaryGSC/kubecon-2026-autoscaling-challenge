# Round 1 - CPU HPA

## Setup

- `nginx:1.29-alpine` static page - *the waits are ignored*
- nginx: requests `25m`, limits `100m`
- plain Deployment + Service, no Knative

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

## Expectations

- Does it scale at all? How many Pods at the peak?
- How long until the first new Pod serves traffic?
- 80 % of *what* exactly?
- Does p99 get better with more Pods?

## Run it

- Argo CD: [challenge-round1-cpu]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round1-cpu) → CronJob [`bench-all`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round1-cpu?resource=&node=batch%2FCronJob%2Fround1-cpu%2Fbench-all%2F0) → **Create Job**
- Grafana: [namespace=round1-cpu]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge?var-namespace=round1-cpu)

```
kubectl -n round1-cpu create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}

Look for: one slow startup, whether all Pods serve roughly the same number of requests, and why Pods keep running after the test.

## How to improve

Tune: [HPA `app`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round1-cpu?resource=&node=autoscaling%2FHorizontalPodAutoscaler%2Fround1-cpu%2Fapp%2F0) · [Deployment `app`]({{TRAFFIC_HOST1_30080}}/applications/argocd/challenge-round1-cpu?resource=&node=apps%2FDeployment%2Fround1-cpu%2Fapp%2F0)

- **Right-size requests** - utilization is relative to them; wrong requests = wrong scaling
- drop the CPU **limit** - throttling adds latency, not throughput
- `behavior.scaleUp` policies - how many Pods per period
- higher `minReplicas` instead of reacting
- do you need to scale at all? One nginx with a full CPU beats ten throttled ones
