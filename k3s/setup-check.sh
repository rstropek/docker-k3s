#!/usr/bin/env bash
# Checks a participant's machine for the k3s half day. Run it in your WSL (Ubuntu) shell.
ok()   { printf '  OK    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
FAILED=0
echo "k3s workshop setup check"
docker version --format '{{.Server.Version}}' >/dev/null 2>&1 && ok "Docker engine reachable: $(docker version --format '{{.Server.Version}}')" || fail "Docker engine not reachable (is Docker Desktop running?)"
command -v k3d >/dev/null && ok "$(k3d version | head -1)" || fail "k3d not found: run ./install-tools.sh"
command -v kubectl >/dev/null && ok "kubectl $(kubectl version --client -o json 2>/dev/null | jq -r .clientVersion.gitVersion)" || fail "kubectl not found: run ./install-tools.sh"
minor=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.minor // empty' | tr -dc 0-9)
[ -n "$minor" ] && [ "$minor" -lt 35 ] && fail "kubectl 1.$minor is too old for k3s 1.36: run ./install-tools.sh, then open a new shell"
for t in curl jq; do command -v $t >/dev/null && ok "$t" || fail "$t missing: sudo apt-get install -y $t"; done
if [ "$(docker inspect registry --format '{{.State.Running}}' 2>/dev/null)" = true ]; then
  ok "registry container is running"
  curl -sf -u workshop:docker-k3s localhost:5000/v2/hello-web/tags/list | grep -q '"1.0"' \
    && ok "localhost:5000/hello-web:1.0 is in the registry" || fail "hello-web:1.0 is not in the registry: run ./registry.sh"
  jq -e '.auths["localhost:5000"]' ~/.docker/config.json >/dev/null 2>&1 \
    && ok "docker is logged in to localhost:5000" || fail "docker is not logged in to localhost:5000: run ./registry.sh"
else
  fail "no registry container: run ./registry.sh (it sets it up as in step 12 of the Docker half day)"
fi
for p in 6550 8000 8080; do
  if (exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null; then
    docker ps --filter name=k3d-workshop-serverlb -q | grep -q . && [ $p != 8080 ] \
      && ok "port $p belongs to the workshop cluster" || fail "port $p is in use (see the ports table in the storybook)"
  else ok "port $p is free"; fi
done
k3d cluster list workshop >/dev/null 2>&1 && echo "  INFO  the cluster 'workshop' exists already (step 2 creates it; 'k3d cluster delete workshop' to start fresh)"
[ $FAILED = 0 ] && echo "All set." || { echo "Please fix the FAIL lines before the workshop."; exit 1; }
