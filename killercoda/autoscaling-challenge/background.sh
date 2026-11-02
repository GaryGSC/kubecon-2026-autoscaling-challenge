#!/bin/bash
# Runs in the background while the attendee reads the intro.
set -euo pipefail
exec > /root/setup.log 2>&1

command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
git clone https://github.com/depeche-io/kubecon-2026-autoscaling-challenge.git /root/challenge
cd /root/challenge
bash bin/install-tools.sh
bash bin/up.sh
touch /root/.setup-done
