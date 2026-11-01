#!/bin/bash
echo "Setting up k3d + Argo CD + Istio + Knative + Prometheus/Grafana (5-10 minutes)..."
echo "Follow the progress with: tail -f /root/setup.log"
while [ ! -f /root/.setup-done ]; do sleep 5; done
cd /root/challenge
echo "Ready."
