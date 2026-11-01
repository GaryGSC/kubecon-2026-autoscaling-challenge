# app-php

Demo app: a Pod with two containers sharing localhost.

- `nginx` (official `nginx:1.29-alpine`, config from `rounds/round3/base/nginx.conf` via ConfigMap) listens on :8080 and forwards to php-fpm at 127.0.0.1:9000.
- `php-fpm` (this image) runs a static pool of `FPM_WORKERS` workers (default 5).

## Endpoints
- `/?ms=N` waits N ms (0..30000, invalid -> 0), returns `waited Nms (pid X)`
- `/healthz` answered by nginx; `/stub_status`, `/fpm-status`, `/fpm-ping` only from 127.0.0.1

## Queueing
Each request occupies one worker for its whole duration. With all workers busy, new requests wait in the php-fpm listen backlog (511) - that is the queue. Max throughput per Pod = FPM_WORKERS / wait time.

## Metrics
- nginx `stub_status` (connections, requests)
- nginx access log `/var/log/nginx/access.log` (format `exporter`, includes `$request_time`) tailed by a log exporter
- php-fpm status `/fpm-status` (active/idle/listen queue), e.g. via hipages/php-fpm_exporter
