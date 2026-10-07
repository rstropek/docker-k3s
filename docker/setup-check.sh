#!/usr/bin/env bash
# Checks a participant's machine for the Docker half day. Run it in your WSL (Ubuntu) shell.
ok()   { printf '  OK    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
FAILED=0
echo "Docker workshop setup check"
command -v docker >/dev/null && ok "docker CLI: $(docker version --format '{{.Client.Version}}' 2>/dev/null)" || fail "docker CLI not found (Docker Desktop: Settings > Resources > WSL integration)"
docker version --format '{{.Server.Version}}' >/dev/null 2>&1 && ok "Docker engine reachable: $(docker version --format '{{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})')" || fail "Docker engine not reachable (is Docker Desktop running?)"
docker compose version >/dev/null 2>&1 && ok "$(docker compose version)" || fail "docker compose plugin missing"
for t in curl jq git; do command -v $t >/dev/null && ok "$t" || fail "$t missing: sudo apt-get install -y $t"; done
case "$PWD" in /mnt/*) fail "you are in $PWD: clone the repo into your Linux home (~), not under /mnt/c";; *) ok "working in the Linux filesystem ($PWD)";; esac
for p in 5000 8000 8080 8090; do
  if (exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null; then fail "port $p is in use (see the ports table in the storybook)"; else ok "port $p is free"; fi
done
command -v dotnet >/dev/null && ok "optional: .NET SDK $(dotnet --version)" || echo "  INFO  optional: no .NET SDK in WSL (only needed for step 7: sudo apt-get install -y dotnet-sdk-10.0)"
[ $FAILED = 0 ] && echo "All set." || { echo "Please fix the FAIL lines before the workshop."; exit 1; }
