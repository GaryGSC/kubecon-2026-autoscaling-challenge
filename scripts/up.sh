#!/usr/bin/env bash
# Creates the k3d cluster and bootstraps Argo CD from gitops/ - same result as
# `argocd-autopilot repo bootstrap --recover`, but needs no git token (the repo is public).
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=autoscaling
# never touch whatever the current kubectl context points at
K="kubectl --context k3d-$CLUSTER"
TIMEOUT=${TIMEOUT:-900}

if ! k3d cluster get "$CLUSTER" >/dev/null 2>&1; then
  k3d cluster create --config k3d/cluster.yaml
fi

echo "==> Installing Argo CD"
$K create namespace argocd --dry-run=client -o yaml | $K apply -f -
$K apply --server-side --force-conflicts -k gitops/bootstrap/argo-cd
$K -n argocd rollout status deploy/argocd-server deploy/argocd-repo-server deploy/argocd-applicationset-controller --timeout=300s
$K -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "==> Bootstrapping GitOps (autopilot layout)"
$K apply -f gitops/bootstrap/argo-cd.yaml -f gitops/bootstrap/root.yaml -f gitops/bootstrap/cluster-resources.yaml

echo "==> Waiting for platform apps (platform + round 1 in both variants) - up to ${TIMEOUT}s"
APPS="platform-istio platform-knative-serving platform-kube-prometheus-stack platform-benchmark-cpu-hpa platform-benchmark-knative-kpa challenge-cpu-hpa challenge-knative-kpa"
deadline=$((SECONDS + TIMEOUT))
while :; do
  ready=0
  for app in $APPS; do
    status=$($K -n argocd get application "$app" -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
    [ "$status" = "Synced/Healthy" ] && ready=$((ready + 1))
    printf '%-34s %s\n' "$app" "${status:-pending}"
  done
  [ "$ready" -eq "$(echo $APPS | wc -w)" ] && break
  if [ "$SECONDS" -ge "$deadline" ]; then echo "Timed out - check Argo CD UI"; exit 1; fi
  echo "---"; sleep 15
done

cat <<INFO

Ready.
  Argo CD     http://localhost:30080   admin / @utoSc4ling
  Grafana     http://localhost:30030   admin / @utoSc4ling
  Prometheus  http://localhost:30090
  Knative     http://<ksvc>.<namespace>.127.0.0.1.sslip.io:8080
INFO
