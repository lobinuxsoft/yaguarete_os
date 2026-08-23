#!/usr/bin/env python3
"""Report what changed in the Bazzite base since we last looked.

Bazzite's changelog answers "what did they change". The question we have is
"what did they change *under* us", which is a different and much shorter
list. This diffs the exact commits.

The base image records the commit it was built from in an OCI label:

    org.opencontainers.image.revision = <ublue-os/bazzite sha>

so the range is exact instead of date-guessed. docs/qa/upstream-base.txt
holds the last revision that was reviewed; `--write` moves it forward.

Three buckets, in descending order of how much they can hurt:

  1. Recipes we call that upstream removed or un-aliased. `ujust` recipes
     get renamed without a release note, our wrappers keep calling the old
     name and nothing fails loudly -- the failure mode already documented in
     docs/qa/upstream-issues.md.
  2. Files we land on top of theirs -- system_files/overrides/ replaces
     assets in place, system_files/usr and system_files/etc are COPYed over
     the base. When upstream edits their copy ours keeps serving the old
     content, and no build step notices. `yafti.yml` and
     `system-update.desktop` are both in this bucket.
  3. Everything else, counted by area, so the noise stays a few lines.

Needs: skopeo, gh (authenticated), python3.
"""

import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
STATE = REPO / "docs" / "qa" / "upstream-base.txt"
UPSTREAM = "ublue-os/bazzite"
DEFAULT_IMAGE = "ghcr.io/ublue-os/bazzite:stable"

# A just recipe header: name, optional PARAM="default" list, trailing colon.
# Anchored to a removed diff line, so `-` is the diff marker, not a dash.
RECIPE = re.compile(r'^-([a-z][a-z0-9-]*)((?:\s+\w+(?:=(?:"[^"]*"|\S+))?)*)\s*:\s*(#.*)?$')
ALIAS = re.compile(r"^-\s*alias\s+([a-z][a-z0-9-]*)\s*:=")


def run(cmd):
    """Run a command and return stdout. Failure is fatal and says why."""
    try:
        done = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except FileNotFoundError:
        sys.exit(f"falta la herramienta: {cmd[0]}")
    except subprocess.CalledProcessError as err:
        sys.exit(f"{' '.join(cmd[:3])} falló:\n{err.stderr.strip()}")
    return done.stdout


def base_revision(image):
    """The upstream commit and version the base image was built from."""
    labels = json.loads(run(["skopeo", "inspect", f"docker://{image}"])).get("Labels") or {}
    revision = labels.get("org.opencontainers.image.revision")
    if not revision:
        sys.exit(f"{image} no expone org.opencontainers.image.revision")
    return revision, labels.get("org.opencontainers.image.version", "?")


def read_state():
    if not STATE.exists():
        return None, None
    fields = dict(re.findall(r"^(\w+):\s*(\S+)", STATE.read_text(encoding="utf-8"), re.M))
    return fields.get("revision"), fields.get("version")


def write_state(revision, version):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(
        "# Last Bazzite base reviewed. Move it forward with:\n"
        "#     just upstream-report --write\n"
        f"revision: {revision}\n"
        f"version:  {version}\n"
        f"reviewed: {date.today().isoformat()}\n",
        encoding="utf-8",
    )


def compare(old, new):
    """Merged commits and files for old...new, or None when the range is empty.

    Both lists paginate on this endpoint, and a range spanning a few weeks
    goes well past one page. --slurp returns every page as an array, which
    is the only reason the totals below can be trusted.
    """
    if old == new:
        return None
    pages = json.loads(
        run(["gh", "api", f"repos/{UPSTREAM}/compare/{old}...{new}", "--paginate", "--slurp"])
    )
    merged = {"commits": [], "files": []}
    for page in pages:
        merged["commits"] += page.get("commits") or []
        merged["files"] += page.get("files") or []
    return merged


def our_files():
    """Rootfs paths we put a file at, as tails like usr/share/.../logo.svg.

    Two layers land on the same paths and both shadow upstream silently:
    system_files/overrides/ replaces assets in place, and system_files/usr +
    system_files/etc are COPYed over the base. Scanning only the first misses
    the ones that matter most -- yafti.yml and system-update.desktop are full
    replacements of an upstream file, and upstream keeps editing theirs.
    """
    roots = [
        (REPO / "system_files" / "overrides", ""),
        (REPO / "system_files" / "usr", "usr"),
        (REPO / "system_files" / "etc", "etc"),
    ]
    tails = set()
    for root, prefix in roots:
        if not root.is_dir():
            continue
        for path in root.rglob("*"):
            if path.is_file():
                rel = str(path.relative_to(root))
                tails.add(f"{prefix}/{rel}" if prefix else rel)
    return tails


def upstream_recipes():
    """Upstream `ujust` recipe names we call, from our recipes and the Portal."""
    names = set()
    sources = list((REPO / "system_files").rglob("*.just"))
    sources += list((REPO / "system_files").rglob("yafti.yml"))
    for path in sources:
        text = path.read_text(encoding="utf-8", errors="replace")
        names |= set(re.findall(r"\bujust\s+([a-z][a-z0-9-]*)", text))
    # Ours are not upstream's to break; they live in this repo.
    return {name for name in names if not name.startswith("yaguarete")}


def removed_names(patch):
    """Recipe and alias names that disappear in a .just patch.

    Only removals matter: a new name upstream is a feature, a removed one is
    a wrapper of ours pointing at nothing.
    """
    gone = set()
    for line in patch.splitlines():
        for pattern in (RECIPE, ALIAS):
            found = pattern.match(line)
            if found:
                gone.add(found.group(1))
    return gone


def area(filename):
    """First two path segments, enough to tell subsystems apart."""
    return "/".join(filename.split("/")[:2])


def report(data, overrides, recipes):
    commits, files = data["commits"], data["files"]
    print(f"## {len(commits)} commits, {len(files)} archivos\n")

    breaks, collisions, rest = [], [], Counter()
    for entry in files:
        name, patch = entry["filename"], entry.get("patch", "")

        if name.endswith(".just") and patch:
            for recipe in sorted(removed_names(patch) & recipes):
                breaks.append((recipe, name))

        tail = next((t for t in overrides if name.endswith(t)), None)
        if tail:
            collisions.append((tail, name, entry["status"]))
        else:
            rest[area(name)] += 1

    if breaks:
        print("### ROTO: recetas que llamamos y ya no están arriba\n")
        for recipe, name in breaks:
            print(f"- `ujust {recipe}` — desapareció de `{name}`")
        print()

    if collisions:
        print("### Chocan con archivos nuestros\n")
        for tail, name, status in collisions:
            print(f"- `{tail}` — upstream {status} `{name}`")
        print()

    if not breaks and not collisions:
        print("Nada toca lo nuestro.\n")

    if rest:
        print("### Resto, por área\n")
        for name, count in rest.most_common(12):
            print(f"- {name} — {count}")
        if len(rest) > 12:
            print(f"- ... y {len(rest) - 12} áreas más")
        print()

    print("<details><summary>commits</summary>\n")
    for commit in commits:
        subject = commit["commit"]["message"].split("\n")[0]
        print(f"- `{commit['sha'][:8]}` {commit['commit']['author']['date'][:10]} {subject}")
    print("\n</details>")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", default=DEFAULT_IMAGE)
    parser.add_argument("--since", help="revisión desde la que diffear (default: el archivo de estado)")
    parser.add_argument("--pending", action="store_true", help="mostrar también lo que está en main y todavía no en :stable")
    parser.add_argument("--write", action="store_true", help="marcar la base actual como revisada")
    args = parser.parse_args()

    current, version = base_revision(args.image)
    stored, stored_version = read_state()
    previous = args.since or stored

    print("# Bazzite upstream\n")
    print(f"- base actual : `{current[:8]}` ({version})")
    print(f"- revisado    : `{(previous or '-')[:8]}` ({stored_version or '-'})\n")

    overrides, recipes = our_files(), upstream_recipes()

    if not previous:
        print(
            "Sin marca previa. Corré `just upstream-report --write` para fijar la "
            "base actual; a partir de ahí el reporte diffea desde acá.\n"
        )
    elif previous == current:
        print("La base no se movió desde la última revisión.\n")
    else:
        report(compare(previous, current), overrides, recipes)

    if args.pending:
        print("\n---\n\n# Todavía no publicado en :stable\n")
        data = compare(current, "main")
        report(data, overrides, recipes) if data else print("Nada.\n")

    if args.write:
        write_state(current, version)
        print(f"\n{STATE.relative_to(REPO)} actualizado a {current[:8]}.")


if __name__ == "__main__":
    main()
