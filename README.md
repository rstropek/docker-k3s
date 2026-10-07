# Docker and k3s for .NET developers

Material for a hands-on workshop, two half days, for C# developers who work on Windows:
**Docker** in the morning, **k3s** (lightweight Kubernetes) in the afternoon. No slides: small,
independent demos with plain commands, run in bash inside WSL against Docker Desktop.

| Path | What it is |
| --- | --- |
| [`docker/storybook.md`](docker/storybook.md) | the presenter's guide for the Docker half day: 17 steps with copyable commands, prediction questions, talking points, and "if it breaks" |
| [`docker/`](docker) | the demos: two small ASP.NET Core apps (`hello-web`, `visit-counter`), Dockerfiles, Compose files, `setup-check.sh`, `prepull.sh` |
| [`rehearsal/run-blocks.py`](rehearsal/run-blocks.py) | runs every block of a storybook marked `<!-- run -->` and times each step |
| [`k3s/storybook.md`](k3s/storybook.md) | the presenter's guide for the k3s half day: 14 steps, same format, on a k3s cluster run by k3d (nodes as Docker containers) |
| [`k3s/`](k3s) | the cluster config, the manifests (`hello/`, `visits/`, `troubleshooting/`), `install-tools.sh`, `registry.sh`, `setup-check.sh`, `prepull.sh` |

**Participants:** see [Before the workshop](docker/storybook.md#before-the-workshop). In short:
WSL 2 with Ubuntu 24.04, Docker Desktop with WSL integration, this repository cloned to
`~/docker-k3s` inside WSL, then `docker/setup-check.sh` and `docker/prepull.sh`. For the
afternoon, also `k3s/install-tools.sh` (k3d and kubectl, no sudo) and `k3s/prepull.sh`; see
[Before the workshop](k3s/storybook.md#before-the-workshop) of the k3s storybook.

**Re-rehearsing** after an image update:

```bash
rehearsal/run-blocks.py --list           # steps and their runnable blocks
rehearsal/run-blocks.py --step 6 9       # some steps
rehearsal/run-blocks.py                  # all of them, about 2.5 minutes
rehearsal/run-blocks.py --storybook k3s/storybook.md   # the k3s half day, about 5 minutes
```
