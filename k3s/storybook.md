# Storybook: k3s for .NET developers

**Half day 2 of the Docker and k3s workshop for the MI-SA development team**

This is the presenter's guide, not a book to follow alone. Improvisation is part of the plan. The
audience is experienced C# developers who live on Windows, know a little Linux, and spent
the morning with Docker ([`docker/storybook.md`](../docker/storybook.md)). The goal is the
fundamentals of Kubernetes, shown with k3s: what a Pod, a Deployment, a Service, and a
PersistentVolumeClaim really are, so that later, when a coding agent writes manifests, they
can read and judge them. Details that an agent gets right anyway stay out.

No slides, no agent prompts: small, independent demos with plain `kubectl` commands and
short manifests. Each step has a goal, copyable blocks, talking points, and one line for
"if it breaks". Each step can be shown on its own: its first block applies what it needs
from earlier steps (`kubectl apply` changes nothing that is already in place). The `hello`
app lives from step 5 to step 10 and is removed there; the visit counter (steps 11 and 12)
and the broken apps (step 13) are removed at the end of their steps.

Three recurring markers, as in the morning:

- **Ask first:** a prediction question before a block. Let the room answer, then run it.
  The answer is in the talking points, not in the block.
- **Your turn:** a minute or two for the participants who build along.
- **Agent trap:** a mistake coding agents (and tutorials) make often. They are collected in
  [step 14](#step-14-wrap-up); that list is what the afternoon should leave behind.

**Setup:** Docker Desktop on Windows, every command in **bash inside WSL (Ubuntu)**, the
repository cloned to `~/docker-k3s`, as in the morning. The cluster is **k3s, run by k3d**:
each Kubernetes node is a Docker container, so the cluster needs nothing but Docker, is
created in about 20 seconds, and is gone with one command. It is the same k3s you'd install
on a server; [step 2](#step-2-a-cluster-made-of-containers) says what differs. The cluster
pulls images from the morning's registry at `localhost:5000`.

The demos were rehearsed on 6 October 2026 with k3d 5.9.0, k3s v1.36.5+k3s1, kubectl 1.36,
and Docker Engine 29.7.1 on Linux (x86-64). The rehearsal script
([`rehearsal/run-blocks.py`](../rehearsal/run-blocks.py)) runs every block marked
`<!-- run -->` in order and times it:

```bash
~/docker-k3s/rehearsal/run-blocks.py --storybook k3s/storybook.md
```

## Timing

Machine time per step in the rehearsal: commands only, measured by `run-blocks.py`, with
the images pre-pulled; the cluster's nodes pulled their own images over a fast line.
Everything else in a step is talking, which is the point. A natural break: after step 7,
the end of Part 2.

| Step | Topic | Machine time |
| --- | --- | ---: |
| 1 | setup check | < 1 s (3 s when it recreates the registry) |
| 2 | a cluster made of containers | 18 s |
| 3 | inside the cluster | 44 s (most of it waiting for Traefik: the cluster's first minute) |
| 4 | the first Pod | 5 s |
| 5 | manifests and Deployments | 4 s |
| 6 | scaling and self-healing | 14 s |
| 7 | rolling updates | 29 s (20 s of it is the broken release timing out) |
| 8 | Services | 5 s |
| 9 | Ingress: Traefik again | 7 s |
| 10 | ConfigMaps and Secrets | 22 s |
| 11 | volumes and PersistentVolumeClaims | 28 s |
| 12 | a real deployment: the visit counter | 80 s (20 s of crashing on purpose, the wait for the app's next restart, and deleting the namespace) |
| 13 | troubleshooting | 45 s (30 s of it is waiting for the apps to fail) |
| 14 | wrap-up | 3 s |
| | **total** | **about 5 minutes** |

## Before the workshop

**Participants** (send this a week ahead, together with the morning's list):

- Everything from the morning's "Before the workshop": WSL with Ubuntu, Docker Desktop with
  WSL integration, the repository in `~/docker-k3s`.
- The two tools of the afternoon, into `~/.local/bin` (no sudo), and the images:
  ```bash
  cd ~/docker-k3s/k3s
  ./install-tools.sh    # k3d, and kubectl unless a recent one is installed already
  ./prepull.sh          # k3s and k3d: about 500 MB on disk, on top of the morning's images
  ```
- An editor for YAML in WSL: VS Code with the WSL extension (`code ~/docker-k3s` in the
  Ubuntu shell) and Red Hat's YAML extension, which knows the Kubernetes schema; or `nano`.
  The "Your turn" moments edit manifests.
- Docker Desktop needs about 4 GB of memory for the cluster and the demos. With WSL, Docker
  Desktop gets half of the laptop's memory by default; on an 8 GB laptop, close the browser
  tabs you don't need.

The morning's registry must be running with `hello-web:1.0` in it. Anyone who skipped the
morning, or cleaned it up, gets it back with `./registry.sh`; step 1 runs it anyway.

**Presenter:**

- `../rehearsal/run-blocks.py --storybook k3s/storybook.md --list` to see that the storybook
  and the rehearsal script agree, then a full rehearsal.
- When the cluster is created, its nodes pull the k3s system images (Traefik, CoreDNS, ...)
  and later Postgres from the internet themselves; `prepull.sh` can't help there, because
  every new cluster starts with empty nodes. On weak wifi, create the cluster before the
  break and keep it; or tether.
- Terminal at 20 pt or larger. `kubectl get` output is wide: a smaller font for steps 3 and
  13, or let it wrap.
- Port 8000 free: the morning's Traefik (`docker/compose-traefik`) must be down.

---

# Part 1: the cluster

## Step 1: setup check

**Goal:** everybody has the tools, and the registry from the morning is there.

<!-- run -->
```bash
cd ~/docker-k3s/k3s
./registry.sh          # the morning's registry: starts it only if it isn't running
./setup-check.sh
```

- **Two new tools.** `k3d` creates k3s clusters whose nodes are Docker containers; we use it
  twice today, to create and to delete. `kubectl` is the client for every Kubernetes: k3s,
  AKS in Azure, EKS in AWS. It's to Kubernetes what the `docker` CLI is to the Docker engine:
  it sends requests to an API, and the cluster does the work.
- **The registry stays the bridge.** Everything the cluster runs, it pulls from a registry.
  The image we pushed in the morning, `localhost:5000/hello-web:1.0`, is our first workload.

If it breaks: `k3d` or `kubectl` not found → `./install-tools.sh`, then open a new shell so
`~/.local/bin` is on the `PATH`.

## Step 2: a cluster made of containers

**Goal:** what k3s is, and where kubectl sends its commands.

**Ask first:** we create a Kubernetes cluster with three nodes (three "machines"). How many
new containers will `docker ps` show afterwards?

<!-- run -->
```bash
cd ~/docker-k3s/k3s
cat cluster.yaml
k3d cluster create --config cluster.yaml
docker network connect k3d-workshop registry     # the nodes find the registry by its name, as the app found db this morning
docker ps --filter label=k3d.cluster=workshop --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
```

Where does `kubectl` send its commands?

<!-- run -->
```bash
kubectl config get-contexts
kubectl config current-context
kubectl get nodes -o wide
```

- **The answer:** four, next to the registry and whatever else runs on your laptop. Three
  nodes (one server, two agents) and a small load balancer in front of them, which publishes the Kubernetes API on `127.0.0.1:6550` and HTTP on port
  8000. Each node is a container running `rancher/k3s`, and each node runs its own
  containers inside: containers in containers.
- **What k3s is:** a complete, certified Kubernetes distribution (a CNCF project, started by
  Rancher, now SUSE) in a single binary of about 70 MB. Same API, same `kubectl`, same
  manifests as AKS, EKS, or a "full" Kubernetes. It's lighter because it bundles what other
  distributions leave to you: containerd, networking, DNS, the Traefik ingress controller,
  local storage, a load balancer for Services, and metrics. It stores the cluster state in
  SQLite on a single server, or in etcd for several servers. Used on the edge, on-premises,
  in small clusters, and on developer machines.
- **On a real server**, k3s is one command: `curl -sfL https://get.k3s.io | sh -`. That
  installs a systemd service, writes the kubeconfig to `/etc/rancher/k3s/k3s.yaml`, and
  more nodes join with the same binary, the server's address, and a token. k3d runs exactly
  this binary, in containers, for laptops and CI. Not for production: the nodes are
  privileged containers.
- **Server and agent:** the server runs the control plane: the API that `kubectl` talks to,
  the scheduler that decides which node runs what, the controllers that keep things as you
  declared them, and the datastore. Agents only run workloads. In k3s, the server runs
  workloads, too. Every node runs the **kubelet**, the agent process that starts the
  containers it's given, restarts them, and checks their health.
- **No Docker inside.** Kubernetes talks to a container runtime through an interface (CRI);
  k3s brings containerd. The images are the same OCI images that Docker builds; a cluster
  doesn't care who built them.
- **Contexts:** k3d added the context `k3d-workshop` to `~/.kube/config` and made it the
  current one. Every `kubectl` command goes to the current context, whatever cluster that
  is. Whoever switched on Kubernetes in Docker Desktop sees a second context,
  `docker-desktop`: a live example. **Agent trap:** an agent (or you, at 6 pm) runs
  `kubectl apply` or `kubectl delete` while the current context is a production cluster.
  Check it with `kubectl config current-context`, or pass `--context` explicitly in
  scripts.

If it breaks: "cluster workshop already exists" → fine, continue; or `k3d cluster delete
workshop` and create it again. "port is already allocated" → the morning's Traefik is still
running: `docker compose -f ~/docker-k3s/docker/compose-traefik/compose.yaml down`.

## Step 3: inside the cluster

**Goal:** Kubernetes is an API of resources, and k3s brings its add-ons as ordinary Pods.

<!-- run -->
```bash
until kubectl -n kube-system get deployment traefik > /dev/null 2>&1; do sleep 2; done   # k3s installs Traefik in its first minute
kubectl -n kube-system rollout status deployment/traefik
kubectl get namespaces
kubectl get pods -A -o wide                          # -A: in all namespaces
kubectl -n kube-system get helmcharts                # -n: in this namespace
docker exec k3d-workshop-server-0 crictl ps          # the containers of one node, seen from inside
```

**Ask first:** this morning we built `hello-web` and pushed it. Is the image in the cluster
now?

<!-- run -->
```bash
docker exec k3d-workshop-agent-0 crictl images
docker exec k3d-workshop-agent-0 cat /etc/rancher/k3s/registries.yaml
```

The cluster's built-in documentation:

<!-- run -->
```bash
kubectl api-resources | head -20
kubectl explain deployment.spec.replicas
```

- **Namespaces** are folders for resources. `kube-system` holds what k3s brings: CoreDNS
  (names for Services), Traefik (HTTP routing), the local-path provisioner (volumes),
  metrics-server, and `svclb-traefik` (the load balancer that gives Traefik its port 80 on
  every node). Our workloads go to `default` first, later to a namespace of their own.
- **Helm** is the package manager for manifests: a chart is a set of manifest templates
  with settings. k3s installs Traefik as a chart (the `helm-install-traefik` Pods did that,
  once). Agents will hand you charts; what comes out of them is the kind of manifest we
  read today.
- **`crictl`** is the node's `docker ps`: it shows only the containers on this node. You
  need it only to debug a node; for everything else, ask the API with `kubectl`.
- **The answer:** no. Each node has its own container runtime and its own image store;
  the images on your laptop's Docker don't count. A cluster pulls from a registry, always.
  `registries.yaml` (from `cluster.yaml`) tells the nodes that `localhost:5000` means the
  container `registry`, over plain HTTP, with our user and password. Every node of a real
  cluster needs such a file, or an image pull secret. In AKS, the registry is an Azure
  Container Registry, and the cluster's managed identity is allowed to pull from it.
- **Everything is a resource** with a type (`kind`) and a name: Pod, Deployment, Service,
  Node, Namespace. `kubectl get <type>` lists them, `kubectl describe` explains one,
  `kubectl explain` documents every field. When an agent writes a field you don't know,
  `kubectl explain` is faster than a web search.

If it breaks: Pods in `kube-system` are not all `Running` yet → the cluster is a minute old
and still pulling; `helm-install-traefik` showing `Completed` is normal: it's a one-time
job.

---

# Part 2: workloads

## Step 4: the first Pod

**Goal:** a Pod is the unit Kubernetes runs; on its own, it is not much more than
`docker run`.

<!-- run -->
```bash
kubectl run hello --image=localhost:5000/hello-web:1.0 --port=8080
kubectl wait --for=condition=Ready pod/hello --timeout=60s
kubectl get pod hello -o wide
kubectl logs hello
```

A tunnel from your laptop to the Pod:

<!-- run -->
```bash
kubectl port-forward pod/hello 8080:8080 > /dev/null &     # runs in the background
sleep 1
curl -s localhost:8080 | jq '{message, host, user, memoryLimitMb}'
kill %1                                                    # stop the tunnel
kubectl describe pod hello | tail -8                       # the events of this Pod
```

**Ask first:** we delete this Pod. What happens?

<!-- run -->
```bash
kubectl delete pod hello
kubectl get pods
```

Where manifests come from:

<!-- run -->
```bash
kubectl run hello --image=localhost:5000/hello-web:1.0 --port=8080 --dry-run=client -o yaml
```

- **A Pod** is one or more containers that share a network address and volumes, always on
  one node. Mostly it's one container; the extras are helpers (sidecars). The Pod got its
  own IP (`10.42...`) and its name is the container's host name: `host` in the answer is
  `hello`.
- **`memoryLimitMb`** is the node's memory: no limit set. That changes in the next step.
- **`port-forward`** tunnels through the Kubernetes API: a developer tool for a quick look,
  not how users reach an app (that's steps 8 and 9).
- **The answer:** it's gone, and nothing brings it back. Most of the room knows that after
  the morning; it's the baseline for the next step. A Pod alone is like a container started
  with `docker run`: if it's deleted, or its node dies, it stays gone. (If its process
  crashes, the kubelet restarts the container; more in step 6.) That's why nobody creates
  Pods directly.
- **`--dry-run=client -o yaml`** prints what `kubectl run` would have sent: the Pod as a
  manifest. Every `kubectl` command that creates something can do that, and it's a quick
  way to start a manifest by hand.

If it breaks: `ErrImagePull` or `ImagePullBackOff` → the registry isn't connected to the
cluster's network: `docker network connect k3d-workshop registry` (step 2). Port 8080 in
use → something from the morning still runs there: `docker ps --filter publish=8080`.

## Step 5: manifests and Deployments

**Goal:** declare what you want in a file; the cluster makes it so, and keeps it so.

The manifest ([`hello/deployment.yaml`](hello/deployment.yaml)):

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat deployment.yaml
```

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml
kubectl rollout status deployment/hello
kubectl get deployment,replicaset
kubectl get pods -o wide
kubectl get deployment hello -o yaml | tail -20              # the live object: status, the cluster's half
```

**Ask first:** we delete one of the three Pods. What happens?

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
POD=$(kubectl get pods -l app=hello -o name | head -1); echo "deleting $POD"
kubectl delete $POD --wait=false                   # don't wait until it's gone
kubectl get pods -l app=hello
kubectl apply -f deployment.yaml                   # again: nothing to do
```

**Your turn:** set `replicas: 2` in `deployment.yaml`, `kubectl apply -f deployment.yaml`,
and `kubectl get pods`. Then set it back to 3.

- **Every manifest has the same four parts:** `apiVersion` and `kind` (what type),
  `metadata` (name, namespace, labels), and `spec` (what you want). `status` is the
  cluster's half: what is. `-o yaml` shows the live object: your file, plus the defaults
  the cluster filled in, plus the status. `-o wide`, `-o yaml`, `-o jsonpath`, and
  `-o custom-columns` (from step 6 on) are all views of the same object.
- **Two blocks for later:** the `readinessProbe` is Compose's health check (step 7), and
  `preStop` makes rollouts lose no requests (step 9).
- **Labels connect things.** The Deployment doesn't know its Pods by name: it owns every
  Pod whose labels match its `selector` (`app: hello`). `-l app=hello` in `kubectl` uses
  the same mechanism. The `template` is the Pod from step 4, as a blueprint.
- **The answer:** a new Pod appears at once, with a new name, while the old one is still
  `Terminating`. You declared "three"; a controller in the cluster compares what is with
  what should be, and acts. All of Kubernetes works like this: a loop that reconciles,
  again and again. The names read `hello-<ReplicaSet hash>-<random>`; the hash changes
  with every version (step 7).
- **Deployment → ReplicaSet → Pods.** The ReplicaSet keeps the number; the Deployment
  manages ReplicaSets, one per version. That pays off in step 7.
- **Declarative instead of imperative.** `kubectl run` was a command, like `docker run`.
  `kubectl apply -f` hands over a goal, as often as you like: the second apply reports
  `unchanged`. The files go into Git and through pull requests, like code. That's what you
  want agents to write.
- **Resources:** `requests` is what the scheduler reserves for the Pod on a node; it decides
  where the Pod fits. `limits.memory` is `docker run --memory`: .NET sees it and sizes its
  heap, so `memoryLimitMb` now reports 192 (75% of 256 MiB). **Agent trap:** no requests
  and limits at all; the scheduler then places blindly, and one leaking Pod can starve a
  node.
- **No CPU limit: our choice, not a law.** A CPU limit throttles the container even when
  the node is idle, and .NET sizes its thread pool to it; the request alone already shares
  CPU fairly under load. Many clusters require limits (a LimitRange or a policy), and agents
  add them by default: then know that a limit of `500m` means half a CPU, at most, always.
- **Spread:** the three Pods usually land on different nodes (`NODE` column). The scheduler
  prefers to spread replicas, so one dead node doesn't take all of them.
- **YAML:** indentation is syntax, tabs are forbidden. `kubectl apply` rejects unknown field
  names, but not wrong values: a typo in a label goes through (step 13). `kubectl apply
  --dry-run=server -f` lets the cluster check a file without changing anything, and the
  YAML extension in VS Code underlines unknown fields while you type.

If it breaks: `rollout status` waits forever → `kubectl get pods` shows why; usually
`ImagePullBackOff` (see step 4).

## Step 6: scaling and self-healing

**Goal:** more replicas with one number, and three ways the cluster heals: a deleted Pod,
a crashed process, a node taken out for maintenance.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml
kubectl scale deployment hello --replicas=6
kubectl rollout status deployment/hello
kubectl get pods -l app=hello -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
```

**Ask first:** the file says 3, the cluster now runs 6. What does the next `kubectl apply`
do?

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl diff -f deployment.yaml | grep -E '^[-+] '      # what apply would change; only the changed lines
kubectl apply -f deployment.yaml
kubectl get deployment hello
```

**Ask first:** the app in one Pod crashes (exit code 3, the `/crash` endpoint from the
morning). Do we get a new Pod, or the same one?

<!-- run -->
```bash
kubectl port-forward deployment/hello 8080:8080 > /dev/null &
sleep 1
curl -s localhost:8080/crash; echo
kill %1
sleep 3
kubectl get pods -l app=hello
kubectl describe pods -l app=hello | grep -A4 'Last State'
```

A node goes into maintenance:

<!-- run -->
```bash
kubectl drain k3d-workshop-agent-0 --ignore-daemonsets --delete-emptydir-data
kubectl rollout status deployment/hello
kubectl get pods -l app=hello -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
kubectl get nodes
kubectl uncordon k3d-workshop-agent-0
```

- **Scaling is one number**, `replicas`. The new Pods spread over the nodes. Scaling
  automatically by load is a HorizontalPodAutoscaler; k3s ships the metrics-server it needs.
- **The answer to the first question:** `diff` shows `replicas: 6 → 3` (and a counter of the
  cluster's, `generation`), and `apply` scales back down. The file is the truth. **Agent
  trap:** fixing a cluster with `kubectl scale`, `kubectl edit`, or `kubectl set` and not
  changing the file. The next `apply`, or the next GitOps sync (a tool that applies the Git
  repository continuously, step 14), silently takes it back.
- **The answer to the second question:** the same Pod. The kubelet restarts the crashed
  container in place: `RESTARTS` is 1, and `describe` shows the last state, `Terminated`
  with exit code 3. If it keeps crashing, the waits between restarts grow (10 s, 20 s,
  40 s, up to 5 minutes): that's the famous `CrashLoopBackOff` (step 13).
- **`drain`** is planned maintenance, for example patching the node's OS: no new Pods on
  this node (`SchedulingDisabled`), and the existing ones are evicted and recreated by
  their Deployments elsewhere. Not only ours: whatever ran there moves, Traefik or CoreDNS
  included. `--ignore-daemonsets` leaves the `svclb` Pods alone (a DaemonSet runs one per
  node by design), `--delete-emptydir-data` accepts that Pods lose their scratch folders.
  `uncordon` opens the node again, but nothing moves back by itself: new Pods go there at
  the next rollout.
- **When a node dies unplanned**, it shows `NotReady` after about 40 seconds, and its Pods
  are replaced elsewhere after 5 minutes by default. That's the difference from Compose:
  Compose runs containers on one machine; Kubernetes keeps them running when a machine is
  gone.

If it breaks: `drain` hangs → a Pod can't be evicted; the message names it. Press Ctrl+C
and `kubectl uncordon` the node.

## Step 7: rolling updates

**Goal:** a new version without downtime, and a broken version without an outage. To keep
it short, we change the Deployment with `kubectl set`, breaking step 6's rule on purpose;
the last block shows the price.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml
kubectl rollout status deployment/hello
kubectl set env deployment/hello Greeting="Hello from revision 2"    # in real life: change the file, then apply
kubectl rollout status deployment/hello
kubectl get replicasets -l app=hello
kubectl port-forward deployment/hello 8080:8080 > /dev/null &
sleep 1
curl -s localhost:8080 | jq .message
kill %1
```

**Ask first:** the next release has a typo in the image tag. How many Pods still answer?

<!-- run -->
```bash
kubectl set image deployment/hello hello=localhost:5000/hello-web:9.9
kubectl rollout status deployment/hello --timeout=20s
kubectl get pods -l app=hello
kubectl rollout history deployment/hello
kubectl rollout undo deployment/hello
kubectl rollout status deployment/hello
kubectl get pods -l app=hello
```

**Ask first:** back to what the file says. The file has no `Greeting`; what does `apply`
do with the one we set?

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml                   # "unchanged"
echo "env: $(kubectl get deployment hello -o jsonpath='{.spec.template.spec.containers[0].env}')"
kubectl replace --save-config -f deployment.yaml   # the whole object, exactly as in the file
kubectl rollout status deployment/hello
echo "env: $(kubectl get deployment hello -o jsonpath='{.spec.template.spec.containers[0].env}')"
```

- **A rolling update:** any change to the Pod template (image, environment variable,
  anything) creates a new ReplicaSet, with a new hash in the Pod names. The Deployment
  scales it up and the old one down, a Pod at a time; the old ReplicaSet stays, with 0
  Pods, for a rollback. `rollout history` lists the revisions; its `CHANGE-CAUSE` stays
  empty, the Git history of the manifests is the better change log.
- **The readiness probe** (in `deployment.yaml`) makes this safe: a new Pod gets traffic
  only when `/healthz` answers, and an old Pod is removed only when a new one is ready.
  Without it, a Pod counts as ready as soon as the process starts, before ASP.NET Core
  listens. That's the morning's "running is not ready". The kubelet probes from outside the
  container, so the chiseled image needs no `curl`. The `preStop` pause at the end of the
  file is the other half of a rollout without errors; step 9 measures it.
- **The answer:** all three. The rollout stops because the new Pod never becomes ready,
  and with three replicas, the Deployment may take down zero Pods before a new one is
  ready (25% of 3, rounded down). Here the image doesn't even start. For an image that
  starts but is broken (it crashes, or `/healthz` fails), the readiness probe is what stops
  the rollout: **Agent trap:** no readiness probe. `rollout undo` is the emergency brake;
  its warning says it: fix the file afterwards, or the next `apply` brings the typo back.
- **The answer to the last question:** nothing. `apply` changes what the file says, and
  removes only what an earlier `apply` put there. The `Greeting` came from `kubectl set
  env`, so it stays, invisible in the file. That's the other half of step 6's trap:
  imperative changes are either silently undone or silently kept. `replace` makes the
  object exactly the file (the second `env:` line is empty); in a team, a GitOps tool does
  that for you.
- **Agent trap:** building a new image, pushing it under the same tag (`1.0` again), and
  expecting the cluster to pick it up. The Pod template didn't change, so nothing rolls out;
  and a node pulls a tag only if it doesn't have it yet (`imagePullPolicy: IfNotPresent`,
  the default for every tag except `latest`). Agents "fix" that with `imagePullPolicy:
  Always` and `rollout restart`, which hides which version runs. One tag per build: a
  version, a build number, or the Git commit.

If it breaks: `rollout status` times out in the first block → `kubectl get pods` and step
13's recipe.

**Break:** the end of Part 2.

---

# Part 3: reaching the app

## Step 8: Services

**Goal:** a stable name in front of Pods that come and go.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml -f service.yaml
kubectl rollout status deployment/hello
kubectl get service hello
kubectl get endpointslices -l kubernetes.io/service-name=hello \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}  ready={.conditions.ready}{"\n"}{end}'
```

**Ask first:** a client inside the cluster calls `http://hello` six times. Which Pods
answer?

A client inside the cluster: a Pod with `curl` that just waits, and `kubectl exec` runs
the requests in it, like `docker exec` in the morning:

<!-- run -->
```bash
kubectl run client --image=curlimages/curl:8.22.0 -- sleep 3600
kubectl wait --for=condition=Ready pod/client --timeout=60s
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6; do curl -s http://hello/ | grep -o "\"host\":\"[^\"]*\""; done'
kubectl exec client -- curl -s http://hello.default.svc.cluster.local/; echo
kubectl delete pod client --wait=false
```

- **Every new Pod has a new name and a new IP.** A **Service** is the stable front: a name
  in the cluster's DNS and a virtual IP (`CLUSTER-IP`), sending each connection to one of
  the ready Pods that match its `selector`. The EndpointSlice is the current list of those
  Pod IPs; it changes with every rollout. Right after a rollout, a Pod on its way out can
  still be listed with `ready=false`: it gets no new connections.
- **The answer:** different Pods, in no particular order. The Service balances per
  connection, not per request. For .NET: an `HttpClient` keeps connections open, so a
  long-running caller may stick to one Pod. `SocketsHttpHandler.PooledConnectionLifetime`
  makes it reconnect now and then.
- **DNS names:** `hello` from the same namespace, `hello.default` from another one, the
  full name `hello.default.svc.cluster.local` from anywhere. The morning's version: a
  container name on a Docker network. In a connection string, it's the Service name
  (`Host=postgres`, step 12), never `localhost`.
- **`port: 80` → `targetPort: 8080`:** callers use the Service's port; the container's port
  is an implementation detail.
- **Types:** `ClusterIP` (the default) is reachable only inside the cluster. `NodePort`
  opens a port on every node. `LoadBalancer` gets an external address: from Azure in AKS,
  and in k3s from ServiceLB, which uses the nodes' own addresses. That's how Traefik gets
  port 80: `kubectl -n kube-system get service traefik`.

If it breaks: `wait` times out → the node is still pulling `curlimages/curl`; run the block
again. A Service with no endpoints → its selector doesn't match the Pods' labels (step 13).

## Step 9: Ingress: Traefik again

**Goal:** one entry point for HTTP, routed by host name: the morning's Traefik, configured
by Kubernetes resources instead of labels.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat ingress.yaml
kubectl apply -f deployment.yaml -f service.yaml -f ingress.yaml
kubectl rollout status deployment/hello
until curl -sf -o /dev/null http://hello.localhost:8000/healthz; do sleep 1; done   # until Traefik routes the new host name
kubectl get ingress hello
for i in 1 2 3 4; do curl -s http://hello.localhost:8000/ | jq -c '{message, host}'; done
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/        # no rule for this host name
curl -s http://hello.localhost:8000/request | jq
```

In the Windows browser, <http://hello.localhost:8000> works, too.

**Ask first:** we replace all three Pods (`rollout restart`) while 50 requests run through
Traefik. How many fail?

<!-- run -->
```bash
for i in $(seq 50); do curl -s -o /dev/null -w '%{http_code}\n' http://hello.localhost:8000/; sleep 0.1; done | sort | uniq -c &
kubectl rollout restart deployment/hello
kubectl rollout status deployment/hello
wait                                                                     # for the 50 requests
```

- **The way of a request:** `curl` → port 8000 on your laptop → the k3d load balancer
  container → port 80 of a node → Traefik's Pod → the `hello` Service → one of the Pods. On
  a real k3s server, the k3d part disappears: the server's own port 80 is Traefik.
- **The same Traefik as this morning**, v3.7.13, installed by k3s:
  `kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik`. In the morning it
  watched the Docker API for labels; here it watches the Kubernetes API for Ingress
  resources.
- **Ingress** is the routing rule: host and path to a Service. The **ingress controller**
  is the proxy that implements it: Traefik in k3s, others elsewhere (Azure: Application
  Gateway). The Ingress YAML stays the same; controller-specific extras go into
  annotations. Typical for us: `/api` to the .NET backend's Service, everything else to the
  Angular container's Service. The newer Gateway API is the successor to Ingress; Traefik
  supports both, and Ingress is what k3s sets up by default.
- **`/request`:** the client is Traefik's Pod again, and the real client is in
  `X-Forwarded-For`. Same fix as in the morning, `ASPNETCORE_FORWARDEDHEADERS_ENABLED`; next
  step, through a ConfigMap.
- **The answer:** none, all 50 return `200`. That takes two lines in
  [`deployment.yaml`](hello/deployment.yaml): the readiness probe, so a new Pod gets
  traffic only when it's ready, and the `preStop` pause, so an old Pod keeps serving for 5
  seconds while Traefik and the Service learn it's going away. ASP.NET Core stops accepting
  connections as soon as it gets SIGTERM; without the pause, the rehearsal lost 2 of 60
  requests: one `502`, and one that hung for 30 seconds and ended as `504`. **Agent trap:**
  "zero-downtime deployment" without a readiness probe and without a `preStop` pause.
- **TLS** belongs here, too: Traefik terminates it; certificates come from cert-manager or
  Traefik's own Let's Encrypt support. Not on a laptop today.

If it breaks: 404 right after `apply` → Traefik needs a moment; repeat the `curl`.
"Connection refused" on 8000 → the cluster was created without the port mapping, or the
morning's Traefik took the port first.

## Step 10: ConfigMaps and Secrets

**Goal:** configuration from the cluster, the morning's environment variables as
resources.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat config.yaml
diff deployment.yaml deployment-config.yaml
```

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f config.yaml -f deployment-config.yaml -f service.yaml -f ingress.yaml
kubectl rollout status deployment/hello
sleep 6                                                      # the old Pods serve 5 s more (preStop, step 9)
curl -s http://hello.localhost:8000/config | jq
curl -s http://hello.localhost:8000/request | jq -c '{remoteIp, scheme}'
```

**Your turn:** change `Greeting` in `config.yaml`, `kubectl apply -f config.yaml`, then
`curl -s http://hello.localhost:8000/ | jq .message`. Keep the answer to yourself until the
next question.

**Ask first:** we change the greeting in the ConfigMap. What do the running Pods say?

<!-- run -->
```bash
kubectl patch configmap hello-config --type merge -p '{"data":{"Greeting":"Changed in the cluster"}}'
sleep 2
curl -s http://hello.localhost:8000/ | jq .message
kubectl rollout restart deployment/hello                     # new Pods, which read the new values
kubectl rollout status deployment/hello
sleep 6
curl -s http://hello.localhost:8000/ | jq .message
```

How secret is a Secret?

<!-- run -->
```bash
kubectl get secret hello-secrets -o jsonpath='{.data}' | jq
kubectl get secret hello-secrets -o jsonpath='{.data.ConnectionStrings__Default}' | base64 -d; echo
```

Clean up the `hello` app:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl delete -f deployment-config.yaml -f config.yaml -f service.yaml -f ingress.yaml
```

- **ConfigMap** for settings, **Secret** for passwords and keys; both are key/value
  resources next to the Deployment. `envFrom` turns every key into an environment variable,
  and `__` becomes the `:` of `appsettings.json`, exactly as in the morning: the app reads
  `Database:Host` and doesn't know it's in Kubernetes. A ConfigMap can also be mounted as a
  file, for example as `appsettings.Production.json`. `postgres.visits` is the
  `<service>.<namespace>` form from step 8, for a database we start in step 11.
- **`stringData`** takes plain text, and the cluster stores it base64-encoded; `data` wants
  base64 by hand, which is where agents produce unreadable or double-encoded values.
- **`/config` prints the connection string, password included:** fine for a demo app, a
  leak in a real one.
- **`/request`:** `remoteIp` is now what Traefik saw. On a laptop that's still an internal
  address, because k3d's load balancer sits in front; getting the user's real IP through is
  the platform's job, not the app's. Any Pod in the cluster can reach the app directly, not
  only Traefik: trusting the headers from everyone is fine for a workshop, and a decision
  for production.
- **The answer:** the old greeting. Environment variables are read when the process starts,
  and the ConfigMap change doesn't restart anything. `rollout restart` replaces the Pods
  one at a time. **Agent trap:** changing a ConfigMap or Secret and expecting the running
  app to pick it up.
- **A Secret is base64, not encryption.** Whoever may read Secrets in the namespace reads
  the password; access is controlled with RBAC, and k3s can encrypt Secrets at rest
  (`--secrets-encryption`). **Agent trap:** a Secret manifest with a real password,
  committed to Git, like our `config.yaml`. In real projects, the values come from outside
  the repository: Sealed Secrets, SOPS, or the External Secrets Operator with Azure Key
  Vault.

If it breaks: `/config` still shows `appsettings.json` values → the Pods are from before
the apply; `kubectl rollout status deployment/hello` and try again.

---

# Part 4: state, and a real app

## Step 11: volumes and PersistentVolumeClaims

**Goal:** data that outlives its Pod: the morning's named volume, the Kubernetes way.

The manifest: a Secret, a PersistentVolumeClaim, a Deployment, a Service
([`visits/1-postgres.yaml`](visits/1-postgres.yaml)), in a namespace of its own:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/visits
kubectl apply -f 0-namespace.yaml -f 1-postgres.yaml
kubectl -n visits rollout status deployment/postgres --timeout=180s
kubectl -n visits get pvc
kubectl get pv
kubectl -n visits exec deploy/postgres -- psql -U postgres -c "CREATE TABLE IF NOT EXISTS notes (note text)"
kubectl -n visits exec deploy/postgres -- psql -U postgres -c "INSERT INTO notes VALUES ('written at $(date +%T)')"
```

**Ask first:** we delete the Postgres Pod. Its replacement may start on any of the three
nodes. Which one does it land on?

<!-- run -->
```bash
kubectl -n visits get pod -l app=postgres -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
kubectl -n visits delete pod -l app=postgres
kubectl -n visits wait --for=condition=Ready pod -l app=postgres --timeout=120s
kubectl -n visits get pod -l app=postgres -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
kubectl -n visits exec deploy/postgres -- psql -U postgres -c "SELECT * FROM notes"
```

Where the data lives:

<!-- run -->
```bash
NODE=$(kubectl -n visits get pod -l app=postgres -o jsonpath='{.items[0].spec.nodeName}'); echo "Postgres runs on $NODE"
docker exec $NODE ls /var/lib/rancher/k3s/storage/
kubectl get pv -o custom-columns=VOLUME:.metadata.name,CLAIM:.spec.claimRef.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],RECLAIM:.spec.persistentVolumeReclaimPolicy
```

- **Three pieces.** The **PersistentVolumeClaim** is the app's request: "1 GiB, mounted by
  one node at a time" (`ReadWriteOnce`). The **PersistentVolume** is the actual storage. The
  **StorageClass** says how to make one when a claim asks: in k3s, `local-path`, a folder
  on the node. The Deployment mounts the claim at `/var/lib/postgresql`, the Postgres 18
  path from the morning.
- **The answer:** the same node, every time. Local storage is bound to its node: the PV
  has a node affinity (the `NODE` column), so the Pod has to follow its data. If that node
  dies, the data is gone and the Pod can't move. In the cloud, the StorageClass gives
  network disks (Azure Disk) that move with the Pod; on-premises k3s clusters often use
  Longhorn (replicated across nodes, also from SUSE) or NFS.
- **And the note survived**, of course: the data is in the volume, not in the container,
  exactly like the morning's `workshop-pgdata`. `kubectl exec` is `docker exec`.
- **Namespaces in manifests:** every object in `visits/` says `namespace: visits` in its
  metadata, while `hello/` says nothing and lands in the current namespace (`default`).
  Files without a namespace can be sent elsewhere with `kubectl apply -n`; with one, the
  file decides. A manifest without a namespace goes wherever the current context points:
  the wrong-context trap, in small.
- **SQL Server** looks the same: `mcr.microsoft.com/mssql/server` with a claim at
  `/var/opt/mssql`, the same `Recreate`, and the same advice for production (Azure SQL
  rather than a Deployment).
- **One database, one volume:** `replicas: 1` and the `Recreate` strategy, so two Postgres
  processes never share a data folder. **Agent trap:** a database as a Deployment with
  several replicas, or with the default rolling update, on one volume. Several replicas of
  a database are a StatefulSet at least, and in practice an operator (CloudNativePG) or a
  managed database (Azure Database for PostgreSQL): backups, failover, and upgrades are the
  hard part.
- **`RECLAIM: Delete`:** deleting the claim deletes the volume and the data, like
  `docker volume rm`. Deleting a namespace deletes its claims. **Agent trap:** a cleanup
  script with `kubectl delete namespace` or `kubectl delete -f .` next to a database.

If it breaks: the PVC stays `Pending` → it waits for its first Pod (`WaitForFirstConsumer`);
`kubectl -n visits describe pvc postgres-data` says why if it's something else.

## Step 12: a real deployment: the visit counter

**Goal:** the morning's Compose app with Traefik, as a complete set of manifests: build,
push, apply, reach.

Build and push the app ([`docker/visit-counter`](../docker/visit-counter)):

<!-- run -->
```bash
cd ~/docker-k3s/docker/visit-counter
docker build -q -t localhost:5000/visit-counter:1.0 .
docker push -q localhost:5000/visit-counter:1.0
```

**Ask first:** Compose had `depends_on: condition: service_healthy`. Kubernetes has nothing
like it. What happens when the app starts before the database is there?

We take the database away (step 6's `scale`, on purpose), then start the app:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/visits
kubectl apply -f 0-namespace.yaml -f 1-postgres.yaml
kubectl -n visits scale deployment postgres --replicas=0
kubectl apply -f 2-visit-counter.yaml
sleep 20
kubectl -n visits get pods
kubectl -n visits logs deploy/visit-counter | grep -m1 Exception
```

The whole folder, in file name order (namespace, database, app). The file says Postgres
has one replica:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/visits
kubectl apply -f .
kubectl -n visits rollout status deployment/postgres --timeout=180s
kubectl -n visits rollout status deployment/visit-counter --timeout=300s   # at its next restart, the app finds the database
kubectl -n visits get pods -o wide
until curl -sf -o /dev/null http://visits.localhost:8000/healthz; do sleep 1; done   # until Traefik routes the new host name
sleep 3                                                                  # and knows all three Pods
for i in 1 2 3 4 5 6; do curl -s http://visits.localhost:8000/ | jq -c; done
```

What we deployed, and how it compares with the morning:

<!-- run -->
```bash
kubectl -n visits get all,ingress,pvc,secret
wc -l ~/docker-k3s/docker/compose-traefik/compose.yaml ~/docker-k3s/k3s/visits/*.yaml
```

**Your turn:** scale the app to five replicas by changing `replicas` in
`2-visit-counter.yaml` and applying the folder again. Then watch `servedBy`.

Clean up; this deletes the claim, and with it the data, on purpose:

<!-- run -->
```bash
kubectl delete namespace visits
```

- **Read [`visits/2-visit-counter.yaml`](visits/2-visit-counter.yaml) top to bottom** with
  the room; every block is something from today: a Secret with the connection string
  (`Host=postgres`, the Service name), a Deployment with three replicas, resources,
  readiness and liveness probes, the `preStop` pause, a `securityContext`, a Service, an
  Ingress for `visits.localhost`. A real app with an Angular front end is this file twice
  (api and web) and one Ingress with two paths.
- **The answer:** the app crashes (Npgsql can't connect, the process exits), the kubelet
  restarts it, and the waits grow: `CrashLoopBackOff`. `apply -f .` brings Postgres back,
  because the file says one replica, and the app recovers by itself at its next restart.
  That's Kubernetes' `depends_on`: retry until it works, with readiness keeping traffic
  away meanwhile. Better than crashing: retry in the app (Npgsql's and EF Core's retry
  options, Polly) or an init container (a container that runs to completion before the app
  starts) that waits for the database.
- **Liveness:** a failing liveness probe restarts the container. `/healthz` here
  deliberately doesn't check the database. **Agent trap:** a liveness probe that checks the
  database: when the database is down, every Pod restarts in a loop, and nothing gets
  better.
- **`securityContext`** is the morning's `docker run --read-only --cap-drop ALL
  --security-opt no-new-privileges`, plus `runAsNonRoot`: the cluster refuses to start an
  image that would run as root (step 13 shows it). The chiseled image passes all of it.
- **`servedBy`** alternates, `visits` counts up: three replicas, one database. Three
  replicas also start at the same time: `Program.cs` creates its table under an advisory
  lock, so they don't race. **Agent trap:** EF Core's `Migrate()` at startup with more than
  one replica; run migrations as a Job (a Pod that runs once, step 14), in an init
  container, or under a lock.
- **`secret/... configured`** on every `apply`, never `unchanged`: that's `stringData`, which
  the cluster stores as `data`, so the comparison always differs. Harmless.
- **About 170 lines of YAML instead of 55 lines of Compose.** Each extra line says something
  Compose couldn't: probes, resources, security, and that this runs across machines. This
  is why Helm and Kustomize exist, why agents write these files, and why you have to be
  able to read them.

If it breaks: `visit-counter` stays in `CrashLoopBackOff` after Postgres is back → wait for
the next restart (up to a minute), or `kubectl -n visits rollout restart deployment/visit-counter`.
Pods that were already running don't crash when the database goes away: delete the
`visit-counter` Deployment before the first block.

---

# Part 5: when things go wrong

## Step 13: troubleshooting

**Goal:** a recipe for every broken Pod: status, events, logs.

Seven broken apps ([`troubleshooting/`](troubleshooting)), each with a different mistake.
Two of them need images the morning built:

<!-- run -->
```bash
cd ~/docker-k3s/docker
docker build -q -f hello-web/Dockerfile.3-multistage -t localhost:5000/hello-web:3-multistage hello-web
docker push -q localhost:5000/hello-web:3-multistage
docker build -q -t localhost:5000/visit-counter:1.0 visit-counter
docker push -q localhost:5000/visit-counter:1.0
cd ~/docker-k3s/k3s/troubleshooting
kubectl apply -f .
sleep 30                                   # give them time to fail
kubectl -n troubleshooting get pods
```

**Ask first:** which of the seven apps is healthy?

**Your turn:** each table takes one app and finds the cause, with this recipe:

<!-- run -->
```bash
kubectl -n troubleshooting get pods                                         # 1. STATUS and RESTARTS
kubectl -n troubleshooting describe pod -l app=catalog | tail -4            # 2. the Events, at the end of describe
kubectl -n troubleshooting logs deploy/orders | head -2                     # 3. what the app said before it died
kubectl -n troubleshooting get events --field-selector type=Warning --sort-by=.lastTimestamp | tail -6   # 4. all warnings
```

The presenter's walkthrough, one line per app:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/troubleshooting
kubectl -n troubleshooting describe pod -l app=billing | grep -m1 'Error:'
kubectl -n troubleshooting describe pod -l app=reports | grep -m1 FailedScheduling
kubectl -n troubleshooting get endpointslices -l kubernetes.io/service-name=webshop
grep -n 'app:' 5-webshop.yaml
kubectl -n troubleshooting get pod -l app=importer -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated}' | jq -c '{reason, exitCode}'
kubectl -n troubleshooting describe pod -l app=inventory | grep -m1 'Readiness probe failed'
```

Two fixes, live (in real life: in the file):

<!-- run -->
```bash
kubectl -n troubleshooting set image deployment/catalog catalog=localhost:5000/hello-web:1.0
kubectl -n troubleshooting patch service webshop -p '{"spec":{"selector":{"app":"webshop"}}}'
kubectl -n troubleshooting rollout status deployment/catalog
kubectl -n troubleshooting get endpointslices -l kubernetes.io/service-name=webshop
kubectl delete namespace troubleshooting
```

| App | `STATUS` | Where you see the cause | The mistake |
| --- | --- | --- | --- |
| 1 catalog | `ErrImagePull`, `ImagePullBackOff` | `describe`: "not found" | tag `1.O` with a letter O |
| 2 orders | `Error`, `CrashLoopBackOff` | `logs`: "Connection string 'Visits' is missing" | no Secret, no `envFrom` |
| 3 billing | `CreateContainerConfigError` | `describe`: "container has runAsNonRoot and image will run as root" | the `aspnet:10.0` image without `USER` |
| 4 reports | `Pending` | `describe`: "0/3 nodes are available: 3 Insufficient cpu" | requests 64 CPUs |
| 5 webshop | `Running`, and still no answer | the Service has no endpoints | selector `web-shop`, label `webshop` |
| 6 importer | `OOMKilled`, `CrashLoopBackOff` | `get pod`, last state: exit code 137 | limit 64 MiB; the process wants more |
| 7 inventory | `Running`, but `0/1` ready | `describe`: "Readiness probe failed: ... connection refused" | probe and port 80; ASP.NET Core listens on 8080 |

- **The answer:** none. `webshop` looks healthy (`1/1 Running`), and nobody reaches it;
  `inventory` runs, and is never ready.
- **The recipe:** `get` for the status, `describe` for the events (everything the cluster
  did and failed to do with this Pod), `logs` for what the app said: for a Pod in
  `CrashLoopBackOff`, that's its last run. `logs --previous` shows the run before the
  current one, for an app that runs again after a crash. `get events` for the whole
  namespace, newest last. Events are kept for an hour; logs only as long as the Pod exists.
  What people type all day: `kubectl get pods -w` (watch the status change) and
  `kubectl logs -f --tail 20 deploy/<name>` (follow the log).
- **Read the status as a stage:** `Pending` = no node yet (scheduling), `ErrImagePull` =
  node can't get the image, `CreateContainerConfigError` = the spec is wrong for this image
  or a ConfigMap/Secret is missing, `CrashLoopBackOff` = the app starts and exits, `Running`
  but not ready = the readiness probe fails. Each stage has its own place to look.
- **App 3 is the morning's agent trap** (a runtime stage without `USER`) meeting a cluster
  that enforces non-root. Many clusters do: AKS with Azure Policy, OpenShift always. Also
  rejected: `USER app` by name ("image has non-numeric user, cannot verify user is
  non-root"); the morning's `USER $APP_UID` is a number and passes.
- **App 5 is the quietest:** everything is green, and the Service sends traffic nowhere. A
  label typo; `kubectl get endpointslices` is the check.
- **App 6, in .NET:** the morning showed that .NET respects the limit and throws
  `OutOfMemoryException` before the kernel kills it. A native leak, or a Node.js process,
  ends like this `alpine` one: `OOMKilled`, exit code 137.
- **App 7 is the most common .NET mistake** in agent-written manifests: port 80, from the
  times before .NET 8. Since .NET 8, the ASP.NET Core images listen on 8080
  (`ASPNETCORE_HTTP_PORTS`). The logs look perfect; only `describe` shows the failing
  probe, and the Service has no endpoints.
- **Chiseled images have no shell** for `kubectl exec`. `kubectl debug -it <pod>
  --image=busybox --target=<container>` adds a temporary container with tools to a running
  Pod.
- **Agents are good at this,** if you give them the facts: paste the `describe` and `logs`
  output rather than "my Pod doesn't work". Graphical helpers: k9s in the terminal,
  Headlamp, or the Kubernetes extension for VS Code.

If it breaks: `logs` says "unable to retrieve container logs" or shows nothing → the
container is restarting right now; run it again. `1.O` and `1.0` look the same on a
projector: zoom in on the `describe` line.

## Step 14: wrap-up

**Goal:** the map of the afternoon, the agent traps, and a clean laptop.

| Docker (morning) | k3s (afternoon) | Step |
| --- | --- | --- |
| `docker` CLI → engine | `kubectl` → API server; contexts | 1, 2 |
| `docker run` | Pod; Deployment → ReplicaSet → Pods | 4, 5 |
| `--restart`, Compose replicas | Deployment: desired state, self-healing, `scale` | 5, 6 |
| `docker compose up` after a change | rolling update, `rollout undo` | 7 |
| network and container names | Service and DNS | 8 |
| Traefik with labels | Traefik with Ingress | 9 |
| `-e`, `--env-file` | ConfigMap, Secret, `envFrom` | 10 |
| named volume | PersistentVolumeClaim, StorageClass | 11 |
| `compose.yaml` | a folder of manifests, `kubectl apply -f .` | 12 |
| health check | readiness and liveness probes | 7, 9, 12 |
| `--read-only`, `--cap-drop ALL`, `USER` | `securityContext`, `runAsNonRoot` | 12, 13 |
| `docker logs`, `inspect`, `ps` | `kubectl logs`, `describe`, `get`, events | 13 |

`kubectl` on one page:

| Command | What for |
| --- | --- |
| `get <type>`, `-o wide`, `-o yaml`, `-w` | list, more columns, the whole object, watch |
| `describe <type> <name>` | one object, with its events |
| `logs`, `-f`, `--previous` | what the app wrote: follow, the run before |
| `apply -f`, `diff -f`, `delete -f` | files: bring in, compare, remove |
| `rollout status`, `restart`, `undo`, `history` | Deployments over time |
| `scale`, `set`, `edit` | quick changes, then fix the file (step 6) |
| `exec`, `debug`, `port-forward` | into a Pod, next to a Pod, a tunnel to a Pod |
| `explain <type>.<field>` | the built-in documentation |
| `-n <namespace>`, `-A`, `-l app=x`, `--context` | where, everywhere, which ones, which cluster |

The agent traps of the afternoon: read every generated manifest with this list in mind.

| Trap | Step |
| --- | --- |
| `kubectl` against the wrong context | 2 |
| no resource requests and limits | 5, 12 |
| fixing the cluster with `scale`, `edit`, `set` instead of the file | 6, 7 |
| no readiness probe | 7 |
| a new image under an old tag; `imagePullPolicy: Always` as the fix | 7 |
| "zero downtime" without readiness probe and `preStop` pause | 9 |
| real secrets in a committed Secret manifest | 10 |
| expecting a changed ConfigMap to reach running Pods | 10 |
| a database Deployment with several replicas or rolling updates on one volume | 11 |
| `kubectl delete namespace` or `delete -f .` next to a database | 11 |
| `Host=localhost` instead of the Service name | 8, 12 |
| a liveness probe that checks the database | 12 |
| EF Core migrations at startup with several replicas | 12 |
| an image that runs as root, no `securityContext` | 12, 13 |
| a Service selector that doesn't match the Pod labels | 13 |
| port 80 instead of 8080 for ASP.NET Core 8 and later | 13 |

- **What's next, when you need it:** Helm or Kustomize (manifests with variables, per
  environment), GitOps with Flux or Argo CD (the cluster pulls its state from Git, so
  nobody runs `kubectl apply` by hand), cert-manager (TLS), Prometheus and Grafana
  (monitoring), and a managed cluster (AKS) or k3s on your own servers.
- **Jobs and CronJobs:** a Job is a Pod that runs to completion, a CronJob starts one on a
  schedule. What is a Windows service on a server today is a Deployment; what is a scheduled
  task is a CronJob; database migrations are a Job.
- The vocabulary is new; the containers are the same as this morning.

Delete the cluster; the registry stays:

<!-- run -->
```bash
docker network disconnect k3d-workshop registry      # or the cluster's network stays behind
k3d cluster delete workshop
kubectl config get-contexts                          # what kubectl points at now
docker ps --filter name=registry --format '{{.Names}}: {{.Status}}'
```

After the delete, `kubectl` points at nothing, or at whatever other cluster is in
`~/.kube/config`: check before the next `apply`.

The end of the day: the registry, its data, the login, and the images we built:

<!-- run -->
```bash
docker rm -f registry
docker volume rm workshop-registry-data
docker logout localhost:5000
docker image rm localhost:5000/visit-counter:1.0 localhost:5000/hello-web:3-multistage 2>/dev/null
```

---

## Ports

| Port | What |
| ---: | --- |
| 5000 | the private registry from the morning |
| 6550 | the Kubernetes API of the workshop cluster, on 127.0.0.1 only |
| 8000 | Traefik in the cluster: `hello.localhost`, `visits.localhost` |
| 8080 | `kubectl port-forward` (steps 4, 6, 7) |

## Troubleshooting

- **`kubectl` talks to the wrong cluster**, or "connection refused" on `localhost:8080`:
  no current context. `kubectl config get-contexts`, then `kubectl config use-context
  k3d-workshop`.
- **`ImagePullBackOff` with "no such host"** for `registry`: the registry container isn't
  on the cluster's network, for example after the registry was recreated.
  `docker network connect k3d-workshop registry`.
- **`ImagePullBackOff` with "not found"**: the image isn't in the registry, or the tag has
  a typo. `curl -s -u workshop:docker-k3s localhost:5000/v2/<name>/tags/list`.
- **After a Docker Desktop restart**, the cluster's containers are stopped: `k3d cluster
  start workshop`.
- **Everything is slow, Pods are evicted**: Docker Desktop is out of memory. Close other
  containers, or give WSL more memory in `%UserProfile%\.wslconfig` (`[wsl2]`,
  `memory=8GB`), then `wsl --shutdown`.
- **Start fresh:** `k3d cluster delete workshop`, then step 2. Two minutes, and nothing else
  on the laptop is touched.
