#!/bin/bash
# Runs in the background while the attendee reads the intro.
# Backend kubernetes-kubeadm-1node-4GB: the cluster (node "controlplane") and kubectl are already there.
set -euo pipefail
exec > /root/setup.log 2>&1
trap 'echo "==> SETUP FAILED - see /root/setup.log"; touch /root/.setup-failed' ERR

echo "==> Cloning the repo"
git clone https://github.com/depeche-io/kubecon-2026-autoscaling-challenge.git /root/challenge
cd /root/challenge

# round 1 HPA needs the resource metrics API (k3s ships metrics-server, kubeadm doesn't);
# kubeadm kubelets serve self-signed certs, hence --kubelet-insecure-tls
if ! kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
  echo "==> Installing metrics-server"
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml
  kubectl -n kube-system patch deploy metrics-server --type=json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

KUBE_CONTEXT=$(kubectl config current-context) bash bin/up.sh
touch /root/.setup-done
