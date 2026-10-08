# Storybook: Kubernetes fundamentals in two hours

**The short version of the k3s half day, for a two-hour session**

This is the presenter's guide for a two-hour version of [`storybook.md`](storybook.md). The
audience is the same: experienced C# developers who live on Windows and know Docker. The goal
is narrower: the fundamentals of **Kubernetes**, not of k3s. k3s is only the vehicle: a real,
certified Kubernetes that runs on a laptop. Everything shown here works the same way on AKS,
EKS, or any other cluster; the few k3s details that show up are named as such.

The thread is one idea, repeated in every step: **you declare what you want, and the cluster
keeps it so.** Pods, Deployments, Services, Ingress, ConfigMaps, and volumes are all
variations on that.

Ten steps, the same markers as in the full storybook:

- **Ask first:** a prediction question before a block. Let the room answer, then run it.
- **Your turn:** a minute or two for the participants who build along.
- **Agent trap:** a mistake coding agents (and tutorials) make often, collected in
  [step 10](#step-10-wrap-up).

The manifests are the ones of the full storybook (`hello/`, `visits/`, `troubleshooting/`).
Their comments mention step numbers of the full version; ignore the numbers. Each step can be
shown on its own: its first block applies what it needs.

What the full version has and this one leaves out: what's inside k3s (Helm charts, `crictl`,
`registries.yaml`), draining a node, the startup-order demo, and two of the seven
broken apps. Each of them is a talking point
here at most.

**Setup:** as for the full storybook: Docker Desktop on Windows, every command in **bash
inside WSL (Ubuntu)**, the repository in `~/docker-k3s`. The cluster is k3s, run by k3d: each
Kubernetes node is a Docker container. Images come from the registry of the Docker half day,
`localhost:5000`.

To rehearse:

```bash
~/docker-k3s/rehearsal/run-blocks.py --storybook k3s/storybook-2h.md
```

## Before the session

**Participants** who build along: the "Before the workshop" list of
[the full storybook](storybook.md#before-the-workshop) (`./install-tools.sh` and
`./prepull.sh` in `~/docker-k3s/k3s`).

**Presenter:**

- The registry with `hello-web:1.0` in it: `./registry.sh` in `~/docker-k3s/k3s`.
- On weak wifi, create the cluster ahead of time (step 1's first block) and keep it: a new
  cluster pulls its system images from the internet.
- Terminal at 20 pt or larger; port 8000 free (no Compose Traefik from the Docker half day).

---

## Step 1: a cluster, and where kubectl talks to

**Goal:** a three-node cluster on the laptop, and the idea that Kubernetes is an API of
resources.

<!-- run -->
```bash
cd ~/docker-k3s/k3s
./registry.sh                                    # the Docker half day's registry, started if needed
k3d cluster create --config cluster.yaml
docker network connect k3d-workshop registry     # the nodes reach the registry by its name
kubectl config current-context
kubectl get nodes -o wide
```

What is running in a cluster that we haven't used yet?

<!-- run -->
```bash
until kubectl -n kube-system get deployment traefik > /dev/null 2>&1; do sleep 2; done   # the cluster installs Traefik in its first minute
kubectl -n kube-system rollout status deployment/traefik
kubectl get namespaces
kubectl get pods -A                              # -A: in all namespaces
kubectl api-resources | head -15
kubectl explain deployment.spec.replicas         # the built-in documentation
```

- **`kubectl` is to Kubernetes what `docker` is to the Docker engine:** a client that sends
  requests to an API, and the cluster does the work. The same `kubectl` and the same
  manifests work against k3s, AKS, or EKS.
- **k3s in one sentence:** a complete Kubernetes in a single binary, with the usual add-ons
  (DNS, an ingress controller, local storage) included. k3d runs its nodes as Docker
  containers, so a cluster costs 20 seconds and one command.
- **Nodes:** one server, which runs the **control plane** (the API that `kubectl` talks to,
  the scheduler that decides which node runs what, the controllers that keep things as you
  declared them, and the database for all of it), and two agents, which only run workloads.
  Every node runs the **kubelet**, which starts containers, restarts them, and checks their
  health.
- **Everything is a resource** with a `kind` and a name: Node, Namespace, Pod, Deployment,
  Service. `kubectl get` lists them, `describe` explains one, `explain` documents every field.
  When an agent writes a field you don't know, `kubectl explain` is faster than a web search.
- **Namespaces** are folders for resources. `kube-system` holds the cluster's own Pods: DNS
  (CoreDNS), the ingress controller (Traefik), storage. They are ordinary Pods, like ours.
- **No Docker inside the cluster.** Each node has its own container runtime and its own image
  store; the images on the laptop don't count. A cluster always pulls from a registry.
- **Contexts:** k3d added the context `k3d-workshop` to `~/.kube/config` and made it the
  current one. Every `kubectl` command goes to the current context, whatever cluster that is.
  **Agent trap:** `kubectl apply` or `delete` while the current context is production. Check
  with `kubectl config current-context`, or pass `--context` in scripts.

If it breaks: "cluster workshop already exists" → fine, continue. "port is already
allocated" → the Compose Traefik is still running:
`docker compose -f ~/docker-k3s/docker/compose-traefik/compose.yaml down`.

---

## Step 2: the first Pod

**Goal:** a Pod is the unit Kubernetes runs; on its own, it is not much more than
`docker run`.

<!-- run -->
```bash
kubectl run hello --image=localhost:5000/hello-web:1.0 --port=8080
kubectl wait --for=condition=Ready pod/hello --timeout=60s
kubectl get pod hello -o wide
kubectl logs hello
kubectl port-forward pod/hello 8080:8080 > /dev/null &     # a tunnel from the laptop to the Pod
sleep 1
curl -s localhost:8080 | jq '{message, host}'
kill %1
```

**Ask first:** we delete this Pod. What happens?

<!-- run -->
```bash
kubectl delete pod hello
kubectl get pods
kubectl run hello --image=localhost:5000/hello-web:1.0 --port=8080 --dry-run=client -o yaml   # the Pod as a manifest
```

- **A Pod** is one or more containers that share an IP address and volumes, always on one
  node. Mostly it's one container. It gets its own IP, and its name is the container's host
  name.
- **The answer:** it's gone, and nothing brings it back. A Pod alone is a `docker run`: if
  it's deleted, or its node dies, it stays gone. That's why nobody creates Pods directly.
- **`port-forward`** is a developer tool for a quick look, not how users reach an app
  (steps 5 and 6).
- **`--dry-run=client -o yaml`** prints what the command would have sent: a quick way to
  start a manifest by hand. The four parts of every manifest are already visible:
  `apiVersion`, `kind`, `metadata`, `spec`.

If it breaks: `ErrImagePull` → `docker network connect k3d-workshop registry` (step 1).

---

## Step 3: Deployments: desired state

**Goal:** declare what you want in a file; the cluster makes it so, and keeps it so.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat deployment.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/hello
kubectl get deployment,replicaset,pods -o wide
```

**Ask first:** we delete one of the three Pods. And then the app in another Pod crashes
(the `/crash` endpoint from the Docker half day). What happens each time?

<!-- run -->
```bash
POD=$(kubectl get pods -l app=hello -o name | head -1); echo "deleting $POD"
kubectl delete $POD --wait=false
kubectl get pods -l app=hello
kubectl port-forward deployment/hello 8080:8080 > /dev/null &
sleep 1
curl -s localhost:8080/crash; echo
kill %1
sleep 3
kubectl get pods -l app=hello                      # RESTARTS
```

**Ask first:** we scale to six by command. The file still says three. What does the next
`kubectl apply` do?

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl scale deployment hello --replicas=6
kubectl get pods -l app=hello -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
kubectl diff -f deployment.yaml | grep -E '^[-+] '      # what apply would change
kubectl apply -f deployment.yaml
kubectl get deployment hello
```

**Your turn:** set `replicas: 2` in `deployment.yaml`, `kubectl apply -f deployment.yaml`,
`kubectl get pods`. Then back to 3.

- **The manifest:** `apiVersion` and `kind` (what type), `metadata` (name, labels), `spec`
  (what you want). The cluster adds `status` (what is): `kubectl get deployment hello -o yaml`
  shows both halves.
- **Labels connect things.** The Deployment doesn't know its Pods by name: it owns every Pod
  whose labels match its `selector` (`app: hello`). The `template` is step 2's Pod, as a
  blueprint. Deployment → ReplicaSet → Pods; the ReplicaSet keeps the number, the Deployment
  keeps one ReplicaSet per version (step 4).
- **The answer to the first question:** a new Pod appears at once, with a new name. You
  declared "three"; a controller compares what is with what should be, and acts. All of
  Kubernetes works like this: a loop that reconciles, again and again.
- **The answer to the crash:** the same Pod, `RESTARTS` 1. The kubelet restarts the crashed
  container in place. If it keeps crashing, the waits between restarts grow up to 5 minutes:
  that's the famous `CrashLoopBackOff` (step 9).
- **A node that dies** is the same story, one level up: its Pods are recreated on the other
  nodes. That's the difference from Compose, which runs containers on one machine.
- **The answer to the last question:** back to three. The file is the truth. **Agent trap:**
  fixing a cluster with `kubectl scale`, `edit`, or `set`, and not the file. The next `apply`,
  or a GitOps tool that applies the Git repository continuously, silently takes it back.
- **Declarative instead of imperative:** `kubectl run` was a command; `kubectl apply -f`
  hands over a goal, as often as you like. The files go into Git and through pull requests,
  like code. That's what you want agents to write.
- **Resources:** `requests` is what the scheduler reserves on a node; it decides where the
  Pod fits. `limits.memory` is `docker run --memory`, and .NET sizes its heap to it. **Agent
  trap:** no requests and limits; the scheduler places blindly, and one leaking Pod starves
  a node.
- **The `readinessProbe` and `preStop`** in the file pay off in the next steps.

If it breaks: `rollout status` waits forever → `kubectl get pods` shows why; usually
`ImagePullBackOff` (step 2).

---

## Step 4: rolling updates and rollback

**Goal:** a new version without downtime, and a broken version without an outage. To keep it
short, we change the Deployment by command; in real life, you change the file.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml
kubectl rollout status deployment/hello
kubectl set env deployment/hello Greeting="Hello from revision 2"
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
kubectl rollout undo deployment/hello
kubectl rollout status deployment/hello
kubectl get pods -l app=hello
```

Back to what the file says, the price of the shortcut:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl apply -f deployment.yaml                   # "unchanged": the Greeting stays
kubectl replace --save-config -f deployment.yaml   # the whole object, exactly as in the file
kubectl rollout status deployment/hello
echo "env: $(kubectl get deployment hello -o jsonpath='{.spec.template.spec.containers[0].env}')"
```

- **A rolling update:** any change to the Pod template (image, environment variable,
  anything) creates a new ReplicaSet. The Deployment scales it up and the old one down, a Pod
  at a time; the old ReplicaSet stays, with 0 Pods, for a rollback.
- **The readiness probe makes it safe:** a new Pod gets traffic only when `/healthz`
  answers, and an old Pod is removed only when a new one is ready. Without it, a Pod counts
  as ready as soon as the process starts. "Running is not ready", as in the Docker half day.
- **The answer:** all three. The new Pod never becomes ready, so the rollout stops and the
  old Pods keep serving. **Agent trap:** no readiness probe; then a broken version replaces
  every working Pod. `rollout undo` is the emergency brake; fix the file afterwards, or the
  next `apply` brings the typo back.
- **`apply` doesn't undo `set`.** It changes what the file says and removes only what an
  earlier `apply` put there; the `Greeting` from `kubectl set env` stays, invisible in the
  file. `replace` makes the object exactly the file. That's step 3's trap from the other
  side: imperative changes are silently undone, or silently kept.
- **Agent trap:** a new image pushed under the same tag (`1.0` again). The Pod template
  didn't change, so nothing rolls out, and nodes that have the tag don't pull it again. The
  usual "fix", `imagePullPolicy: Always` plus `rollout restart`, hides which version runs.
  One tag per build: a version, a build number, or the Git commit.

If it breaks: the first `rollout status` times out → `kubectl get pods` and step 9's recipe.

---

## Step 5: Services: a stable name

**Goal:** a stable name in front of Pods that come and go.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat service.yaml
kubectl apply -f deployment.yaml -f service.yaml
kubectl rollout status deployment/hello
kubectl get service hello
kubectl get endpointslices -l kubernetes.io/service-name=hello
```

**Ask first:** a client inside the cluster calls `http://hello` six times. Which Pods answer?

<!-- run -->
```bash
kubectl run client --image=curlimages/curl:8.22.0 -- sleep 3600
kubectl wait --for=condition=Ready pod/client --timeout=60s
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6; do curl -s http://hello/ | grep -o "\"host\":\"[^\"]*\""; done'
kubectl delete pod client --wait=false
```

- **Every new Pod has a new name and a new IP.** A **Service** is the stable front: a name in
  the cluster's DNS and a virtual IP, sending each connection to one of the *ready* Pods that
  match its `selector`. The EndpointSlice is the current list of those Pod IPs.
- **The answer:** different Pods, in no particular order. The Service balances per
  connection, not per request: a .NET `HttpClient` that keeps its connection open may stick
  to one Pod.
- **DNS names:** `hello` from the same namespace, `hello.<namespace>` from another one. The
  Docker version is a container name on a Docker network. In a connection string, it's the
  Service name (`Host=postgres`, step 8). **Agent trap:** `Host=localhost`; in a Pod,
  `localhost` is the Pod itself.
- **`port: 80` → `targetPort: 8080`:** callers use the Service's port; the container's port
  is an implementation detail.
- **Types:** `ClusterIP` (the default) works only inside the cluster. `LoadBalancer` gets an
  external address, from Azure in AKS. For HTTP, one entry point for all apps is the better
  way: the next step.

If it breaks: `wait` times out → the node is still pulling `curlimages/curl`; run it again.

---

## Step 6: Ingress: HTTP from outside

**Goal:** one entry point for HTTP, routed by host name: Traefik, as in the Docker half day,
configured by Kubernetes resources instead of labels.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat ingress.yaml
kubectl apply -f deployment.yaml -f service.yaml -f ingress.yaml
kubectl rollout status deployment/hello
until curl -sf -o /dev/null http://hello.localhost:8000/healthz; do sleep 1; done   # until Traefik routes the new host name
kubectl get ingress hello
for i in 1 2 3 4; do curl -s http://hello.localhost:8000/ | jq -c '{message, host}'; done
```

In the Windows browser, <http://hello.localhost:8000> works, too.

**Ask first:** we replace all three Pods (`rollout restart`) while 50 requests run. How many
fail?

<!-- run -->
```bash
for i in $(seq 50); do curl -s -o /dev/null -w '%{http_code}\n' http://hello.localhost:8000/; sleep 0.1; done | sort | uniq -c &
kubectl rollout restart deployment/hello
kubectl rollout status deployment/hello
wait                                                     # for the 50 requests
```

- **Ingress** is a routing rule: host and path to a Service. The **ingress controller** is
  the proxy that implements it: Traefik in k3s, others elsewhere (Azure: Application
  Gateway). The Ingress YAML stays the same. Typical for us: `/api` to the .NET backend's
  Service, everything else to the Angular front end's Service. The Gateway API is the newer
  successor to Ingress.
- **The way of a request:** `curl` → port 8000 on the laptop → a node → Traefik's Pod → the
  `hello` Service → one of the Pods.
- **The answer:** none, all 50 return `200`. Two lines in
  [`deployment.yaml`](hello/deployment.yaml) do that: the readiness probe (a new Pod gets
  traffic only when it's ready) and the `preStop` pause (an old Pod keeps serving for 5
  seconds while Traefik and the Service learn it's going away). Without the pause, some
  requests fail with `502` or `504`. **Agent trap:** "zero-downtime deployment" without a
  readiness probe and a `preStop` pause.
- **TLS** belongs here, too: the ingress controller terminates it, with certificates from
  cert-manager or Let's Encrypt.

If it breaks: 404 right after `apply` → Traefik needs a moment; repeat the `curl`.

---

## Step 7: ConfigMaps and Secrets

**Goal:** configuration from the cluster: the environment variables of the Docker half day,
as resources.

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
cat config.yaml
diff deployment.yaml deployment-config.yaml
kubectl apply -f config.yaml -f deployment-config.yaml -f service.yaml -f ingress.yaml
kubectl rollout status deployment/hello
sleep 6                                                      # the old Pods serve 5 s more (preStop)
curl -s http://hello.localhost:8000/config | jq
```

**Ask first:** we change the greeting in the ConfigMap. What do the running Pods say?

<!-- run -->
```bash
kubectl patch configmap hello-config --type merge -p '{"data":{"Greeting":"Changed in the cluster"}}'
sleep 2
curl -s http://hello.localhost:8000/ | jq .message
kubectl rollout restart deployment/hello                     # new Pods read the new values
kubectl rollout status deployment/hello
sleep 6
curl -s http://hello.localhost:8000/ | jq .message
```

How secret is a Secret? And then the `hello` app goes away:

<!-- run -->
```bash
cd ~/docker-k3s/k3s/hello
kubectl get secret hello-secrets -o jsonpath='{.data.ConnectionStrings__Default}' | base64 -d; echo
kubectl delete -f deployment-config.yaml -f config.yaml -f service.yaml -f ingress.yaml
```

- **ConfigMap** for settings, **Secret** for passwords and keys. `envFrom` turns every key
  into an environment variable, and `__` becomes the `:` of `appsettings.json`, exactly as
  with Docker: the app reads `Database:Host` and doesn't know it's in Kubernetes. A ConfigMap
  can also be mounted as a file, for example as `appsettings.Production.json`.
- **The answer:** the old greeting. Environment variables are read when the process starts;
  a ConfigMap change restarts nothing. **Agent trap:** changing a ConfigMap or Secret and
  expecting the running app to pick it up.
- **A Secret is base64, not encryption.** Whoever may read Secrets in the namespace reads the
  password; access is controlled with RBAC. **Agent trap:** a Secret manifest with a real
  password, committed to Git, like our `config.yaml`. In real projects, the values come from
  outside the repository, for example from Azure Key Vault via the External Secrets Operator.

If it breaks: `/config` shows the `appsettings.json` values → the Pods are from before the
`apply`; wait for `rollout status` and try again.

---

## Step 8: state, and a real app

**Goal:** a database whose data outlives its Pod, and the Compose app of the Docker half day
as a set of manifests.

Build and push the app, then apply the whole folder (namespace, Postgres, app):

<!-- run -->
```bash
cd ~/docker-k3s/docker/visit-counter
docker build -q -t localhost:5000/visit-counter:1.0 .
docker push -q localhost:5000/visit-counter:1.0
cd ~/docker-k3s/k3s/visits
kubectl apply -f .
kubectl -n visits rollout status deployment/postgres --timeout=180s
kubectl -n visits rollout status deployment/visit-counter --timeout=300s   # it may restart until Postgres is ready
until curl -sf -o /dev/null http://visits.localhost:8000/healthz; do sleep 1; done
sleep 3                                                                  # until Traefik knows all three Pods
for i in 1 2 3 4 5 6; do curl -s http://visits.localhost:8000/ | jq -c; done
kubectl -n visits get pvc
```

**Ask first:** we delete the Postgres Pod. What does the counter say afterwards?

<!-- run -->
```bash
kubectl -n visits delete pod -l app=postgres
kubectl -n visits wait --for=condition=Ready pod -l app=postgres --timeout=120s
for i in 1 2 3 4 5 6; do curl -s -w ' %{http_code}\n' http://visits.localhost:8000/; sleep 0.5; done
```

What we deployed, compared with Compose:

<!-- run -->
```bash
kubectl -n visits get all,ingress,pvc,secret
wc -l ~/docker-k3s/docker/compose-traefik/compose.yaml ~/docker-k3s/k3s/visits/*.yaml
```

Clean up; deleting the namespace deletes the claim, and with it the data:

<!-- run -->
```bash
kubectl delete namespace visits
```

- **Read [`visits/2-visit-counter.yaml`](visits/2-visit-counter.yaml) top to bottom** with
  the room: every block is something from today. A Secret with the connection string
  (`Host=postgres`, the Service name), a Deployment with three replicas, resources,
  readiness and liveness probes, the `preStop` pause, a `securityContext`, a Service, an
  Ingress for `visits.localhost`. A real app with an Angular front end is this file twice
  and one Ingress with two paths.
- **Three pieces of storage** ([`visits/1-postgres.yaml`](visits/1-postgres.yaml)): the
  **PersistentVolumeClaim** is the app's request ("1 GiB, one node at a time"), the
  **PersistentVolume** is the actual storage, and the **StorageClass** makes one when a claim
  asks. In k3s that's a folder on a node; in AKS an Azure Disk, which can move with the Pod.
  The manifest is the same.
- **The answer:** first a few `500`s, about one per app Pod, then the counter goes on where
  it was. The data is in the volume, not in the container, like the named volume of the
  Docker half day. The `500`s are each Pod's pooled connection, still pointing at the old
  Postgres process: Npgsql throws it away and the next request reconnects. A database
  restart costs every caller that doesn't retry one error; in a real app, retries belong in
  the data access (EF Core's `EnableRetryOnFailure`, Polly).
- **No `depends_on`.** The app may start before the database: it crashes, the kubelet
  restarts it, and it recovers at the next try. Kubernetes' answer to startup order is retry,
  with readiness keeping traffic away meanwhile. The same retries in the app would do
  better than crashing.
- **One database, one volume:** `replicas: 1` and the `Recreate` strategy, so two Postgres
  processes never share a data folder. **Agent trap:** a database Deployment with several
  replicas, or with the default rolling update. In production: a managed database (Azure
  Database for PostgreSQL) or an operator; backups and failover are the hard part.
- **Liveness:** a failing liveness probe restarts the container. **Agent trap:** a liveness
  probe that checks the database: when the database is down, every Pod restarts in a loop.
- **`securityContext`** is the Docker half day's `--read-only --cap-drop ALL`, plus
  `runAsNonRoot`: the cluster refuses an image that would run as root.
- **About 170 lines of YAML instead of 55 lines of Compose.** Each extra line says something
  Compose couldn't: probes, resources, security, and that this runs across machines. That's
  why agents write these files, and why you have to be able to read them.
- **Agent trap:** `kubectl delete namespace` in a cleanup script, next to a database.

If it breaks: `visit-counter` stays in `CrashLoopBackOff` after Postgres is ready → wait for
the next restart, or `kubectl -n visits rollout restart deployment/visit-counter`.

---

## Step 9: troubleshooting

**Goal:** a recipe for every broken Pod: status, events, logs.

Five broken apps from [`troubleshooting/`](troubleshooting), each with a different mistake:

<!-- run -->
```bash
cd ~/docker-k3s/docker/visit-counter
docker build -q -t localhost:5000/visit-counter:1.0 .     # from the cache, if step 8 ran
docker push -q localhost:5000/visit-counter:1.0
cd ~/docker-k3s/k3s/troubleshooting
kubectl apply -f 0-namespace.yaml -f 1-catalog.yaml -f 2-orders.yaml -f 4-reports.yaml -f 5-webshop.yaml -f 7-inventory.yaml
sleep 30                                                  # give them time to fail
kubectl -n troubleshooting get pods
```

**Ask first:** which of the five apps is healthy?

**Your turn:** each table takes one app and finds the cause, with this recipe:

<!-- run -->
```bash
kubectl -n troubleshooting get pods                                         # 1. STATUS and RESTARTS
kubectl -n troubleshooting describe pod -l app=catalog | tail -4            # 2. the Events, at the end of describe
kubectl -n troubleshooting logs deploy/orders | head -2                     # 3. what the app said before it died
kubectl -n troubleshooting get events --field-selector type=Warning --sort-by=.lastTimestamp | tail -6   # 4. all warnings
```

The presenter's walkthrough of the other three, then two fixes (in real life: in the file):

<!-- run -->
```bash
cd ~/docker-k3s/k3s/troubleshooting
kubectl -n troubleshooting describe pod -l app=reports | grep -m1 FailedScheduling
kubectl -n troubleshooting get endpointslices -l kubernetes.io/service-name=webshop
grep -n 'app:' 5-webshop.yaml
kubectl -n troubleshooting describe pod -l app=inventory | grep -m1 'Readiness probe failed'
kubectl -n troubleshooting set image deployment/catalog catalog=localhost:5000/hello-web:1.0
kubectl -n troubleshooting patch service webshop -p '{"spec":{"selector":{"app":"webshop"}}}'
kubectl -n troubleshooting rollout status deployment/catalog
kubectl -n troubleshooting get endpointslices -l kubernetes.io/service-name=webshop
kubectl delete namespace troubleshooting
```

| App | `STATUS` | Where you see the cause | The mistake |
| --- | --- | --- | --- |
| catalog | `ErrImagePull`, `ImagePullBackOff` | `describe`: "not found" | tag `1.O` with a letter O |
| orders | `Error`, `CrashLoopBackOff` | `logs`: "Connection string 'Visits' is missing" | no Secret, no `envFrom` |
| reports | `Pending` | `describe`: "0/3 nodes are available: 3 Insufficient cpu" | requests 64 CPUs |
| webshop | `Running`, and still no answer | the Service has no endpoints | selector `web-shop`, label `webshop` |
| inventory | `Running`, but `0/1` ready | `describe`: "Readiness probe failed: ... connection refused" | probe on port 80; ASP.NET Core listens on 8080 |

- **The answer:** none. `webshop` looks healthy (`1/1 Running`), and nobody reaches it;
  `inventory` runs, and is never ready.
- **The recipe:** `get` for the status, `describe` for the events (everything the cluster
  did and failed to do with this Pod), `logs` for what the app said (`--previous` for the run
  before a crash), `get events` for the whole namespace. All day long: `kubectl get pods -w`
  and `kubectl logs -f deploy/<name>`.
- **Read the status as a stage:** `Pending` = no node fits (scheduling), `ErrImagePull` =
  the node can't get the image, `CrashLoopBackOff` = the app starts and exits, `Running` but
  not ready = the readiness probe fails. Each stage has its own place to look.
- **webshop is the quietest:** everything is green, and the Service sends traffic nowhere. A
  label typo; `kubectl get endpointslices` is the check. **Agent trap.**
- **inventory is the most common .NET mistake** in agent-written manifests: port 80, from
  the times before .NET 8. Since .NET 8, the ASP.NET Core images listen on 8080. The logs
  look perfect; only `describe` shows the failing probe. **Agent trap.**
- **Agents are good at this,** if you give them the facts: paste the `describe` and `logs`
  output rather than "my Pod doesn't work". Graphical helpers: k9s, Headlamp, the
  Kubernetes extension for VS Code.

If it breaks: `logs` shows nothing → the container is restarting right now; run it again.

---

## Step 10: wrap-up

**Goal:** the map of the session, the agent traps, and a clean laptop.

| Docker | Kubernetes | Step |
| --- | --- | --- |
| `docker` CLI → engine | `kubectl` → API server; contexts | 1 |
| `docker run` | Pod | 2 |
| `--restart`, Compose replicas | Deployment: desired state, self-healing, `scale` | 3 |
| `docker compose up` after a change | rolling update, `rollout undo` | 4 |
| network and container names | Service and DNS | 5 |
| Traefik with labels | Ingress | 6 |
| `-e`, `--env-file` | ConfigMap, Secret, `envFrom` | 7 |
| named volume | PersistentVolumeClaim, StorageClass | 8 |
| `compose.yaml` | a folder of manifests, `kubectl apply -f .` | 8 |
| health check | readiness and liveness probes | 4, 6, 8 |
| `docker logs`, `inspect`, `ps` | `kubectl logs`, `describe`, `get`, events | 9 |

The agent traps: read every generated manifest with this list in mind.

| Trap | Step |
| --- | --- |
| `kubectl` against the wrong context | 1 |
| no resource requests and limits | 3 |
| fixing the cluster with `scale`, `edit`, `set` instead of the file | 3, 4 |
| no readiness probe; "zero downtime" without a `preStop` pause | 4, 6 |
| a new image under an old tag | 4 |
| `Host=localhost` instead of the Service name | 5 |
| real secrets in a committed Secret manifest | 7 |
| expecting a changed ConfigMap to reach running Pods | 7 |
| a database Deployment with several replicas or rolling updates | 8 |
| a liveness probe that checks the database | 8 |
| a Service selector that doesn't match the Pod labels | 9 |
| port 80 instead of 8080 for ASP.NET Core 8 and later | 9 |

- **What's next, when you need it:** Helm or Kustomize (manifests per environment), GitOps
  with Flux or Argo CD (the cluster pulls its state from Git), Jobs and CronJobs (a Pod that
  runs to completion, once or on a schedule: migrations, nightly tasks), and a managed
  cluster (AKS). The full [k3s storybook](storybook.md) covers more of it.
- The vocabulary is new; the containers are the same as in the Docker half day.

Delete the cluster; the registry stays:

<!-- run -->
```bash
docker network disconnect k3d-workshop registry      # or the cluster's network stays behind
k3d cluster delete workshop
kubectl config get-contexts                          # what kubectl points at now
```

After the delete, `kubectl` points at nothing, or at whatever other cluster is in
`~/.kube/config`: check before the next `apply`.

At the very end, the registry, its data, the login, and the images we built:

<!-- run -->
```bash
docker rm -f registry
docker volume rm workshop-registry-data
docker logout localhost:5000
docker image rm localhost:5000/visit-counter:1.0 2>/dev/null
```

---

## Troubleshooting

- **`kubectl` talks to the wrong cluster:** `kubectl config use-context k3d-workshop`.
- **`ImagePullBackOff` with "no such host"** for `registry`:
  `docker network connect k3d-workshop registry`.
- **`ImagePullBackOff` with "not found":** the image isn't in the registry, or the tag has a
  typo. `curl -s -u workshop:docker-k3s localhost:5000/v2/<name>/tags/list`.
- **After a Docker Desktop restart:** `k3d cluster start workshop`.
- **Start fresh:** `k3d cluster delete workshop`, then step 1.
