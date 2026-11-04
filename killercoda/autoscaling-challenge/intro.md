# Autoscaling Reality Check

**How fast can your Pods *really* scale when the traffic hits?**

Ask YouTube, ChatGPT or your vendor how to autoscale on Kubernetes and you get
`kubectl autoscale deployment app --cpu-percent=80` - with a demo app that is nginx, ~5 MB of RAM,
ready in milliseconds, one endpoint, one kind of request.

Your real app is different:

- it takes a minute or two to start, and *Ready* ≠ ready - caches are still warming up
- sidecars bring their own startup and resources
- fast *and* slow requests hit the same endpoint
- a new node takes 2–10 minutes, Black Friday peaks are 10–20× baseline, and a new release changes the performance profile

Scale up and scale down are **different disciplines**. This scenario covers **Pod-level autoscaling only** - single node, no node autoscaling.

## What is being set up

A single-node k3d cluster with:

- **Argo CD** - GitOps, one app + namespace per round
- **Istio + Knative Serving** - the second autoscaler (requests in flight)
- **kube-prometheus-stack** - 5 s scrapes, one Grafana dashboard
- **k6** - the load, as suspended CronJobs

The technology doesn't matter - Flux instead of Argo CD, KEDA instead of Knative, Datadog instead of Prometheus: **same lessons**.

Setup runs in the background and takes 5–10 minutes (`tail -f /root/setup.log`).

> Killercoda environments are small. If Pods stay `Pending`, use the local k3d or Codespaces setup from the
> [README](https://github.com/depeche-io/kubecon-2026-autoscaling-challenge).
