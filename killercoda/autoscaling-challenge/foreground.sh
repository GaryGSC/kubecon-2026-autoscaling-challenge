#!/bin/bash
echo "Setting up k3d + Argo CD + Istio + Knative + Prometheus/Grafana (5-10 minutes), full log: /root/setup.log"
tail -n +1 -F /root/setup.log 2>/dev/null | grep --line-buffered -E '^==>|^(platform|challenge)-|^---$|^Ready\.|Timed out' &
while [ ! -f /root/.setup-done ] && [ ! -f /root/.setup-failed ]; do sleep 5; done; kill %1; cd /root/challenge 2>/dev/null; true
