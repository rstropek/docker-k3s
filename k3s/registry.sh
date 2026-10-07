#!/usr/bin/env bash
# The registry from step 12 of the Docker half day, for anyone who starts with the k3s half:
# starts it if it isn't running, logs docker in, and pushes hello-web:1.0 if it's missing.
# Safe to run again; it changes nothing that is already in place.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
if [ "$(docker inspect registry --format '{{.State.Running}}' 2>/dev/null)" != true ]; then
  if docker inspect registry >/dev/null 2>&1; then
    docker start registry
  else
    [ -s "$repo/docker/registry/htpasswd" ] || \
      docker run --rm --entrypoint htpasswd httpd:2.4-alpine -Bbn workshop docker-k3s > "$repo/docker/registry/htpasswd"
    docker run -d --name registry --restart unless-stopped -p 5000:5000 \
      -v workshop-registry-data:/var/lib/registry \
      -v "$repo/docker/registry/htpasswd":/auth/htpasswd:ro \
      -e REGISTRY_AUTH=htpasswd -e REGISTRY_AUTH_HTPASSWD_REALM=workshop -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
      registry:3.1.2
  fi
  sleep 1
fi
echo docker-k3s | docker login localhost:5000 -u workshop --password-stdin
if ! curl -sf -u workshop:docker-k3s localhost:5000/v2/hello-web/tags/list | grep -q '"1.0"'; then
  docker build -q -f "$repo/docker/hello-web/Dockerfile.4-chiseled" -t localhost:5000/hello-web:1.0 "$repo/docker/hello-web"
  docker push localhost:5000/hello-web:1.0
fi
curl -s -u workshop:docker-k3s localhost:5000/v2/_catalog
