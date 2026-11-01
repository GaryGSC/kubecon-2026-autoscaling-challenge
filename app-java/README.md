# app-java

Tiny Spring Boot 3.5 (Java 21, Spring MVC on Tomcat, no WebFlux, no virtual threads) demo for the autoscaling tutorial.

- `GET :8080/?ms=N` sleeps N ms (clamped 0..30000, invalid -> 0) and returns `waited {ms}ms (thread {name})`.
- Management on `:8081`: `/metrics` (Prometheus), `/health`, `/health/liveness`, `/health/readiness`.

Env vars: `TOMCAT_THREADS` (worker pool, default 10), `TOMCAT_ACCEPT_COUNT` (accept backlog, default 100),
`STARTUP_DELAY_SECONDS` (simulated warm-up, default 30: readiness is 503 until it ends, liveness stays UP).

Key metrics: `http_server_requests_seconds_*` (histogram buckets 10ms..5s), `tomcat_threads_busy_threads`,
`tomcat_threads_config_max_threads`, `jvm_*`.

The lesson:
- Concurrency is capped by the thread pool: 10 sleeping requests saturate a pod at 0% CPU, so CPU-based HPA never fires.
- Extra connections queue in the accept backlog, so latency grows while the pod looks idle.
- JVM startup (even slower under a low CPU limit) plus the warm-up delay means new pods are not ready for a long time, so newly scaled pods help late; scale on busy threads / in-flight requests, early.

Build: `docker build -t app-java .` (image flags: `-XX:MaxRAMPercentage=75 -XX:+UseSerialGC`).
