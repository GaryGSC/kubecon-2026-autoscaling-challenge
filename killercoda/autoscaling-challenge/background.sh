#!/bin/bash
# Runs in the background while the attendee reads the intro.
set -euo pipefail
exec > /root/setup.log 2>&1
trap 'echo "==> SETUP FAILED - see /root/setup.log"; touch /root/.setup-failed' ERR

echo "==> Installing Docker"
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
echo "==> Cloning the repo"
git clone https://github.com/depeche-io/kubecon-2026-autoscaling-challenge.git /root/challenge
cd /root/challenge
echo "==> Installing CLI tools"
bash bin/install-tools.sh
echo "==> Creating the k3d cluster"
bash bin/up.sh
touch /root/.setup-done
