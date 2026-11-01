# autoscaling demo app

Tiny HTTP server with a fixed worker pool. Each request sleeps `ms` milliseconds
(I/O-like wait, no CPU). Only `WORKERS` requests run at once; the rest queue.
Throughput is capped while CPU stays near zero, so CPU-based HPA won't notice.

Env: `PORT` (default 8080), `WORKERS` (default 10), `BACKEND_URL` (default `http://backend`, used by `/bff`),
`MODE=bff` (serve the BFF on `/` too - the k6 benchmark always calls `/?ms=`),
`TIMEOUT_MS` / `BACKEND_TIMEOUT_MS` (defaults for `?timeout=` / `?backend_timeout=` when the request has none; 0 = no timeout).

Endpoints:

- `/?ms=N&timeout=T`: sleeps N ms (clamped 0..30000) on a worker. `timeout` (ms, 0/missing = none)
  covers queue wait + work; on expiry the worker is released and the answer is `504 timeout after Tms`.
- `/bff?ms=N&timeout=T&backend_timeout=BT`: takes a worker from the same pool and holds it while calling
  `${BACKEND_URL}/?ms=N&timeout=BT` (a BFF thread blocked on I/O). `timeout` = BFF deadline (queue wait + backend call).
- `/healthz`, `/metrics`.

```
client --> /bff (WORKERS, timeout=T) --> backend: Deployment of this same app, "/" (WORKERS, timeout=BT)
```

Run the backend as a second Deployment/Service named `backend` (same image) and the BFF with `BACKEND_URL` pointing at it.

Status codes of `/bff`:

| Result | Code | Body |
|---|---|---|
| backend 200 | 200 | `bff ok: <backend body>` |
| BFF deadline `T` fires (queued or waiting for backend) | 504 | `bff timeout after Tms` |
| backend answered non-200 (e.g. its own 504 from `BT`) | 502 | `backend returned <code>` |
| connection error | 502 | `backend error` |

So 504 means "my own deadline fired", 502 means "the backend failed first". A client that disconnects
is counted as `499` (no response written).

Metrics: `app_http_requests_total{handler,code}` and `app_http_request_duration_seconds{handler}`
(`handler` = `work` or `bff`; includes queue time), `app_backend_requests_total{code}` (backend status,
`error` or `timeout`), `app_backend_request_duration_seconds`, `app_requests_in_flight`,
`app_requests_queued`, `app_workers`.

## Lesson: timeouts must shrink along the call chain

Use BFF `timeout` > backend `timeout` (`T > BT`, leave room for queueing and network). If the BFF
gives up first, the backend keeps working (and holding its workers) for a result nobody waits for;
the BFF's workers are also freed while the backend's are still busy, so load amplifies downstream.
With `BT < T` the backend answers 504 itself and the BFF returns a clean 502.

Retries and timeouts also interact with autoscaling of both tiers: a timed-out request that is retried
adds load to a tier that is already saturated, and each tier scales on its own signal (queued/in-flight,
not CPU). Scaling the BFF alone just moves the queue to the backend.

```sh
go run .
curl 'localhost:8080/?ms=200'
curl localhost:8080/healthz
curl -s localhost:8080/metrics | grep ^app_
```
