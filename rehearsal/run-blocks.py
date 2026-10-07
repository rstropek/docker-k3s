#!/usr/bin/env python3
"""Rehearse a storybook: run every bash block marked <!-- run --> step by step, log and time it.

Usage (from the repo root or anywhere):
  rehearsal/run-blocks.py [--storybook docker/storybook.md] [--list] [--step N ...] [--from N]

Blocks run with bash (no -e: some commands fail on purpose) from the repo root, with
~/docker-k3s replaced by this checkout. Output goes to rehearsal/logs/<storybook>-stepNN.log.
"""
import argparse
import pathlib
import re
import subprocess
import sys
import time

root = pathlib.Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument("--storybook", default="docker/storybook.md")
ap.add_argument("--list", action="store_true", help="list steps and their runnable blocks, run nothing")
ap.add_argument("--step", type=int, nargs="*", help="run only these steps")
ap.add_argument("--from", dest="start", type=int, default=0, help="run from this step on")
args = ap.parse_args()

book = (root / args.storybook).read_text()
steps = []  # (number, title, [blocks])
for m in re.finditer(r"^## Step (\d+): (.*)$", book, re.M):
    steps.append([int(m.group(1)), m.group(2), [], m.start()])
for s, nxt in zip(steps, steps[1:] + [None]):
    end = nxt[3] if nxt else len(book)
    s[2] = re.findall(r"<!-- run -->\n```bash\n(.*?)\n```", book[s[3]:end], re.S)

if args.list:
    for n, title, blocks, _ in steps:
        print(f"step {n:2}  {len(blocks)} block(s)  {title}")
    sys.exit(0)

logs = root / "rehearsal" / "logs"
logs.mkdir(parents=True, exist_ok=True)
name = pathlib.Path(args.storybook).parent.name or "storybook"
total = 0.0
for n, title, blocks, _ in steps:
    if (args.step and n not in args.step) or n < args.start or not blocks:
        continue
    log = logs / f"{name}-step{n:02}.log"
    started = time.monotonic()
    with log.open("w") as f:
        for i, block in enumerate(blocks, 1):
            script = block.replace("~/docker-k3s", str(root))
            f.write(f"### block {i}\n{script}\n### output\n")
            f.flush()
            t = time.monotonic()
            subprocess.run(["bash", "-c", script], cwd=root, stdout=f, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
            f.write(f"### block {i} took {time.monotonic() - t:.1f} s\n\n")
            f.flush()
    took = time.monotonic() - started
    total += took
    print(f"step {n:2}  {took:6.1f} s  {title}  ({log.relative_to(root)})")
print(f"total {total:.1f} s")
