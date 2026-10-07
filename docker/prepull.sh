#!/usr/bin/env bash
# Pulls every image the Docker half day uses, so the workshop doesn't depend on conference wifi.
set -euo pipefail
images=(
  alpine:3.24
  ubuntu:24.04
  mcr.microsoft.com/dotnet/sdk:10.0
  mcr.microsoft.com/dotnet/aspnet:10.0
  mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled
  postgres:18.6
  registry:3.1.2
  httpd:2.4-alpine
  curlimages/curl:8.22.0
  traefik:v3.7.13
  aquasec/trivy:0.75.0
)
for i in "${images[@]}"; do echo "pulling $i"; docker pull -q "$i"; done
docker image ls --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | head -20
