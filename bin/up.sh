#!/usr/bin/env bash
# Creates the k3d cluster, installs Argo CD and applies the bootstrap Applications from gitops/
# (no git token needed, the repo is public).
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

echo "==> Bootstrapping GitOps (root app of apps)"
$K apply -f gitops/bootstrap/argo-cd.yaml -f gitops/bootstrap/root.yaml -f gitops/bootstrap/cluster-resources.yaml

echo "==> Waiting for the apps - up to ${TIMEOUT}s"
# platform apps must be Synced + Healthy; the round apps (one per namespace) only Synced -
# their Knative services keep warming up after that and waiting for all six Healthy would be slow
PLATFORM_APPS="platform-istio platform-knative-serving platform-kube-prometheus-stack"
ROUND_APPS="challenge-round1-cpu challenge-round2 challenge-round3 challenge-round4 challenge-round5 challenge-round6"
deadline=$((SECONDS + TIMEOUT))
while :; do
  ready=0
  for app in $PLATFORM_APPS $ROUND_APPS; do
    status=$($K -n argocd get application "$app" -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
    case " $PLATFORM_APPS " in
      *" $app "*) [ "$status" = "Synced/Healthy" ] && ready=$((ready + 1)) ;;
      *) case "$status" in Synced/*) ready=$((ready + 1)) ;; esac ;;
    esac
    printf '%-34s %s\n' "$app" "${status:-pending}"
  done
  [ "$ready" -eq "$(echo $PLATFORM_APPS $ROUND_APPS | wc -w)" ] && break
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
