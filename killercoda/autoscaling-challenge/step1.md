# Explore the platform

Open the UIs (credentials are public for the tutorial: `admin` / `@utoSc4ling`):

- [Argo CD]({{TRAFFIC_HOST1_30080}})
- [Grafana]({{TRAFFIC_HOST1_30030}}) - dashboard **Autoscaling Reality Check**
- [Prometheus]({{TRAFFIC_HOST1_30090}})

All rounds are deployed by Argo CD, one app and namespace each: `challenge-round1-cpu`, `challenge-round1-in-flight`,
`challenge-round2` ... `challenge-round6`.

Run a benchmark: Argo CD -> `challenge-round1-cpu` -> CronJob `bench-all` -> **Create Job**, or:

```
kubectl -n round1-cpu create job --from=cronjob/bench-all bench-all-$(date +%s)
```{{exec}}
