# Autoscaling Reality Check

You get a single-node Kubernetes cluster (k3d) with:

- **Argo CD** managing the platform (plain `Application` manifests in `gitops/`)
- **Istio + Knative Serving** for requests-in-flight autoscaling
- **kube-prometheus-stack** (Prometheus + Grafana)
- **k6 benchmarks** as suspended CronJobs - started from each round's Argo CD app

Setup runs in the background and takes 5-10 minutes (`tail -f /root/setup.log`).

> Killercoda environments are small. If Pods stay `Pending`, use the local k3d or Codespaces setup from the README.
