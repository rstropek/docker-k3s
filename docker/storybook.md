# Storybook: Docker for .NET developers

**Half day 1 of the Docker and k3s workshop for the MI-SA development team**

This is the presenter's guide, not a book to follow alone. Improvisation is part of the plan. The
audience is experienced C# developers who live on Windows and know a little Linux. The goal
is the fundamentals: what an image, a container, a volume, and a network really are, so that
later, when a coding agent writes a Dockerfile or a Compose file, they can read and judge it.
Details that an agent gets right anyway stay out.

No slides, no agent prompts: small, independent demos with plain `docker` commands. Each step
has a goal, copyable blocks, talking points, and one line for "if it breaks". Each step can
be shown on its own: if it needs an image from an earlier step, its first block builds it
(a cache hit if it exists already), and it ends by removing exactly what it created.

Three recurring markers:

- **Ask first:** a prediction question before a block. Let the room answer, then run it.
  The answer is in the talking points, not in the block.
- **Your turn:** a minute or two for the participants who build along.
- **Agent trap:** a mistake coding agents (and tutorials) make often. They are collected in
  [step 17](#step-17-wrap-up-from-docker-to-k3s); that list is what the morning should leave
  behind.

**Setup:** Docker Desktop on Windows, and every command runs in **bash inside WSL (Ubuntu)**,
with this repository cloned to `~/docker-k3s`. Linux containers, .NET 10. Everything the
workshop creates is named `workshop-...` or has a short name like `hello` or `db`, and is
removed by that name; nothing in here prunes.

The demos were rehearsed on 6 October 2026 with Docker Engine 29.7.1, Compose 5.5.1, and the
.NET 10.0.12 images on Linux (x86-64). The rehearsal script ([`rehearsal/run-blocks.py`](../rehearsal/run-blocks.py))
runs every block marked `<!-- run -->` in order and times it. A second, independent
walkthrough by a fresh agent ran every block, including the unmarked ones. Where Docker
Desktop behaves differently from a native Linux engine, the step says so.

## Timing

Machine time per step in the rehearsal: commands only, measured by `run-blocks.py`, with the
images pre-pulled and the NuGet and build caches from earlier runs. The first build of the
day adds a few seconds per Dockerfile (the naive build took 6 s cold). Everything else in a
step is talking, which is the point. A natural break: after step 7, the end of Part 1.

| Step | Topic | Machine time |
| --- | --- | ---: |
| 1 | setup check | < 1 s |
| 2 | a container is a process | 2 s |
| 3 | images and containers | 1 s |
| 4 | the first Dockerfile | 4 s (9 s when the build isn't cached) |
| 5 | layer cache and `.dockerignore` | 17 s |
| 6 | multi-stage and chiseled | 4 s |
| 7 | images without a Dockerfile (optional) | 9 s |
| 8 | run and watch | 6 s |
| 9 | how a container ends | 22 s (10 s of it is the shell-form `docker stop`) |
| 10 | configuration with environment variables | 9 s |
| 11 | volumes | 10 s |
| 12 | registries | 7 s |
| 13 | networks | 9 s |
| 14 | Docker Compose | 11 s |
| 15 | a reverse proxy: Traefik | 16 s |
| 16 | slim and secure images | 30 s (the first Trivy run downloads its database) |
| 17 | wrap-up: from Docker to k3s | < 1 s |
| | **total** | **about 2.5 minutes** |

## Before the workshop

**Participants** (send this a week ahead):

- Windows 11 with WSL 2 and Ubuntu 24.04:
  ```powershell
  wsl --install -d Ubuntu-24.04
  ```
- Docker Desktop, with WSL integration switched on for that distro (Settings → Resources →
  WSL integration). Docker Desktop is free for personal use, education, and companies below
  250 employees **and** USD 10 million revenue; everyone else needs a paid subscription.
  Check that before the workshop, not during it.
- In the Ubuntu shell: clone the repository into the Linux home, never under `/mnt/c`, and
  run the checks:
  ```bash
  sudo apt-get update && sudo apt-get install -y git curl jq
  git clone https://github.com/rstropek/docker-k3s.git ~/docker-k3s
  cd ~/docker-k3s/docker
  ./setup-check.sh
  ./prepull.sh          # about 1 GB to download, 3.5 GB on disk: not over conference wifi
  ```
- Optional, only for step 7: the .NET 10 SDK inside WSL (Ubuntu 24.04 has it in its own
  package feed). Nobody needs it for anything else: all other builds run inside the SDK
  image.
  ```bash
  sudo apt-get install -y dotnet-sdk-10.0
  ```

**Presenter:**

- The participant checks above, plus `../rehearsal/run-blocks.py --list` to see that the
  storybook and the rehearsal script agree.
- Terminal at 20 pt or larger. `jq` installed: almost every `curl` is piped into it.
- Ports 5000, 8000, 8080, and 8090 free (see [Ports](#ports)).
- Before showing `~/.docker/config.json` (step 12) on the projector, make sure no real
  credentials are in it; the block only prints the registry names.

---

# Part 1: containers and images

## Step 1: setup check

**Goal:** everybody has a working engine, and knows that `docker` is only a client.

<!-- run -->
```bash
docker version --format 'client {{.Client.Version}}, server {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'
docker context ls
docker info --format '{{.OperatingSystem}} | kernel {{.KernelVersion}} | {{.NCPU}} CPUs | {{.MemTotal}} bytes'
pwd
```

- **Client and server.** The `docker` CLI sends requests to the Docker engine (the daemon,
  `dockerd`) over an API. `docker version` shows both halves; if the server half is
  missing, the CLI can't reach the engine. `docker context ls` shows where the CLI sends its
  requests; with Docker Desktop you may see a `desktop-linux` context next to `default`.
- **Where is the engine?** Docker Desktop runs it in a small Linux VM, the same WSL 2 VM
  your Ubuntu runs in. The `docker` in your Ubuntu shell is just a client talking to it, and
  so is the one in PowerShell. On a Linux server there is no VM: the engine runs on the
  host.
- **Keep your files in the Linux filesystem** (`/home/<you>/...`), not under `/mnt/c`.
  Bind mounts and builds from `/mnt/c` go through a cross-OS file share: much slower, and
  file change notifications don't arrive.
- **Bash you'll see today**, in one minute:
  - `a | b` pipes the output of `a` into `b` (`curl ... | jq` formats JSON),
  - `$(...)` runs a command and uses its output as a value,
  - `2>&1` merges the error output into the normal output,
  - `$PWD` is the current folder, `~` your home folder,
  - `\` at the end of a line continues the command on the next line,
  - `# ...` is a comment.

If it breaks: "Cannot connect to the Docker daemon" → Docker Desktop isn't running, or WSL
integration is off for this distro (Settings → Resources → WSL integration).

## Step 2: a container is a process

**Goal:** the difference between a container and a virtual machine, seen in a few commands.

**Ask first:** a container with Alpine Linux runs on your Ubuntu in WSL. Which kernel
version does it report: Alpine's or Ubuntu's?

<!-- run -->
```bash
uname -r                                              # the kernel version, here in WSL
docker run --rm alpine:3.24 uname -r                  # and inside an Alpine container
docker run --rm alpine:3.24 head -2 /etc/os-release   # which distribution is in there?
docker run --rm ubuntu:24.04 head -2 /etc/os-release
time docker run --rm alpine:3.24 true                 # start, run, stop, remove: how long?
docker run --rm alpine:3.24 ps                        # which processes run in a container?
```

A container's process, seen from both sides:

<!-- run -->
```bash
docker run -d --name sleeper alpine:3.24 sleep 600
docker top sleeper            # the process as the engine's host sees it, with a host process ID
docker exec sleeper ps        # the same process inside the container
docker rm -f sleeper
```

- **The answer:** the same kernel everywhere, but a different distribution in each
  container, a start in well under a second, and a process list with one entry: your
  command as PID 1 (process ID 1, the first process; on Linux, PID 1 has a special job,
  step 9).
- **A VM** virtualizes hardware and boots its own kernel. **A container** is an ordinary
  Linux process on the host's kernel, with two kinds of fences around it:
  - **namespaces** decide what it *sees*: its own process list, hostname, network,
    filesystem,
  - **cgroups** (control groups) decide what it may *use*: CPU, memory (step 8).
- The image brings the distribution's files (Alpine, Ubuntu), never a kernel. That's why
  the kernel version is the same everywhere and why a container starts in milliseconds.
- **Linux containers need a Linux kernel.** That's the reason Docker Desktop needs WSL 2.
  Windows containers exist (Windows kernel, Windows base images, Windows Server hosts), but
  .NET on Linux containers is the mainstream, and k3s is Linux only.
- **The flags of today:** `--rm` removes the container when its process ends, `-d` runs it
  in the background (detached), `--name` gives it a name we can use instead of the ID,
  `docker exec` starts a second process inside a running container, `docker rm -f` kills
  and removes it.

If it breaks: `time` shows several seconds → the image wasn't there yet and the first run
included the download; run it again.

## Step 3: images and containers

**Goal:** an image is a stack of read-only layers plus metadata; a container is an image
plus a writable layer plus a process.

<!-- run -->
```bash
docker pull mcr.microsoft.com/dotnet/aspnet:10.0
docker image ls mcr.microsoft.com/dotnet/aspnet
docker image history mcr.microsoft.com/dotnet/aspnet:10.0                  # the layers, newest first
docker image inspect mcr.microsoft.com/dotnet/aspnet:10.0 --format '{{json .Config.Env}}' | jq
```

**Ask first:** container `one` writes a file. Container `two` starts from the same image.
Does it see the file?

<!-- run -->
```bash
docker run --name one alpine:3.24 sh -c 'echo hello > /greeting.txt'
docker run --name two alpine:3.24 cat /greeting.txt
docker diff one                                         # what "one" changed on top of the image
docker ps -a --filter name=one --filter name=two        # do the containers still exist?
docker rm one two
```

**Your turn:** look around in an Ubuntu container for two minutes, then `exit`. Does the
container still exist afterwards? (`docker ps -a`)

```bash
docker run -it --rm ubuntu:24.04 bash
# inside: cat /etc/os-release; ls /; apt --version; exit
```

- **The answer:** no. Every container has its own writable layer on top of the shared,
  read-only image. `docker diff` shows what a container changed (`A` = added).
- **Image names:** `alpine:3.24` is short for `docker.io/library/alpine:3.24`:
  registry / repository : tag. Microsoft's images live on `mcr.microsoft.com`, not on Docker
  Hub.
- **Layers** are shared: ten images on the same `aspnet:10.0` store its layers once. The
  config holds what the image runs (`Entrypoint`, `Cmd`), as whom (`User`), and with which
  environment (`Env`). In the `aspnet` image you can already see `ASPNETCORE_HTTP_PORTS=8080`
  and `APP_UID=1654`; both come back later.
- `docker image ls` shows two sizes: unpacked on disk, and compressed (what travels over the
  network).
- **Lifecycle:** created → running → exited → removed. `docker ps` shows running containers,
  `docker ps -a` all of them. A stopped container keeps its writable layer until you remove
  it, and then it's gone. Anything worth keeping goes into a volume (step 11).
- **Agent trap:** .NET 10 images are based on Ubuntu 24.04 (Noble). There are no Debian
  images any more; `-bookworm-slim` tags from older Dockerfiles (and from an agent's
  memory) stop at .NET 9.

If it breaks: `toomanyrequests` from Docker Hub → anonymous pulls are rate-limited;
`docker login` with a free account, or use the pre-pulled images.

## Step 4: the first Dockerfile

**Goal:** a C# web app in an image, built without a .NET SDK on your machine.

The app ([`hello-web/Program.cs`](hello-web/Program.cs)) is an empty ASP.NET Core app that
reports where it runs: host name, OS, user, CPUs, and memory limit. It also has a few
endpoints for later steps (`/config`, `/request`, `/alloc/{mb}`, `/crash`, `/healthz`).

[`hello-web/Dockerfile.1-naive`](hello-web/Dockerfile.1-naive):

```dockerfile
# 1: the naive Dockerfile. It works, but the SDK ships to production and every code change restores again.
FROM mcr.microsoft.com/dotnet/sdk:10.0
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app
WORKDIR /app
ENTRYPOINT ["dotnet", "HelloWeb.dll"]
```

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
docker build -f Dockerfile.1-naive -t hello-web:1-naive .
docker run -d --name hello -p 8080:8080 hello-web:1-naive
sleep 2                                                  # give the app a moment to start
curl -s localhost:8080 | jq
docker logs hello
docker rm -f hello
```

Open <http://localhost:8080> in the Windows browser, too: Docker Desktop forwards published
ports to Windows.

- **The build runs in a container.** `FROM` the SDK image, copy the sources, `dotnet
  publish`, and the result is an image. Nobody needs the .NET SDK installed to build it,
  and everybody builds with the same SDK version.
- **The build context** is the `.` at the end: that folder is sent to the builder, and
  `COPY` can only see what's in it.
- **`ENTRYPOINT`** is the process that becomes PID 1, written as a JSON array (step 9 shows
  why).
- **Port 8080.** Since .NET 8, ASP.NET Core in the official images listens on 8080, not 80
  (`ASPNETCORE_HTTP_PORTS`), so it can run as a non-root user. `launchSettings.json` with
  its port 5180 is a Visual Studio and `dotnet run` thing; the container never reads it.
- **`-p 8080:8080`** is host port : container port. Without `-p` the app runs, but nothing
  outside Docker's network reaches it.
- Read the JSON: `host` is the container ID, `os` is Ubuntu 24.04, `environment` is
  `Production` (nobody set `ASPNETCORE_ENVIRONMENT`), and `user` is **root**. Remember that
  one.

If it breaks: "port is already allocated" → another container has 8080;
`docker ps --filter publish=8080`, then remove it.

## Step 5: layer cache and `.dockerignore`

**Goal:** why the order of a Dockerfile matters, and what goes into the build context.

Every instruction is a layer, cached by the instruction and its inputs. The first changed
layer rebuilds, and so does everything after it.

**Ask first:** we change one line of C#. Which steps of `Dockerfile.1-naive` run again?

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
docker build -f Dockerfile.1-naive -t hello-web:1-naive .           # nothing changed: watch for CACHED
echo "// change $RANDOM" >> Program.cs                              # append a comment line to the C# file
docker build -f Dockerfile.1-naive -t hello-web:1-naive .           # which steps say CACHED now?
sed -i '/^\/\/ change /d' Program.cs                                # remove the line again
```

`COPY . .` copied a changed file, so everything after it runs again, NuGet restore
included. Now the order that .NET's official sample uses
([`Dockerfile.2-layers`](hello-web/Dockerfile.2-layers)):

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0
WORKDIR /src
COPY HelloWeb.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app --no-restore
WORKDIR /app
ENTRYPOINT ["dotnet", "HelloWeb.dll"]
```

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
docker build -f Dockerfile.2-layers -t hello-web:2-layers .
echo "// change $RANDOM" >> Program.cs
docker build -f Dockerfile.2-layers -t hello-web:2-layers .         # RUN dotnet restore: CACHED
sed -i '/^\/\/ change /d' Program.cs
```

The build context, with and without [`.dockerignore`](hello-web/.dockerignore). Pretend
Visual Studio just built into `bin/`:

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
cat .dockerignore
mkdir -p bin/Debug && head -c 300M /dev/zero > bin/Debug/huge.dll   # a 300 MB dummy file
docker build -f Dockerfile.2-layers -t hello-web:2-layers .         # look for "transferring context"
mv .dockerignore .dockerignore.off                                  # switch .dockerignore off
docker build -f Dockerfile.2-layers -t hello-web:2-layers .
docker image ls hello-web:2-layers                                  # how big is the image now?
mv .dockerignore.off .dockerignore
rm -rf bin
docker build -q -f Dockerfile.2-layers -t hello-web:2-layers .
```

- **The answer:** with `COPY . .` first, any change to any file rebuilds everything after
  it. Order from rarely changing to often changing: the project file (packages) changes
  rarely, the code all the time. Restore in its own layer means NuGet packages download
  once, not on every build. With a solution, copy every `.csproj` (and
  `Directory.Packages.props`) first.
- **`.dockerignore` is `.gitignore` for the build context.** Without it, `bin/` and `obj/`
  from your Windows build are sent to the builder (2 bytes vs. 315 MB in the rehearsal), and
  `COPY . .` puts them into the image (300 MB bigger). It's slow, it bloats the image, and
  `obj/project.assets.json` with Windows paths in it breaks `dotnet publish` inside the
  container.
- **Agent trap:** a Dockerfile without a `.dockerignore` next to it.
- The cache is why CI builds can be fast, and why `--no-cache` exists when you distrust it.

If it breaks: a build fails with odd errors about `project.assets.json` → `bin/` or `obj/`
got into the context; check that `.dockerignore` is there.

## Step 6: multi-stage and chiseled

**Goal:** build with the SDK, ship only the runtime. Then ship even less.

[`Dockerfile.3-multistage`](hello-web/Dockerfile.3-multistage):

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY HelloWeb.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENTRYPOINT ["dotnet", "HelloWeb.dll"]
```

[`Dockerfile.4-chiseled`](hello-web/Dockerfile.4-chiseled) differs only in the base image of
the second stage (and its comment):

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
diff Dockerfile.3-multistage Dockerfile.4-chiseled
docker build -f Dockerfile.3-multistage -t hello-web:3-multistage .
docker build -f Dockerfile.4-chiseled -t hello-web:4-chiseled .
docker image ls hello-web
```

**Ask first:** how do you get a shell inside a chiseled container?

<!-- run -->
```bash
docker run -d --name hello -p 8080:8080 hello-web:4-chiseled
sleep 2                                  # give the app a moment to start
curl -s localhost:8080 | jq '{os, user}'
docker exec hello sh -c 'echo hi'
docker rm -f hello
```

Rehearsal sizes (on disk / compressed):

| Image | Base | Size |
| --- | --- | ---: |
| `hello-web:1-naive` | `sdk:10.0` | 1.31 GB / 354 MB |
| `hello-web:3-multistage` | `aspnet:10.0` | 341 MB / 96 MB |
| `hello-web:4-chiseled` | `aspnet:10.0-noble-chiseled` | 181 MB / 56 MB |

- **Multi-stage:** the first stage has the SDK, compilers, and NuGet; only its `/app` output
  is copied into the second stage. The final image never contains the SDK or your sources.
  **Agent trap:** a single-stage Dockerfile that ships the SDK.
- **This is what Visual Studio generates**, too: "Add → Docker Support" writes a multi-stage
  Dockerfile (stages `base`, `build`, `publish`, `final`) with `USER app` and
  `EXPOSE 8080`. Now you can read it.
- **The same pattern for Angular:** stage 1 `FROM node`, `npm ci`, `ng build`; stage 2
  `FROM nginx`, copy `dist/`. Node never ships.
- **The answer:** you don't. **Chiseled** Ubuntu images contain only the files .NET needs: no
  shell, no package manager, and they run as the non-root user `app` (UID 1654). Less to
  download, less to patch, less for an attacker to use. Debugging means logs and metrics
  (step 8); `docker debug` in Docker Desktop attaches a toolbox to a shell-less container.
- **Globalization:** the chiseled image runs in invariant mode, without culture data or time
  zones. Formatting with `de-AT` or converting to `Europe/Vienna` needs the
  `10.0-noble-chiseled-extra` variant (ICU and tzdata).
- `EXPOSE 8080` publishes nothing. It documents the port, and tools read it (Traefik in
  step 15).

If it breaks: the app crashes with `CultureNotFoundException` in the chiseled image → it
needs culture data; use `aspnet:10.0-noble-chiseled-extra`.

## Step 7: images without a Dockerfile (optional)

**Goal:** the .NET SDK can build a container image by itself. Needs the .NET 10 SDK in WSL
(see [Before the workshop](#before-the-workshop)); otherwise show it from the presenter's
machine.

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
dotnet publish --os linux --arch x64 /t:PublishContainer \
  -p ContainerRepository=hello-web -p ContainerImageTag=sdk -p ContainerFamily=noble-chiseled
docker image ls hello-web
docker inspect hello-web:sdk --format 'user {{.Config.User}}, ports {{json .Config.ExposedPorts}}'
docker inspect hello-web:sdk --format '{{json .Config.Labels}}' | jq
rm -rf bin obj                           # the local build output
```

- **No Dockerfile, no Docker needed to build.** The SDK assembles the layers itself and
  hands them to Docker at the end (or pushes them to a registry, step 12). It picks the base
  image (`aspnet` for web apps), the port, and the non-root user.
- **We asked for `noble-chiseled`, the SDK made it `noble-chiseled-extra`** (see the
  `base.name` label): the project doesn't set
  `<InvariantGlobalization>true</InvariantGlobalization>`, so the SDK keeps culture data.
  The SDK knows the app; a Dockerfile doesn't.
- **When a Dockerfile still wins:** OS packages, several build steps, non-.NET parts (the
  Angular stage from step 6). A Dockerfile is also what every other tool (CI, Compose, an
  agent) understands.
- The settings can live in the `.csproj` (`ContainerRepository`, `ContainerFamily`, ...)
  instead of on the command line.

If it breaks: `dotnet: command not found` → this step needs the SDK in WSL; everything else
doesn't.

---

# Part 2: running containers

## Step 8: run and watch

**Goal:** what you do with a running container, and how limits look from inside .NET.

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
docker build -q -f Dockerfile.4-chiseled -t hello-web:4-chiseled .
docker run -d --name hello -p 8080:8080 --memory 256m --cpus 1.5 hello-web:4-chiseled
sleep 2                                                      # give the app a moment to start
docker ps --filter name=hello
docker logs hello
curl -s localhost:8080 | jq '{cpus, memoryLimitMb}'
docker stats --no-stream hello
docker inspect hello --format '{{.State.Status}} since {{.State.StartedAt}}, restarts: {{.RestartCount}}'
```

Live, in a second terminal (not rehearsed; `Ctrl+C` to leave):

```bash
docker logs -f hello
docker stats
```

**Ask first:** the container may use 256 MB. The app allocates 100 MB, then 200 MB more.
What happens?

<!-- run -->
```bash
curl -s localhost:8080/alloc/100 | jq
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/alloc/200     # prints the HTTP status code
docker logs hello 2>&1 | grep -m1 OutOfMemoryException                # the first matching log line
docker ps --filter name=hello --format '{{.Names}}: {{.Status}}'
```

And a process that doesn't know its limit:

<!-- run -->
```bash
docker run --name oom --memory 64m alpine:3.24 sh -c 'tail /dev/zero'; echo "exit code $?"   # tail reads an endless stream into memory
docker inspect oom --format 'OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}}'
docker rm oom
docker rm -f hello
```

- **`-d`, `ps`, `logs`, `stats`, `inspect`, `exec`** cover nearly all day-to-day work.
  Logs are whatever the process writes to stdout and stderr, so log to the console in
  containers, not to files.
- **Limits are cgroups** (step 2). `--memory 256m` and `--cpus 1.5` are enforced by the
  kernel, and .NET reads them: `Environment.ProcessorCount` is 2 and the GC heap limit is
  75 % of the container's memory (192 MB).
- **The answer:** .NET throws an `OutOfMemoryException`, the request fails with a 500, and
  the process survives. A process that doesn't know its limit (the `tail` above) is killed
  by the kernel: `OOMKilled=true`, exit code 137. Kubernetes reports the same thing as
  `OOMKilled` (Windows analogy: Task Manager → End task, but done by the OS).

If it breaks: `/alloc/200` doesn't fail → the container runs without `--memory`; check
`docker inspect hello --format '{{.HostConfig.Memory}}'`.

## Step 9: how a container ends

**Goal:** stop, crash, restart, and what the exit code tells you.

**Ask first:** `docker stop` on our app takes a fraction of a second. The second image is
identical except for one line in its Dockerfile. How long does `docker stop` take there?

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
docker build -q -f Dockerfile.4-chiseled -t hello-web:4-chiseled .
docker run -d --name hello hello-web:4-chiseled
sleep 2                                         # give the app a moment to start
time docker stop hello
docker logs hello 2>&1 | tail -3                # the app's last words
docker build -q -f Dockerfile.shell-form -t hello-web:shell-form .
diff Dockerfile.3-multistage Dockerfile.shell-form
docker run -d --name shellform hello-web:shell-form
sleep 2
time docker stop shellform
docker ps -a --filter name=shellform --format '{{.Names}}: {{.Status}}'
docker rm hello shellform
```

**Crashing and restarting:**

<!-- run -->
```bash
docker run -d --name hello -p 8080:8080 --restart on-failure hello-web:4-chiseled
sleep 2
curl -s localhost:8080/crash; echo              # the app exits with code 3
sleep 3
docker inspect hello --format 'restarts: {{.RestartCount}}, status: {{.State.Status}}'
docker rm -f hello
```

- **`docker stop` sends a signal, then waits, then kills.** First SIGTERM ("please shut
  down", like closing a console window, which ends up in .NET's `ApplicationStopping`),
  then, after 10 seconds, SIGKILL ("end task", no cleanup possible).
- **The answer:** 10 seconds, and exit code 137. With `ENTRYPOINT dotnet HelloWeb.dll`
  (shell form, without the JSON brackets), PID 1 is `/bin/sh`, not your app, and `sh`
  doesn't pass the signal on. .NET never hears it, and every stop ends in a kill. **Agent
  trap:** shell-form `ENTRYPOINT` or `CMD`. Always the JSON form.
- **Exit codes, simplified:** 0 is success; small numbers are the app's own (`/crash`
  exits with 3); **137** means killed (out of memory, or the stop deadline ran out). An
  unhandled .NET exception ends as a crash, 139 on Linux.
- **Restart policies:** `no` (default), `on-failure`, `unless-stopped`, `always`. The engine
  restarts the process; that's the small version of what Kubernetes does with a whole
  cluster.
- **Removing:** `docker rm -f` kills and removes. `docker system df` shows what uses space.
  **Agent trap:** `docker system prune` or `docker volume prune` to "clean up". They remove
  everything unused on the machine, including other projects' databases. Remove your own
  things by name.

If it breaks: the .NET app also takes 10 seconds to stop → it's busy with long requests; the
.NET host waits up to 30 seconds for them, Docker only 10 (`docker stop -t 30`).

## Step 10: configuration with environment variables

**Goal:** one image for every environment; the configuration comes from outside.

**Ask first:** how do you get different settings into production today?
(`appsettings.Production.json`? Transformations in the build? IIS settings?)

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
docker build -q -f Dockerfile.4-chiseled -t hello-web:4-chiseled .
docker run -d --name hello -p 8080:8080 hello-web:4-chiseled
sleep 2                                                        # give the app a moment to start
curl -s localhost:8080/config | jq                             # from appsettings.json
docker rm -f hello
docker run -d --name hello -p 8080:8080 \
  -e Greeting="Hello from an environment variable" \
  -e Database__Host=db.example.internal \
  -e ConnectionStrings__Default="Host=db;Username=app;Password=secret" \
  -e ASPNETCORE_ENVIRONMENT=Development \
  hello-web:4-chiseled
sleep 2
curl -s localhost:8080/config | jq
curl -s localhost:8080 | jq .environment
docker rm -f hello
```

**Your turn:** start it with your own `-e Greeting=...` and check `/config`.

The same from a file ([`hello.env`](hello-web/hello.env)), and who can read it:

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
cat hello.env
docker run -d --name hello -p 8080:8080 --env-file hello.env hello-web:4-chiseled
sleep 2
curl -s localhost:8080/config | jq
docker inspect hello --format '{{json .Config.Env}}' | jq      # anyone who can talk to the engine sees them
docker rm -f hello
```

And what never belongs in an image (a throwaway Dockerfile, typed inline):

<!-- run -->
```bash
docker build -q -t leaky - <<'EOF'
FROM alpine:3.24
ENV API_KEY=sk-live-do-not-ship-me
EOF
docker history --no-trunc leaky | grep -o 'API_KEY=[^ ]*'
docker image rm leaky
```

- **.NET configuration already speaks environment variables.** `__` (double underscore)
  becomes `:`, so `Database__Host` is `Database:Host` and `ConnectionStrings__Default` is
  `GetConnectionString("Default")`. Environment variables override `appsettings.json` and
  `appsettings.{Environment}.json`; command-line arguments override both.
- **`ASPNETCORE_ENVIRONMENT`** defaults to `Production` in a container.
- **Build once, configure per environment.** The image that passed the tests is the image
  that goes to production; only its environment changes. No more per-environment builds.
- **Environment variables are not secret.** `docker inspect` shows them. **Agent trap:**
  secrets in `ENV` or `ARG` in a Dockerfile: they're in the image for good, for everyone
  who can pull it. Real secrets come from files mounted at runtime or a secret store
  (Kubernetes Secrets in the afternoon).

If it breaks: a value isn't picked up → check the spelling with `docker inspect`; in bash,
a variable name can't contain `:`, which is exactly why `__` exists.

## Step 11: volumes

**Goal:** where data survives a container, and the three kinds of mounts.

**Ask first:** a Postgres container gets a table and a row. We remove the container and
start a new one from the same image. Is the row still there?

<!-- run -->
```bash
docker run -d --name db -e POSTGRES_PASSWORD=workshop postgres:18.6
until docker exec db pg_isready -h 127.0.0.1 -U postgres -q; do sleep 1; done   # wait until Postgres accepts connections
docker exec db psql -U postgres -c "CREATE TABLE notes (text text); INSERT INTO notes VALUES ('remember me');"
ANON=$(docker inspect db --format '{{range .Mounts}}{{.Name}}{{end}}'); echo "anonymous volume: $ANON"
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=workshop postgres:18.6
until docker exec db pg_isready -h 127.0.0.1 -U postgres -q; do sleep 1; done
docker exec db psql -U postgres -c "SELECT * FROM notes"
docker rm -f -v db                                              # -v: also remove its anonymous volume
docker volume ls --filter name="$ANON"                          # the first container's volume is still there
docker volume rm "$ANON"
```

A named volume:

<!-- run -->
```bash
docker run -d --name db -e POSTGRES_PASSWORD=workshop -v workshop-pgdata:/var/lib/postgresql postgres:18.6
until docker exec db pg_isready -h 127.0.0.1 -U postgres -q; do sleep 1; done
docker exec db psql -U postgres -c "CREATE TABLE notes (text text); INSERT INTO notes VALUES ('remember me');"
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=workshop -v workshop-pgdata:/var/lib/postgresql postgres:18.6
until docker exec db pg_isready -h 127.0.0.1 -U postgres -q; do sleep 1; done
docker exec db psql -U postgres -c "SELECT * FROM notes"
docker volume inspect workshop-pgdata
docker rm -f db
```

A bind mount: files from your WSL home inside the container ([`volumes/init/`](volumes/init)):

<!-- run -->
```bash
cd ~/docker-k3s/docker/volumes
cat init/01-notes.sql
docker run -d --name db -e POSTGRES_PASSWORD=workshop -v "$PWD/init":/docker-entrypoint-initdb.d:ro postgres:18.6
until docker exec db pg_isready -h 127.0.0.1 -U postgres -q; do sleep 1; done
docker exec db psql -U postgres -c "SELECT * FROM notes"
docker rm -f -v db
```

Backing up a volume is just another container, which packs it into a `.tgz` file in the
current folder:

<!-- run -->
```bash
cd ~/docker-k3s/docker/volumes
docker run --rm -v workshop-pgdata:/data:ro -v "$PWD":/backup alpine:3.24 tar czf /backup/pgdata.tgz -C /data .
ls -lh pgdata.tgz
rm pgdata.tgz
docker volume rm workshop-pgdata
```

- **The answer:** no, the row is gone. The writable layer dies with the container (step 3).
  Data that must survive goes into a mount:
  - **named volume** (`-v workshop-pgdata:/path`): managed by Docker, lives inside Docker's
    VM, survives `docker rm`. The right place for databases.
  - **bind mount** (`-v "$PWD/init":/path`): a folder from your machine. Right for source
    code, config files, and seed scripts. On Windows: from the WSL filesystem, not `/mnt/c`.
    `:ro` makes it read-only for the container.
  - **anonymous volume**: created when an image declares `VOLUME` (Postgres does) and you
    mount nothing. The data is kept, but nobody knows where. Always name your volumes.
- **Agent trap:** Postgres 18 changed its path. Mount `/var/lib/postgresql`, not
  `/var/lib/postgresql/data` like in every older tutorial. The image warns in its log if you
  get it wrong.
- **Running is not ready.** Postgres needs a few seconds before it accepts connections;
  hence `pg_isready` in a loop (`-h 127.0.0.1`, because during its first start Postgres
  briefly runs a setup server that isn't reachable over the network yet). Compose does the
  same with a health check (step 14), and Kubernetes with a readiness probe.
- **The same for SQL Server:** `mcr.microsoft.com/mssql/server` with `ACCEPT_EULA=Y` and
  `MSSQL_SA_PASSWORD`, volume at `/var/opt/mssql`. Same ideas, different paths.
- Volumes outlive containers on purpose. `docker rm -v` removes a container's anonymous
  volumes, `docker volume rm` a named one. In k3s, the same idea is a PersistentVolumeClaim.

If it breaks: `pg_isready` loops forever → `docker logs db`; a wrong `POSTGRES_PASSWORD` or a
leftover volume from another Postgres version are the usual causes.

## Step 12: registries

**Goal:** where images come from, tags vs. digests, and a private registry of our own. A
registry is just another container, built from everything in steps 8 to 11: a named volume,
environment variables, a restart policy.

Tags move, digests don't:

<!-- run -->
```bash
docker pull alpine:3.24                  # = docker.io/library/alpine:3.24
DIGEST=$(docker image inspect alpine:3.24 --format '{{index .RepoDigests 0}}'); echo "$DIGEST"
docker pull "$DIGEST"                    # this exact content, today and in a year
```

A private registry, with a user and password ([`registry/`](registry)). `htpasswd` is a small
tool that writes a user/password file; we run it from the Apache `httpd` image:

<!-- run -->
```bash
cd ~/docker-k3s/docker/registry
docker run --rm --entrypoint htpasswd httpd:2.4-alpine -Bbn workshop docker-k3s > htpasswd
docker run -d --name registry --restart unless-stopped -p 5000:5000 \
  -v workshop-registry-data:/var/lib/registry \
  -v "$PWD/htpasswd":/auth/htpasswd:ro \
  -e REGISTRY_AUTH=htpasswd -e REGISTRY_AUTH_HTPASSWD_REALM=workshop -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:3.1.2
sleep 1
curl -si localhost:5000/v2/ | head -1                      # the registry's API, without credentials
```

**Ask first:** we tag our image for the new registry and push it. What happens?

<!-- run -->
```bash
docker build -q -f ~/docker-k3s/docker/hello-web/Dockerfile.4-chiseled -t hello-web:4-chiseled ~/docker-k3s/docker/hello-web
docker tag hello-web:4-chiseled localhost:5000/hello-web:1.0
docker push localhost:5000/hello-web:1.0
echo docker-k3s | docker login localhost:5000 -u workshop --password-stdin   # password from stdin, not in the shell history
docker push localhost:5000/hello-web:1.0
curl -s -u workshop:docker-k3s localhost:5000/v2/_catalog | jq
curl -s -u workshop:docker-k3s localhost:5000/v2/hello-web/tags/list | jq
docker image rm localhost:5000/hello-web:1.0
docker pull localhost:5000/hello-web:1.0
```

Where did the password go? (Prints only the registry names and the credential store, never
the stored values.)

<!-- run -->
```bash
jq '{credsStore, registries: (.auths | keys)}' ~/.docker/config.json
```

**Leave the registry running.** The k3s half day pulls from it; configuring k3s to trust
this plain-HTTP registry is part of the afternoon.

- **The answer:** "push access denied": the registry wants a login (the first `curl`
  already said 401). The error comes after some progress lines, so read to the end.
- **A registry is an HTTP API** (`/v2/...`) that stores layers and manifests. The image name
  says which registry: no host means Docker Hub, `mcr.microsoft.com/...` means Microsoft,
  `localhost:5000/...` means ours. In real life: Azure Container Registry, GitHub Container
  Registry, Harbor, Nexus, or GitLab. Same API, same commands.
- **`docker tag`** adds a name, it copies nothing. **`push`** uploads only the layers the
  registry doesn't have yet.
- **Tag = branch name, digest = commit hash.** `alpine:3.24` gets security fixes, `latest`
  means whatever was pushed last; a digest never changes. Pin tags with a patch level for
  readability, or digests for reproducibility, and let a bot (Renovate, Dependabot) update
  them. **Agent trap:** `:latest` in a Dockerfile or a deployment.
- **Credentials:** `docker login` stores them per registry. Docker Desktop hands them to the
  Windows Credential Manager (`credsStore` is `desktop.exe`). On a plain Linux box they end
  up base64-encoded in `~/.docker/config.json`, which is encoding, not encryption.
- Optional, with the SDK from step 7: `dotnet publish` pushes directly, using the same
  `docker login`:
  ```bash
  cd ~/docker-k3s/docker/hello-web
  DOTNET_CONTAINER_INSECURE_REGISTRIES=localhost:5000 dotnet publish --os linux --arch x64 /t:PublishContainer \
    -p ContainerRegistry=localhost:5000 -p ContainerRepository=hello-web -p ContainerImageTag=sdk -p ContainerFamily=noble-chiseled
  curl -s -u workshop:docker-k3s localhost:5000/v2/hello-web/tags/list | jq
  rm -rf bin obj
  ```

If it breaks: `connection refused` on port 5000 → another program (often an old registry
container) has the port; `docker ps --filter publish=5000`.

---

# Part 3: several containers

## Step 13: networks

**Goal:** how containers find each other, and why `localhost` is the wrong answer.

The second demo app, [`visit-counter`](visit-counter/Program.cs), counts page visits in
Postgres. Its connection string comes from `ConnectionStrings__Visits`.

<!-- run -->
```bash
cd ~/docker-k3s/docker/visit-counter
docker build -t visit-counter:1 .
docker run -d --name db -e POSTGRES_PASSWORD=workshop postgres:18.6
docker run --rm alpine:3.24 ping -c1 -W1 db                    # can another container find "db" by name?
docker network create workshop
docker network connect workshop db
docker run --rm --network workshop alpine:3.24 ping -c1 db     # and now?
until docker exec db pg_isready -h 127.0.0.1 -U postgres -q; do sleep 1; done
```

**Ask first:** on your laptop, the connection string says `Host=localhost`, and it works.
What happens in a container?

<!-- run -->
```bash
docker run -d --name counter-wrong --network workshop \
  -e ConnectionStrings__Visits="Host=localhost;Username=postgres;Password=workshop" visit-counter:1
sleep 3
docker ps -a --filter name=counter-wrong --format '{{.Names}}: {{.Status}}'
docker logs counter-wrong 2>&1 | grep -m1 'Failed to connect'
```

**Your turn:** fix it before the next block does.

<!-- run -->
```bash
docker run -d --name counter --network workshop -p 8080:8080 \
  -e ConnectionStrings__Visits="Host=db;Username=postgres;Password=workshop" visit-counter:1
sleep 2                                                        # give the app a moment to start
curl -s localhost:8080 | jq
curl -s localhost:8080 | jq
```

Inside the network vs. from the host:

<!-- run -->
```bash
docker run --rm --network workshop curlimages/curl:8.22.0 -s http://counter:8080/ | jq -c   # container name, container port
docker port counter                                                                         # what is published?
docker network inspect workshop --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
docker run --rm --add-host host.docker.internal:host-gateway curlimages/curl:8.22.0 -s http://host.docker.internal:8080/ | jq -c
docker rm -f -v db counter counter-wrong                       # -v: Postgres's anonymous volume, too
docker network rm workshop
```

- **The answer:** the app dies at startup ("Failed to connect to 127.0.0.1:5432", exit code
  139: an unhandled .NET exception). **`localhost` inside a container is the container
  itself.** On your laptop Postgres ran next to the app; here nothing listens on 5432
  inside `counter-wrong`. **Agent trap:** `Host=localhost` in a containerized connection
  string.
- **User-defined networks have DNS:** the container name is the host name. The default
  `bridge` network doesn't, for historical reasons, so always create one (Compose does that
  for you, step 14).
- **Two kinds of ports:** inside the network, containers talk to each other directly on the
  container port (`counter:8080`, `db:5432`). `-p` is only for traffic from outside. The
  database isn't published at all, so nothing outside the network can reach it. That's a
  good default.
- **`-p 8080:8080` listens on all network interfaces** of the host (`0.0.0.0` in
  `docker port`): colleagues in the same Wi-Fi can reach your container.
  `-p 127.0.0.1:8080:8080` keeps it on your machine.
- **`host.docker.internal`** is the way from a container to your machine, for example to an
  API you're debugging in Visual Studio. Docker Desktop provides the name; on a Linux engine
  you add it with `--add-host host.docker.internal:host-gateway`.
- The `pg_isready` loop before starting the app is a manual "wait until ready". Without it,
  the app may start before the database accepts connections and crash just like
  `counter-wrong`. Compose's health checks automate that (step 14).
- In k3s, the same idea is a Service: a stable name in front of containers that come and go.

If it breaks: `network workshop already exists` → a previous run didn't clean up;
`docker network rm workshop` (after removing its containers).

## Step 14: Docker Compose

**Goal:** step 13 as a file. Describe the desired state, let Compose create it.

[`compose/compose.yaml`](compose/compose.yaml):

```yaml
name: workshop-compose   # project name: prefixes containers, network, and volume
services:
  app:
    build: ../visit-counter
    image: visit-counter:compose
    ports:
      - "8080:8080"
    environment:
      ConnectionStrings__Visits: "Host=db;Username=postgres;Password=${POSTGRES_PASSWORD}"
    depends_on:
      db:
        condition: service_healthy   # wait until Postgres accepts connections, not just until it started
    restart: unless-stopped

  db:
    image: postgres:18.6
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 2s
      timeout: 3s
      retries: 15

volumes:
  db-data:
```

<!-- run -->
```bash
cd ~/docker-k3s/docker/compose
cat .env
docker compose config | grep Visits                 # ${POSTGRES_PASSWORD} filled in from .env
docker compose up -d --build --wait
docker compose ps
curl -s localhost:8080 | jq -c
curl -s localhost:8080 | jq -c
docker compose logs app | tail -5
docker compose up -d --wait                         # again: what changes?
```

**Ask first:** `docker compose down`, then `up` again. Does the visit count start at 1?

<!-- run -->
```bash
cd ~/docker-k3s/docker/compose
docker compose down
docker compose up -d --wait
curl -s localhost:8080 | jq -c
docker compose down -v                              # -v: the volume, too
```

Live (not rehearsed): `docker compose up` without `-d` shows all logs in one stream;
`Ctrl+C` stops everything.

- **Declarative:** the file says what should exist; `up` makes it so and leaves alone what
  already matches (the second `up` changed nothing). That's the mental model for Kubernetes
  manifests in the afternoon.
- **The answer:** no, the count goes on. `down` removes containers and the network but keeps
  volumes; `down -v` deletes them, too. **Agent trap:** `down -v` in a cleanup script: data
  loss is one flag away.
- **Compose gives you step 13 for free:** a network per project, the service names as host
  names, containers named `<project>-<service>-<n>`. `name:` sets the project name; without
  it, it's the folder name.
- **`depends_on` with `condition: service_healthy`** starts the app only when the database
  answers. Without the condition, Compose only waits until the container *started*.
  `--wait` makes `up` itself wait until everything is healthy or running.
- **Health checks run inside the container.** That works for Postgres, which brings
  `pg_isready`. Our chiseled app has `/healthz` but no shell and no curl to call it from
  inside, so it has no Docker health check. Kubernetes probes come from outside the
  container, so there `/healthz` just works: the readiness and liveness probes of the
  afternoon.
- **Two kinds of variables:** `.env` next to `compose.yaml` fills `${...}` in the file;
  `environment:` sets variables in the container. `.env` keeps passwords out of the YAML,
  but not out of `docker inspect`.

If it breaks: `dependency failed to start: container workshop-compose-db-1 is unhealthy` →
`docker compose logs db`; usually a volume left over from a different Postgres setup:
`docker compose down -v`.

## Step 15: a reverse proxy: Traefik

**Goal:** one entry point that routes by host name and balances across replicas. k3s ships
Traefik as its default ingress controller, so this is the afternoon's mental model.

[`compose-traefik/compose.yaml`](compose-traefik/compose.yaml) (the database is as in step
14):

```yaml
name: workshop-traefik
services:
  traefik:
    image: traefik:v3.7.13
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false   # only containers with traefik.enable=true
      - --entrypoints.web.address=:80
      - --api.insecure=true                         # dashboard on port 8080 inside the container (demo only)
    ports:
      - "8000:80"      # the entrypoint for all apps
      - "8090:8080"    # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  app:
    build: ../visit-counter
    image: visit-counter:compose
    deploy:
      replicas: 2
    environment:
      ConnectionStrings__Visits: "Host=db;Username=postgres;Password=${POSTGRES_PASSWORD}"
    labels:
      - traefik.enable=true
      - traefik.http.routers.visits.rule=Host(`visits.localhost`)
      - traefik.http.routers.visits.entrypoints=web
      - traefik.http.services.visits.loadbalancer.server.port=8080
    depends_on:
      db:
        condition: service_healthy

  hello:
    image: hello-web:4-chiseled
    environment:
      - ASPNETCORE_FORWARDEDHEADERS_ENABLED   # no value: taken from your shell when you run docker compose, unset otherwise
    labels:
      - traefik.enable=true
      - traefik.http.routers.hello.rule=Host(`hello.localhost`)
      - traefik.http.routers.hello.entrypoints=web
```

**Ask first:** two replicas of the counter run behind Traefik. Which one answers?

<!-- run -->
```bash
cd ~/docker-k3s/docker/compose-traefik
docker build -q -f ../hello-web/Dockerfile.4-chiseled -t hello-web:4-chiseled ../hello-web
docker compose up -d --build --wait
sleep 2                                                                       # give Traefik a moment to see the containers
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
for i in 1 2 3 4; do curl -s http://visits.localhost:8000/ | jq -c; done      # four requests in a loop
curl -s http://hello.localhost:8000/ | jq -c '{message, host}'
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/               # no rule for this host name
```

Open <http://localhost:8090> for the dashboard: routers, services, and the two servers
behind `visits`. In the Windows browser, <http://visits.localhost:8000> works, too.

Scaling, and what the app sees behind a proxy:

<!-- run -->
```bash
cd ~/docker-k3s/docker/compose-traefik
docker compose up -d --scale app=4 --wait
sleep 2
for i in 1 2 3 4 5 6; do curl -s http://visits.localhost:8000/ | jq -r .servedBy; done
curl -s http://hello.localhost:8000/request | jq                               # who is the client?
ASPNETCORE_FORWARDEDHEADERS_ENABLED=true docker compose up -d --wait hello     # recreate hello with the variable set
sleep 2
curl -s http://hello.localhost:8000/request | jq
docker compose down -v
```

- **The answer:** they take turns (`servedBy` alternates); with four replicas, four
  containers share the work.
- **A reverse proxy** is the single door: it routes by host name or path, balances across
  replicas, and terminates TLS (Traefik can get Let's Encrypt certificates by itself). The
  apps behind it publish no ports at all. In production, it typically sends `/api` to the
  .NET backend and everything else to the Angular container.
- **Traefik configures itself from the Docker API.** It watches containers start and stop
  and reads their labels: the routing rules live with the app they route to. `hello` has no
  port label; Traefik takes the port from `EXPOSE 8080` (step 6).
- **The Docker socket is root access to the host.** Whoever can talk to
  `/var/run/docker.sock` can start a privileged container. `:ro` doesn't change that: it
  makes the socket file read-only, not the API. Mount it only into containers you trust.
- **Behind a proxy, the app's client is the proxy.** Before: `remoteIp` is Traefik's
  address, and the real client is only in `X-Forwarded-For`. After setting
  `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true`, ASP.NET Core applies the forwarded headers.
  The `environment:` entry without a value passes the variable through from the shell that
  runs `docker compose`; that's how we switched it on without editing the file. The variable
  trusts any proxy, so use it only when the app can't be reached except through the proxy.
  **Agent trap:** forgetting this, and then chasing HTTPS redirect loops and wrong client IPs
  behind a TLS-terminating proxy.
- **`*.localhost`** resolves to 127.0.0.1 in curl and in browsers, so host-based routing
  works on a laptop without touching the hosts file.
- In k3s: the same Traefik, but configured by Ingress resources instead of labels, and the
  replicas come from a Deployment.

If it breaks: 404 right after `up` → Traefik needs a moment to see new containers; repeat
the `curl`. Port 8000 or 8090 taken → change the left side of the mapping in
`compose.yaml`.

---

# Part 4: wrap-up

## Step 16: slim and secure images

**Goal:** the checklist, backed by numbers from our own images.

<!-- run -->
```bash
cd ~/docker-k3s/docker/hello-web
for t in 1-naive 3-multistage 4-chiseled; do docker build -q -f Dockerfile.$t -t hello-web:$t . > /dev/null; done
docker image ls hello-web --format 'table {{.Tag}}\t{{.Size}}'
for t in 1-naive 3-multistage 4-chiseled; do echo "$t runs as: $(docker inspect hello-web:$t --format '{{or .Config.User "root (no USER set)"}}')"; done
```

**Ask first:** a vulnerability scanner checks the three images. Which one has the most
known vulnerabilities, and how big is the difference?

Trivy runs as a container. It needs the Docker socket to read local images; see step 15 for
what that means:

<!-- run -->
```bash
for t in 1-naive 3-multistage 4-chiseled; do
  echo "== hello-web:$t"
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v workshop-trivy-cache:/root/.cache \
    aquasec/trivy:0.75.0 image --quiet --scanners vuln hello-web:$t | grep -E '^Total'
done
```

Lock it down at runtime:

<!-- run -->
```bash
docker run -d --name hello -p 8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges hello-web:4-chiseled
sleep 2                                  # give the app a moment to start
curl -s localhost:8080 | jq '{user, os}'
docker rm -f hello
docker volume rm workshop-trivy-cache
```

The checklist:

| | Practice | Where we saw it |
| --- | --- | --- |
| 1 | Multi-stage: the SDK never ships | step 6 |
| 2 | Small base image: chiseled, distroless, or Alpine | steps 6, 16 |
| 3 | Non-root: chiseled does it; otherwise `USER $APP_UID` after `FROM aspnet:10.0` | steps 4, 6, 16 |
| 4 | `.dockerignore`, layer order | step 5 |
| 5 | No secrets in `ENV`, `ARG`, or copied files | step 10 |
| 6 | Pinned versions, updated by a bot; rebuild regularly for base image patches | step 12 |
| 7 | Scan in CI (Trivy, Docker Scout) | step 16 |
| 8 | Run read-only, without extra privileges | step 16 |
| 9 | JSON-form `ENTRYPOINT`, log to stdout | steps 8, 9 |

- **The answer, from the rehearsal:** 18 known vulnerabilities in the naive SDK-based image,
  14 in `aspnet:10.0`, 2 in chiseled (none high or critical, on that day). The SDK is not the
  big difference; leaving out the shell and the package tools is. The scanner counts
  packages it knows to be vulnerable, and a package that isn't in the image can't be. Each
  finding is one you'd have to explain in an audit, whether your app uses it or not.
- **Root in a container is still root** on the host's kernel. Namespaces make an escape
  hard, not impossible. With `aspnet:10.0`, add `USER $APP_UID` yourself; it's one line.
  **Agent trap:** a runtime stage without `USER`.
- **The runtime flags:** `--read-only` makes the container's filesystem unwritable,
  `--cap-drop ALL` takes away the special kernel permissions a root process would have, and
  `no-new-privileges` stops a process from gaining more rights later. Our app runs fine with
  all three.
- **A pinned image doesn't patch itself.** Rebuild on base image updates, not only on code
  changes.
- These flags show up again in the afternoon as a Kubernetes `securityContext`.

If it breaks: Trivy is slow the first time → it downloads its vulnerability database into
the `workshop-trivy-cache` volume; the second run takes seconds.

## Step 17: wrap-up: from Docker to k3s

**Goal:** what carries over to the afternoon, and the list of traps to look for in any
Dockerfile or Compose file, whoever wrote it.

**Your turn:** before showing the table, ask the room to guess the right-hand column.

| Docker (this morning) | k3s (this afternoon) |
| --- | --- |
| image, registry (step 12: `localhost:5000`) | the same images, pulled by the cluster |
| `docker run` | Pod, managed by a Deployment |
| `--restart`, replicas in Compose | Deployment: desired number of Pods, restarted automatically |
| `-e`, `--env-file` | `env` in the Pod spec, ConfigMap, Secret |
| named volume | PersistentVolumeClaim |
| user-defined network, container names | Service with a stable DNS name |
| health check, "running is not ready" | readiness and liveness probes |
| Traefik with labels | Traefik with Ingress resources |
| `compose.yaml`, `docker compose up` | manifests, `kubectl apply` |
| `--memory`, `--cpus`, `OOMKilled` | `resources.limits`, `OOMKilled` |
| `--read-only`, `--cap-drop` | `securityContext` |
| `docker logs`, `inspect`, `ps` | `kubectl logs`, `describe`, `get` |

The agent traps of the morning: read every generated Dockerfile and Compose file with this
list in mind.

| Trap | Step |
| --- | --- |
| `-bookworm-slim` or other Debian tags for .NET 10 | 3 |
| no `.dockerignore` | 5 |
| a single stage that ships the SDK | 6 |
| shell-form `ENTRYPOINT` or `CMD` | 9 |
| `docker system prune` or `volume prune` to clean up | 9 |
| secrets in `ENV` or `ARG` | 10 |
| Postgres 18 data at `/var/lib/postgresql/data` | 11 |
| `:latest` instead of a pinned version | 12 |
| `Host=localhost` in a container's connection string | 13 |
| `down -v` in a cleanup script | 14 |
| no forwarded headers behind a reverse proxy | 15 |
| a runtime stage that runs as root | 16 |

- Compose runs containers on one machine. Kubernetes runs them on many, and keeps them
  running when one of those machines dies. The vocabulary changes; the container doesn't.

Clean up the morning, but keep the registry and its image:

<!-- run -->
```bash
docker image rm hello-web:1-naive hello-web:2-layers hello-web:3-multistage hello-web:4-chiseled hello-web:shell-form 2>/dev/null
docker image rm visit-counter:1 visit-counter:compose localhost:5000/hello-web:1.0 hello-web:sdk 2>/dev/null
docker ps --filter name=registry --format '{{.Names}}: {{.Status}}'      # still running for the afternoon
```

---

## Ports

| Port | What |
| ---: | --- |
| 5000 | private registry (step 12), stays running for k3s |
| 8000 | Traefik entry point (step 15): `visits.localhost`, `hello.localhost` |
| 8080 | the demo apps (steps 4 to 14) |
| 8090 | Traefik dashboard (step 15) |
| 5432 | Postgres, never published: only reachable inside its network |

## Troubleshooting

- **"Cannot connect to the Docker daemon"** in WSL: start Docker Desktop, and check
  Settings → Resources → WSL integration for your distro.
- **"port is already allocated"**: find the container and remove it.
  ```bash
  docker ps --filter publish=8080 --format '{{.Names}} {{.Ports}}'
  ```
  If no container has it, a Windows program does (IIS, another dev server); change the left
  side of `-p`.
- **"The container name ... is already in use"**: a step was interrupted before its cleanup.
  Remove that container by name (`docker rm -f hello`), then repeat the block.
- **Builds or bind mounts are slow, file changes don't arrive**: the repo is under `/mnt/c`.
  Clone it into `~`.
- **`/bin/sh^M: bad interpreter`** or scripts failing in a container: the file was checked
  out on Windows with CRLF line endings. Clone inside WSL.
- **`toomanyrequests` from Docker Hub**: anonymous pull limit; `docker login` or use the
  pre-pulled images.
- **Disk full**: `docker system df`, then remove the workshop images by name (step 17's
  cleanup block). Don't reach for `docker system prune`: it removes other projects' data,
  too.
