# Projects

Argo CD `AppProject`s, synced by the `root` Application together with `gitops/applications`.

`platform` holds the shared tutorial platform: Istio, Knative Serving and kube-prometheus-stack.

`challenge` holds one app per round (`challenge-round1-cpu`, `challenge-round2` .. `challenge-round6`), each deployed into its own namespace together with the k6 benchmark CronJobs (`gitops/charts/k6-bench`).
