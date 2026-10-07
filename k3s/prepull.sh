#!/usr/bin/env bash
# Pulls the images the k3s half day needs on the Docker side, so the workshop doesn't depend
# on conference wifi. The cluster's own images (Traefik, CoreDNS, Postgres in the cluster, ...)
# are pulled by the nodes themselves; see "Before the workshop" in the storybook.
set -euo pipefail
images=(
  rancher/k3s:v1.36.5-k3s1
  ghcr.io/k3d-io/k3d-proxy:5.9.0
  ghcr.io/k3d-io/k3d-tools:5.9.0
  registry:3.1.2
  httpd:2.4-alpine
  mcr.microsoft.com/dotnet/sdk:10.0
  mcr.microsoft.com/dotnet/aspnet:10.0
  mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled
)
for i in "${images[@]}"; do echo "pulling $i"; docker pull -q "$i"; done
