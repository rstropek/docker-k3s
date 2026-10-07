# Docker and k3s for .NET developers

A hands-on workshop in two separate half days for C# developers who work on Windows:

- **Docker.** What an image, a container, a volume, and a network really are, built
  up from a small ASP.NET Core app to a multi-container setup with Compose and Traefik.
- **k3s.** The same app on a lightweight Kubernetes cluster: Pods, Deployments,
  Services, Ingress, configuration, persistent storage, and troubleshooting.

The goal is not to make everyone a platform engineer. The goal is fundamentals solid enough
that, when a coding agent writes a Dockerfile, a Compose file, or a Kubernetes manifest, you
can read it, judge it, and spot what is wrong.

There are no slides. The workshop consists of small, independent demos with plain `docker`
and `kubectl` commands, run in bash inside WSL against Docker Desktop. Each half day is
written down as a **storybook**: the presenter's guide with every command ready to copy.

## What you will see

**Half day 1: [Docker](docker/storybook.md)** (17 steps)

1. A container is a process, not a small VM
2. Images and containers, layers, and the layer cache
3. Dockerfiles for .NET: from naive to multi-stage to chiseled images, and build arguments
4. Running, watching, and stopping containers, and what happens to PID 1
5. Configuration with environment variables
6. Volumes, registries (a private one, with login), and networks
7. Docker Compose, then Traefik as a reverse proxy in front of several replicas
8. Slim and secure images, and the bridge from Docker to Kubernetes

**Half day 2: [k3s](k3s/storybook.md)** (14 steps)

1. A k3s cluster with three nodes, each node a Docker container (via [k3d](https://k3d.io))
2. What k3s ships with: Traefik, CoreDNS, local storage, a load balancer
3. Pods, manifests, and Deployments; scaling and self-healing, including a node going away
4. Rolling updates without dropped requests, and rolling back a broken one
5. Services and Ingress, ConfigMaps and Secrets
6. PostgreSQL on a PersistentVolumeClaim, and a real app that depends on it
7. Troubleshooting seven broken apps with status, events, and logs

Both half days end with a list of **agent traps**: mistakes that coding agents and tutorials
make often, and what to look for in a review.

## How a storybook works

Each step has a goal, copyable command blocks, talking points for the presenter, and one line
for "if it breaks". Every step can be shown on its own: it creates what it needs and removes
exactly what it created. Three markers recur:

- **Ask first:** a prediction question before a block. The room answers, then the block runs.
- **Your turn:** a minute or two for participants who build along.
- **Agent trap:** a common mistake, collected in the wrap-up step of each half day.

The storybooks are written for a presenter, but they work for self-study too: read the talking
points, guess the answer to each "Ask first" before you run the block.

## Getting started

You need Windows 11 with WSL 2 (Ubuntu 24.04) and Docker Desktop with WSL integration switched
on. Everything else runs in the Ubuntu shell:

```bash
sudo apt-get update && sudo apt-get install -y git curl jq
git clone https://github.com/rstropek/docker-k3s.git ~/docker-k3s

# Docker half day
cd ~/docker-k3s/docker
./setup-check.sh
./prepull.sh              # about 1 GB to download: not over conference wifi

# k3s half day
cd ~/docker-k3s/k3s
./install-tools.sh        # k3d and kubectl into ~/.local/bin, no sudo
./prepull.sh
```

Clone into the Linux home, not under `/mnt/c`. The .NET SDK is not required: all builds run
inside the SDK container image. Details, including the Docker Desktop license conditions, are
in *Before the workshop* of the [Docker](docker/storybook.md#before-the-workshop) and the
[k3s](k3s/storybook.md#before-the-workshop) storybook.

Native Linux with Docker Engine works as well; where Docker Desktop behaves differently, the
storybook says so.

## What is in the repository

| Path | What it is |
| --- | --- |
| [`docker/storybook.md`](docker/storybook.md) | the presenter's guide for the Docker half day |
| [`docker/`](docker) | two small ASP.NET Core apps (`hello-web`, `visit-counter`), a series of Dockerfiles, Compose files, setup scripts |
| [`k3s/storybook.md`](k3s/storybook.md) | the presenter's guide for the k3s half day |
| [`k3s/`](k3s) | the k3d cluster config, the manifests (`hello/`, `visits/`, `troubleshooting/`), setup scripts |
| [`rehearsal/run-blocks.py`](rehearsal/run-blocks.py) | runs every command block of a storybook marked `<!-- run -->` and times each step |

Everything the workshop creates on your machine has a fixed name (`workshop-...`, `hello`,
`registry`, the cluster `workshop`, ...) and is removed by that name. Nothing in here runs
`docker system prune` or any other global cleanup, so your other containers and volumes are
safe.

## Rehearsing

Every runnable block was executed end to end with .NET 10, Docker Engine 29.7, and k3s 1.36.
To check that the demos still work after an image update, run the rehearsal script from the
repository root:

```bash
rehearsal/run-blocks.py --list                          # steps and their runnable blocks
rehearsal/run-blocks.py --step 6 9                      # some steps of the Docker half day
rehearsal/run-blocks.py                                 # the whole Docker half day
rehearsal/run-blocks.py --storybook k3s/storybook.md    # the whole k3s half day
```

The output of each step goes to `rehearsal/logs/`.
