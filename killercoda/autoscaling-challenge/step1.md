# Explore the platform

Open the UIs (credentials are public for the tutorial: `admin` / `@utoSc4ling`):

- [Argo CD]({{TRAFFIC_HOST1_30080}})
- [Grafana]({{TRAFFIC_HOST1_30030}}) - dashboard **Autoscaling Reality Check**
- [Prometheus]({{TRAFFIC_HOST1_30090}})

Deploy round 1 in both variants:

```
kubectl apply -k rounds/round1/cpu-hpa
kubectl apply -k rounds/round1/knative-kpa
```{{exec}}

Run a benchmark: Argo CD -> `platform-benchmark-cpu-hpa` -> `bench-all` -> **Create Job**, or:

```
kubectl -n cpu-hpa create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}
