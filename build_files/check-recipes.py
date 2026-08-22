#!/usr/bin/env python3
"""Fail the build when a recipe reads a `just` parameter as a shell variable.

`just` substitutes {{ ACTION }} when it renders the recipe body. $ACTION is an
ordinary shell variable, and unless the body assigns it first the value is
simply absent -- fatal under `set -u`, silently empty without it. Recipes that
do assign it (ACTION="{{ ACTION }}") are correct and must not be flagged.

This shipped broken in yaguarete-setup-local-ai and nothing noticed, because a
recipe that exists satisfies every other check we have. Existing is not the
same as working.
"""
import glob
import re
import sys

FAIL = []

for path in sorted(glob.glob("/usr/share/ublue-os/just/*yaguarete*.just")):
    text = open(path, encoding="utf-8", errors="replace").read()
    params = set(re.findall(r"^[a-z0-9_-]+\s+([A-Z_]+)=", text, re.M))

    for param in params:
        # The body may bridge the parameter into the shell exactly once.
        bridged = re.search(rf'^\s*{param}=\s*"?\{{\{{\s*{param}\s*\}}\}}', text, re.M)
        if bridged:
            continue
        for lineno, line in enumerate(text.split("\n"), 1):
            if "{{" in line:
                continue
            if re.search(rf"\$\{{?{param}\b", line):
                FAIL.append((path, lineno, param, line.strip()))

if FAIL:
    print("=" * 70, file=sys.stderr)
    print("[recipes] FATAL: just parameters used as unset shell variables", file=sys.stderr)
    for path, lineno, param, line in FAIL:
        print(f"[recipes]   {path}:{lineno}  ${param}  ->  {line}", file=sys.stderr)
    print("[recipes] Use {{ PARAM }}, or assign PARAM=\"{{ PARAM }}\" first.", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    sys.exit(1)

print("[recipes] no just parameter is read as an unset shell variable")
