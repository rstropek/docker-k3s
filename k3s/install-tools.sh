#!/usr/bin/env bash
# Installs the two command-line tools for the k3s half day into ~/.local/bin (no sudo):
#   k3d      creates k3s clusters whose nodes are Docker containers
#   kubectl  the Kubernetes client; skipped if you have a recent one already (Docker Desktop brings one)
set -euo pipefail

K3D_VERSION=v5.9.0
KUBECTL_VERSION=v1.36.5

case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

bin=~/.local/bin
mkdir -p "$bin"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if command -v k3d >/dev/null && [[ "$(k3d version | head -1)" == *"$K3D_VERSION"* ]]; then
  echo "k3d $K3D_VERSION is installed already"
else
  curl -fsSLo "$tmp/k3d-linux-$arch" "https://github.com/k3d-io/k3d/releases/download/$K3D_VERSION/k3d-linux-$arch"
  curl -fsSLo "$tmp/checksums.txt" "https://github.com/k3d-io/k3d/releases/download/$K3D_VERSION/checksums.txt"
  echo "$(awk -v f="_dist/k3d-linux-$arch" '$2 == f {print $1}' "$tmp/checksums.txt")  $tmp/k3d-linux-$arch" | sha256sum -c -
  install -m 755 "$tmp/k3d-linux-$arch" "$bin/k3d"
fi

# kubectl may be at most one minor version older than the cluster (k3s 1.36)
minor=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.minor // empty' | tr -dc 0-9)
if [ -n "$minor" ] && [ "$minor" -ge 35 ]; then
  echo "kubectl 1.$minor is installed already: $(command -v kubectl)"
else
  curl -fsSLo "$tmp/kubectl" "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$arch/kubectl"
  echo "$(curl -fsSL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$arch/kubectl.sha256")  $tmp/kubectl" | sha256sum -c -
  install -m 755 "$tmp/kubectl" "$bin/kubectl"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Add ~/.local/bin to your PATH: echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc, then open a new shell" ;;
esac
k3d version
kubectl version --client
