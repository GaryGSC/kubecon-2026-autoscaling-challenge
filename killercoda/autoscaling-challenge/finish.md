# Takeaways

1. **CPU is not throughput.** Scale on what saturates: workers, requests in flight, queue.
2. **Startup time is part of your scaling budget.** A Pod ready after 40 s misses a third of a 2-minute burst.
3. **Pods are scaling units, not containers.** Sidecars and co-located processes change the math.
4. **Timeouts and autoscaling are one design.** Measure the whole call chain.

Compare your rounds in [Grafana]({{TRAFFIC_HOST1_30030}}/d/autoscaling-challenge).

Slides and all manifests: https://github.com/depeche-io/kubecon-2026-autoscaling-challenge
