// Tiny demo app: a fixed pool of workers serving I/O-like (sleeping) requests.
// Throughput is capped by WORKERS while CPU stays near zero.
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"math/rand/v2"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	buckets  = []float64{.01, .025, .05, .1, .25, .5, 1, 1.5, 2, 3, 5, 10}
	requests = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "app_http_requests_total", Help: "Requests by handler and status code (499 = client left)."}, []string{"handler", "code"})
	duration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name: "app_http_request_duration_seconds", Help: "Total request time including queueing.",
		Buckets: buckets}, []string{"handler"})
	backendReqs = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "app_backend_requests_total", Help: "Downstream calls by status code, error or timeout."}, []string{"code"})
	backendDur = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name: "app_backend_request_duration_seconds", Help: "Downstream call time.", Buckets: buckets})
	inFlight = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "app_requests_in_flight", Help: "Requests currently holding a worker."})
	queued = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "app_requests_queued", Help: "Requests waiting for a worker."})
	workersG = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "app_workers", Help: "Configured worker limit."})

	backendURL = "http://backend"
	// defaults when the request has no ?timeout= / ?backend_timeout= (0 = none)
	defaultTimeout, defaultBackendTimeout int
	client                                = &http.Client{Transport: &http.Transport{MaxIdleConnsPerHost: 100, IdleConnTimeout: 90 * time.Second}}
)

func envInt(key string, def int) int {
	if n, err := strconv.Atoi(os.Getenv(key)); err == nil && n > 0 {
		return n
	}
	return def
}

// handle wraps a job with the shared worker pool: ?minWait=A&maxWait=B (random wait in [A,B]), ?timeout=T (queue wait + job).
func handle(name string, sem chan struct{}, job func(ctx context.Context, r *http.Request, ms int, wait time.Duration) (int, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		q := r.URL.Query()
		minWait, _ := strconv.Atoi(q.Get("minWait"))
		maxWait, _ := strconv.Atoi(q.Get("maxWait"))
		minWait = max(0, min(minWait, 30000))
		maxWait = max(minWait, min(maxWait, 30000))
		ms := minWait + rand.IntN(maxWait-minWait+1)
		timeout, err := strconv.Atoi(q.Get("timeout"))
		if err != nil {
			timeout = defaultTimeout
		}
		ctx := r.Context()
		if timeout > 0 {
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(ctx, time.Duration(timeout)*time.Millisecond)
			defer cancel()
		}
		prefix := ""
		if name == "bff" {
			prefix = "bff "
		}

		code, body := 0, ""
		queued.Inc()
		select {
		case sem <- struct{}{}: // got a worker
			queued.Dec()
			inFlight.Inc()
			wait := time.Since(start)
			code, body = job(ctx, r, ms, wait)
			inFlight.Dec()
			<-sem // released on success AND on timeout
		case <-ctx.Done(): // gave up while waiting
			queued.Dec()
		}
		if code == 0 { // deadline hit in queue or inside job
			code, body = 504, fmt.Sprintf("%stimeout after %dms\n", prefix, timeout)
		}
		if r.Context().Err() != nil { // client disconnected: nobody to answer
			code = 499
		} else {
			w.WriteHeader(code)
			fmt.Fprint(w, body)
		}
		requests.WithLabelValues(name, strconv.Itoa(code)).Inc()
		duration.WithLabelValues(name).Observe(time.Since(start).Seconds())
	}
}

// sleepJob is I/O-like work: no CPU. Returns 0 if the deadline fires first.
func sleepJob(ctx context.Context, _ *http.Request, ms int, wait time.Duration) (int, string) {
	select {
	case <-time.After(time.Duration(ms) * time.Millisecond):
		return 200, fmt.Sprintf("waited %dms (queued %dms)\n", ms, wait.Milliseconds())
	case <-ctx.Done():
		return 0, ""
	}
}

// bffJob holds its worker while blocked on the backend (like a thread waiting on I/O).
func bffJob(ctx context.Context, r *http.Request, ms int, _ time.Duration) (int, string) {
	url := fmt.Sprintf("%s/?minWait=%d&maxWait=%d", backendURL, ms, ms)
	bt, err := strconv.Atoi(r.URL.Query().Get("backend_timeout"))
	if err != nil {
		bt = defaultBackendTimeout
	}
	if bt > 0 {
		url += fmt.Sprintf("&timeout=%d", bt)
	}
	start := time.Now()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	resp, err := client.Do(req)
	var b []byte
	code := "error"
	if err == nil {
		b, err = io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		resp.Body.Close()
		code = strconv.Itoa(resp.StatusCode)
	}
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		code, err = "timeout", ctx.Err()
	}
	backendReqs.WithLabelValues(code).Inc()
	backendDur.Observe(time.Since(start).Seconds())
	switch {
	case code == "timeout":
		return 0, "" // our own deadline: 504
	case err != nil:
		return 502, "backend error\n"
	case code != "200":
		return 502, "backend returned " + code + "\n"
	}
	return 200, "bff ok: " + string(b)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	workers := envInt("WORKERS", 10)
	prometheus.MustRegister(requests, duration, backendReqs, backendDur, inFlight, queued, workersG)
	workersG.Set(float64(workers))
	if u := os.Getenv("BACKEND_URL"); u != "" {
		backendURL = u
	}
	defaultTimeout = envInt("TIMEOUT_MS", 0)
	defaultBackendTimeout = envInt("BACKEND_TIMEOUT_MS", 0)
	sem := make(chan struct{}, workers) // one pool shared by both handlers

	mux := http.NewServeMux()
	// MODE=bff serves the BFF on "/" too, so the k6 benchmark (always "/?minWait=&maxWait=") can target it
	if os.Getenv("MODE") == "bff" {
		mux.HandleFunc("/", handle("bff", sem, bffJob))
	} else {
		mux.HandleFunc("/", handle("work", sem, sleepJob))
	}
	mux.HandleFunc("/bff", handle("bff", sem, bffJob))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, "ok") })
	mux.Handle("/metrics", promhttp.Handler())

	srv := &http.Server{Addr: ":" + port, Handler: mux}
	go func() {
		log.Printf("listening on :%s with %d workers", port, workers)
		if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, os.Interrupt)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}
