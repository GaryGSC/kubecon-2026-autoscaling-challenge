#!/usr/bin/env bash
# Installs the pinned CLI tools (Linux/macOS, amd64/arm64). Used by Codespaces and Killercoda.
set -euo pipefail

K3D_VERSION=v5.9.0
KUBECTL_VERSION=v1.36.5

OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m); case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
BIN=/usr/local/bin
SUDO=$([ -w "$BIN" ] && echo "" || echo sudo)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

install_bin() { $SUDO install -m 0755 "$1" "$BIN/$2"; echo "installed $2"; }

command -v k3d >/dev/null || {
  curl -fsSLo "$TMP/k3d" "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-${OS}-${ARCH}"
  install_bin "$TMP/k3d" k3d
}

command -v kubectl >/dev/null || {
  curl -fsSLo "$TMP/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
  install_bin "$TMP/kubectl" kubectl
}
