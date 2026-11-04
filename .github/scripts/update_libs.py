#!/usr/bin/env python3
"""Update ART's bundled libraries from their upstream sources.

Reads .github/libs.json, fetches each upstream (git or svn), copies changed
files into AdvanceRaidTools_Libraries/Libs, moves the pins forward and writes a
Markdown report saying, per library, which version changed and which upstream
commits came with it.

Rules, so a sync never surprises anyone:
  * Files are only added or updated, never deleted. Files ART has that upstream
    lacks (packager CHANGES.txt, nested LibStub copies) are kept and listed.
  * Dot files (.github, .pkgmeta, .luarc.json ...) are never copied.
  * "only_existing" libraries only update files ART already ships.
  * "exclude" globs skip upstream files another entry owns (nested copies).
  * Nested .toc files are left as shipped (WoW never loads them here).
  * A file that differs only in line endings, trailing whitespace or expanded
    $Id$-style keywords is left alone, and an updated file
    keeps the line ending style it had in ART.
  * After syncing, every file named by a .toc or .xml under the libraries
    folder must exist, or the run fails.

Exit code 0 with "changed=true|false" written to $GITHUB_OUTPUT when set.
"""
import argparse
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

FLAG_RE = re.compile(r"secret|midnight|\b12\.\d|taint|combat|perf|lag\b|cpu|memory|leak|crash|error", re.I)


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True).stdout


def fetch(name, src, cache):
    """Return (checkout_dir, head, changelog_fn)."""
    dest = os.path.join(cache, name)
    if src["type"] == "git":
        if not os.path.isdir(dest):
            run(["git", "clone", "--quiet", "--filter=blob:none", "--branch", src["branch"], src["url"], dest])
        head = run(["git", "rev-parse", "HEAD"], cwd=dest).strip()

        def log(paths, pin):
            """[(timestamp, "hash subject")] for commits after pin touching paths."""
            if not pin or pin == head:
                return []
            try:
                out = run(["git", "log", "--no-merges", "--format=%ct %h %s", f"{pin}..{head}", "--"] + paths, cwd=dest)
            except subprocess.CalledProcessError:
                return [(0, f"(old pin {pin[:7]} not found upstream; history unavailable)")]
            return [(int(l.split(" ", 1)[0]), l.split(" ", 1)[1]) for l in out.splitlines() if l.strip()]

        return dest, head, log
    if src["type"] == "svn":
        if not os.path.isdir(dest):
            run(["svn", "export", "--quiet", "--force", src["url"], dest])
        head = run(["svn", "info", "--show-item", "last-changed-revision", src["url"]]).strip()

        def log(paths, pin):
            if not pin or str(pin) == head:
                return []
            out = run(["svn", "log", "--xml", "-r", f"{head}:{int(pin) + 1}", src["url"]])
            msgs = re.findall(r'<logentry\s+revision="(\d+)">.*?<msg>(.*?)</msg>', out, re.S)
            return [(int(rev), f"r{rev} {m.strip().splitlines()[0] if m.strip() else ''}") for rev, m in msgs]

        return dest, head, log
    raise SystemExit(f"unknown source type {src['type']}")


VERSION_PATTERNS = [
    re.compile(r'(MAJOR)\w*\s*,\s*\w*MINOR\w*\s*=\s*["\'][^"\']+["\']\s*,\s*(\d+)'),
    re.compile(r'local\s+Type,\s*Version\s*=\s*"([^"]+)",\s*(\d+)'),
    re.compile(r'NewLibrary\(\s*"([^"]+)"\s*,\s*(\d+)'),
    re.compile(r'"([A-Za-z][\w.-]*-\d\.\d)"\s*,\s*(\d+)'),
    re.compile(r'\b(CTL_VERSION|\w*MINOR\w*)\s*=\s*(\d+)'),
    re.compile(r'(_VERSION)\s*=\s*"([^"]+)"'),
]


def read_version(path):
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except FileNotFoundError:
        return None
    found = {}
    for i, pat in enumerate(VERSION_PATTERNS):
        m = pat.search(text)
        if m:
            found[i] = m.group(2)
    return found


def version_change(before, after):
    """Compare using the first pattern both copies match, so styles agree."""
    if not before:
        return None, (next(iter(after.values())) if after else None)
    for i in sorted(before):
        if i in (after or {}):
            return before[i], after[i]
    return next(iter(before.values())), next(iter(after.values())) if after else None


def version_files(lib, libdir):
    pats = lib.get("versions")
    if not pats:
        base = os.path.basename(lib["path"]) + ".lua"
        pats = [base] if os.path.exists(os.path.join(libdir, base)) else []
    out = []
    for p in pats:
        if "*" in p:
            d = os.path.join(libdir, os.path.dirname(p))
            if os.path.isdir(d):
                out += sorted(os.path.join(os.path.dirname(p), f) for f in os.listdir(d)
                              if fnmatch.fnmatch(f, os.path.basename(p)))
        else:
            out.append(p)
    return out


def walk(top):
    for root, dirs, files in os.walk(top):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            # Nested .toc files are never loaded inside ART_Libraries; their
            # Interface/Version lines only churn, so they are left as shipped.
            if not f.startswith(".") and not f.endswith(".toc"):
                yield os.path.relpath(os.path.join(root, f), top).replace(os.sep, "/")


KEYWORD_RE = re.compile(rb"\$(Id|Revision|Rev|Date|Author|LastChangedDate|LastChangedRevision)\b[^$\n]*\$")


def normalize(data):
    """Compare files ignoring line endings and expanded svn/packager keywords."""
    data = KEYWORD_RE.sub(rb"$\1$", data.replace(b"\r\n", b"\n"))
    return b"\n".join(l.rstrip() for l in data.rstrip().split(b"\n"))


def find_base(checkout, subdir, rel, current):
    """Newest upstream commit whose copy of rel matches what ART ships now."""
    path = f"{subdir}/{rel}" if subdir else rel
    try:
        commits = run(["git", "log", "--format=%H", "-n", "400", "--", path], cwd=checkout).split()
    except subprocess.CalledProcessError:
        return None
    want = normalize(current)
    for h in commits:
        try:
            blob = subprocess.run(["git", "show", f"{h}:{path}"], cwd=checkout, check=True, capture_output=True).stdout
        except subprocess.CalledProcessError:
            continue
        if normalize(blob) == want:
            return h
    return None


def eol_of(data):
    return b"\r\n" if b"\r\n" in data else b"\n"


def lib_eol(libdir):
    for rel in walk(libdir) if os.path.isdir(libdir) else []:
        if rel.endswith(".lua"):
            return eol_of(open(os.path.join(libdir, rel), "rb").read())
    return b"\n"


def to_eol(data, eol):
    data = data.replace(b"\r\n", b"\n")
    return data.replace(b"\n", eol) if eol != b"\n" else data


def check_references(libs_root, toc):
    missing = []
    xml_ref = re.compile(r'(?:Script|Include)\s+file\s*=\s*"([^"]+)"', re.I)
    for rel in walk(libs_root):
        if rel.endswith(".xml"):
            p = os.path.join(libs_root, rel)
            text = re.sub(r"<!--.*?-->", "", open(p, encoding="utf-8", errors="replace").read(), flags=re.S)
            for ref in xml_ref.findall(text):
                target = os.path.normpath(os.path.join(os.path.dirname(p), ref.replace("\\", "/")))
                if not os.path.exists(target):
                    missing.append(f"{rel} -> {ref}")
    if toc and os.path.exists(toc):
        base = os.path.dirname(toc)
        for line in open(toc, encoding="utf-8", errors="replace"):
            line = line.strip()
            if line and not line.startswith("#"):
                if not os.path.exists(os.path.join(base, line.replace("\\", "/"))):
                    missing.append(f"{os.path.basename(toc)} -> {line}")
    return missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=".github/libs.json")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--report", default="lib-update-report.md")
    ap.add_argument("--cache", default=None)
    ap.add_argument("--skip-type", action="append", default=[], help="skip sources of this type (local testing)")
    args = ap.parse_args()

    manifest_path = os.path.join(args.repo, args.manifest)
    manifest = json.load(open(manifest_path))
    libs_root = os.path.join(args.repo, manifest["root"])
    toc = os.path.join(os.path.dirname(libs_root), os.path.basename(os.path.dirname(libs_root)) + ".toc")
    cache = args.cache or tempfile.mkdtemp(prefix="libsrc-")

    fetched = {}
    for name, src in manifest["sources"].items():
        if src["type"] in args.skip_type:
            continue
        fetched[name] = fetch(name, src, cache)

    sections, flagged, any_change = [], [], False
    seen_logs = set()
    for lib in manifest["libs"]:
        if lib["source"] not in fetched:
            continue
        src = manifest["sources"][lib["source"]]
        checkout, head, log = fetched[lib["source"]]
        upstream = os.path.join(checkout, lib["subdir"]) if lib["subdir"] else checkout
        dest = os.path.join(libs_root, lib["path"])
        if not os.path.isdir(upstream):
            raise SystemExit(f"{lib['path']}: upstream folder '{lib['subdir']}' is gone")

        vfiles = version_files(lib, dest)
        before = {f: read_version(os.path.join(dest, f)) for f in vfiles}
        new_eol = lib_eol(dest)
        existing = set(walk(dest)) if os.path.isdir(dest) else set()
        up_files = {f for f in walk(upstream)
                    if not any(fnmatch.fnmatch(f, pat) for pat in lib.get("exclude", []))}

        pin = src.get("pin")
        old_content = {}

        updated, added, skipped_new = [], [], []
        for rel in sorted(up_files):
            target = os.path.join(dest, rel)
            data = open(os.path.join(upstream, rel), "rb").read()
            if rel in existing:
                cur = open(target, "rb").read()
                if normalize(cur) == normalize(data):
                    continue
                old_content[rel] = cur
                open(target, "wb").write(to_eol(data, eol_of(cur)))
                updated.append(rel)
            elif lib.get("only_existing"):
                skipped_new.append(rel)
            else:
                os.makedirs(os.path.dirname(target), exist_ok=True)
                open(target, "wb").write(to_eol(data, new_eol))
                added.append(rel)
        kept = sorted(existing - up_files)

        if not (updated or added):
            continue
        any_change = True
        vfiles = version_files(lib, dest)
        after = {f: read_version(os.path.join(dest, f)) for f in vfiles}
        vchanges = []
        for f in vfiles:
            old, new = version_change(before.get(f), after.get(f))
            if old != new:
                vchanges.append(f"`{f}` {old or 'new'} → {new}")

        # Changelog: commits since the pin, or (first sync) since the upstream
        # commit each updated file last matched, so only changes ART lacks show.
        prefix = lib["subdir"] + "/" if lib["subdir"] else ""
        entries, unknown = {}, False
        if pin is not None:
            groups = [([lib["subdir"]] if lib["subdir"] else [], pin)]
        elif src["type"] == "git":
            groups = []
            for rel in updated:
                b = find_base(checkout, lib["subdir"], rel, old_content[rel])
                if b:
                    groups.append(([prefix + rel], b))
                else:
                    unknown = True
        else:
            groups, unknown = [], True
        for paths, b in groups:
            for ts, c in log(paths, b):
                entries.setdefault(c, ts)
        key = (lib["source"], lib["subdir"])
        commits = [] if key in seen_logs and pin is not None else [c for c, _ in sorted(entries.items(), key=lambda kv: -kv[1])]
        seen_logs.add(key)

        lines = [f"### {lib['path']}", ""]
        lines.append("Version: " + ("; ".join(vchanges) if vchanges else "unchanged (code changed without a version bump)"))
        lines.append("")
        if commits:
            lines.append("Upstream changes:")
            for c in commits:
                mark = " ⚠️" if FLAG_RE.search(c) else ""
                lines.append(f"- {c}{mark}")
                if mark:
                    flagged.append(f"{lib['path']}: {c}")
        if unknown:
            lines.append(f"Some files had no matching upstream history (first tracked sync from {src['url']}, now at {head[:12]}), so not every change is listed.")
        lines.append("")
        lines.append("Files updated: " + (", ".join(f"`{f}`" for f in updated) or "none"))
        if added:
            lines.append("Files added: " + ", ".join(f"`{f}`" for f in added))
        if skipped_new:
            shown = ", ".join(f"`{f}`" for f in skipped_new[:5]) + (f" and {len(skipped_new) - 5} more" if len(skipped_new) > 5 else "")
            lines.append(f"New upstream files not copied (this library ships a fixed file list): {shown}")
        if kept:
            lines.append("Kept, not in upstream: " + ", ".join(f"`{f}`" for f in kept))
        sections.append("\n".join(lines))

    for name, (_, head, _) in fetched.items():
        manifest["sources"][name]["pin"] = head
    with open(manifest_path, "w", newline="\n") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")

    missing = check_references(libs_root, toc)
    if missing:
        print("Files named by .toc/.xml are missing after the sync:", *missing, sep="\n  ", file=sys.stderr)
        sys.exit(1)

    report = "## Library updates\n\n"
    if flagged:
        report += "Upstream changes that mention secret values, game versions, errors or performance:\n\n"
        report += "".join(f"- {f}\n" for f in flagged) + "\n"
    report += "\n\n".join(sections) if sections else "No library changed."
    with open(args.report, "w", newline="\n") as fh:
        fh.write(report + "\n")

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a") as fh:
            fh.write(f"changed={'true' if any_change else 'false'}\n")
    print(f"changed={'true' if any_change else 'false'}")


if __name__ == "__main__":
    main()
