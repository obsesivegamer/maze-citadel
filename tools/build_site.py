#!/usr/bin/env python3
"""Build the download site from site/ and the newest GitHub Release.

Fills site/index.html from the newest published release: its .dmg and the
build-info.json that tools/verify_dmg.sh wrote. A private repo's release files
need a login to download, so for a private repo the .dmg is copied into the
site and served from there; a public repo links to the release file. With no
release (or no token), the page says the first build is on its way.

Usage: tools/build_site.py [--out build/site] [--repo owner/name] [--offline]
Token: GH_TOKEN or GITHUB_TOKEN, else `gh auth token`.
"""

import argparse
import datetime
import html
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
API = "https://api.github.com"
MACOS_NAMES = {"13": "Ventura", "14": "Sonoma", "15": "Sequoia", "26": "Tahoe"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def token() -> str:
    for name in ("GH_TOKEN", "GITHUB_TOKEN"):
        if os.environ.get(name):
            return os.environ[name]
    try:
        out = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def request(url: str, tok: str, accept="application/vnd.github+json"):
    headers = {"Accept": accept, "X-GitHub-Api-Version": "2022-11-28"}
    if tok:
        headers["Authorization"] = f"Bearer {tok}"
    return urllib.request.Request(url, headers=headers)


def api(path: str, tok: str):
    with urllib.request.urlopen(request(API + path, tok), timeout=30) as r:
        return json.load(r)


def download_asset(asset: dict, tok: str, dest: Path) -> None:
    """Release asset download. The API answers with a redirect to signed
    storage, which must be fetched without the GitHub token."""
    opener = urllib.request.build_opener(NoRedirect)
    try:
        resp = opener.open(request(asset["url"], tok, "application/octet-stream"), timeout=60)
    except urllib.error.HTTPError as e:
        if e.code not in (301, 302, 303, 307, 308):
            raise
        resp = urllib.request.urlopen(e.headers["Location"], timeout=300)
    with resp, open(dest, "wb") as f:
        shutil.copyfileobj(resp, f)


def repo_name(arg: str) -> str:
    if arg:
        return arg
    if os.environ.get("GITHUB_REPOSITORY"):
        return os.environ["GITHUB_REPOSITORY"]
    url = subprocess.run(
        ["git", "-C", str(ROOT), "remote", "get-url", "origin"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    m = re.search(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", url)
    if not m:
        sys.exit(f"build_site: can't tell the GitHub repo from origin {url!r}; pass --repo")
    return m.group(1)


def project_defaults() -> dict:
    project = (ROOT / "project.godot").read_text()
    presets = (ROOT / "export_presets.cfg").read_text()
    version = re.search(r'^config/version="(.*)"', project, re.M).group(1)
    min_os = re.search(r'^application/min_macos_version_arm64="(.*)"', presets, re.M)
    return {
        "version": version,
        "dmg": f"MazeCitadel-{version}.dmg",
        "min_macos": min_os.group(1) if min_os else "13.0",
        "notarized": False,
    }


def fetch_release(repo: str, tok: str, out: Path):
    """Newest non-draft release with a .dmg, as template values, or None."""
    info = api(f"/repos/{repo}", tok)
    private = info.get("private", True)
    releases = api(f"/repos/{repo}/releases?per_page=20", tok)
    for rel in releases:
        if rel.get("draft"):
            continue
        assets = {a["name"]: a for a in rel.get("assets", [])}
        dmg = next((a for n, a in assets.items() if n.endswith(".dmg")), None)
        if not dmg:
            continue
        build = {}
        if "build-info.json" in assets:
            path = out / "build-info.json"
            download_asset(assets["build-info.json"], tok, path)
            build = json.loads(path.read_text())
        if private:
            (out / "download").mkdir(parents=True, exist_ok=True)
            download_asset(dmg, tok, out / "download" / dmg["name"])
            href = f"download/{dmg['name']}"
        else:
            href = dmg["browser_download_url"]
        published = datetime.datetime.fromisoformat(rel["published_at"].replace("Z", "+00:00"))
        return {
            "version": build.get("version") or rel["tag_name"].lstrip("v"),
            "dmg": dmg["name"],
            "dmg_href": href,
            "size_bytes": dmg["size"],
            "sha256": build.get("sha256", ""),
            "app_bytes": build.get("app_bytes", 0),
            "min_macos": build.get("min_macos", ""),
            "notarized": bool(build.get("notarized")),
            "prerelease": bool(rel.get("prerelease")),
            "release_url": rel["html_url"],
            "release_date": published,
            "tag": rel["tag_name"],
            "public": not private,
        }
    return None


def site_url(repo: str, tok: str) -> str:
    try:
        url = api(f"/repos/{repo}/pages", tok).get("html_url", "")
    except urllib.error.HTTPError:
        return ""
    return url if url.endswith("/") else url + "/"


def render(template: str, values: dict, flags: dict) -> str:
    block = re.compile(r"<!--if:(\w+)-->(.*?)<!--end:\1-->", re.S)
    while True:
        new = block.sub(lambda m: m.group(2) if flags.get(m.group(1)) else "", template)
        if new == template:
            break
        template = new

    def value(m):
        key = m.group(1)
        if key not in values:
            sys.exit(f"build_site: no value for {{{{{key}}}}} in the template")
        return html.escape(str(values[key]))

    return re.sub(r"\{\{(\w+)\}\}", value, template)


def credits_html(style: str) -> str:
    """assets/CREDITS.md as a page; CC-BY sounds need visible attribution."""
    body = ["<p>Maze Citadel is built with free models, textures, sounds and fonts by these artists.</p>"]
    md = (ROOT / "assets" / "CREDITS.md").read_text()
    for chunk in re.split(r"\n\s*\n", md):
        lines = [line.strip() for line in chunk.strip().splitlines()]
        if not lines or lines[0].startswith("Generated by"):
            continue  # the note for maintainers about how the file is made
        text = html.escape("\n".join(lines))
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
        text = re.sub(r"(https?://[^\s|,<]+)", r'<a href="\1">\1</a>', text)
        if text.startswith("## "):
            body.append(f"<h2>{text[3:]}</h2>")
        elif text.startswith("# "):
            body.append(f"<h1>{text[2:]}</h1>")
        elif text.startswith("- "):
            items = "".join(f"<li>{item}</li>" for item in re.split(r"\n- ", text[2:]))
            body.append(f"<ul>{items}</ul>")
        else:
            body.append(f"<p>{' '.join(text.splitlines())}</p>")
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Credits · Maze Citadel</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;800&family=Fira+Sans:wght@400;500;700&display=swap">
{style}
<style>
.credits {{ padding-block: 48px 72px; display: grid; gap: 14px; max-width: 52rem; }}
.credits h1 {{ font: 800 var(--step-2)/1.1 var(--display); color: var(--gold-bright); }}
.credits h2 {{ margin-top: 24px; }}
.credits ul {{ display: grid; gap: 8px; padding-left: 1.2em; color: var(--text-dim); font-size: var(--step--1); }}
.credits p {{ color: var(--text-dim); }}
.credits a {{ overflow-wrap: anywhere; }}
</style>
</head>
<body>
<main class="wrap credits">
<p><a href="./">← Maze Citadel</a></p>
{chr(10).join(body)}
</main>
</body>
</html>
"""


def build(out: Path, release, url: str) -> dict:
    src = ROOT / "site"
    defaults = project_defaults()
    rel = release or {}
    min_macos = (rel.get("min_macos") or defaults["min_macos"]).split(".")[0]
    dmg = rel.get("dmg", defaults["dmg"])
    date = rel.get("release_date")
    # Free space to ask for: the installed app, rounded up to the next 50 MB.
    disk_mb = -(-(rel.get("app_bytes") or 180 * 1048576) // (50 * 1048576)) * 50
    values = {
        "version": rel.get("version", defaults["version"]),
        "dmg_name": dmg,
        "dmg_href": rel.get("dmg_href", ""),
        "size_mb": f"{round(rel['size_bytes'] / 1048576)} MB" if release else "",
        "sha256": rel.get("sha256", ""),
        "disk_mb": disk_mb,
        "min_macos": min_macos,
        "min_macos_name": f"{min_macos} {MACOS_NAMES.get(min_macos, '')}".strip(),
        "release_date": f"{date.day} {date:%B %Y}" if date else "",
        "release_url": rel.get("release_url", ""),
        "site_url": url,
    }
    flags = {
        "release": bool(release),
        "no_release": not release,
        "prerelease": rel.get("prerelease", False),
        "notarized": rel.get("notarized", False),
        "unsigned": not rel.get("notarized", False),
        "public": rel.get("public", False),
        "site_url": bool(url),
    }
    template = (src / "index.html").read_text()
    (out / "index.html").write_text(render(template, values, flags))
    style = re.search(r"<style>.*?</style>", template, re.S).group(0)
    (out / "credits.html").write_text(credits_html(style))
    shutil.copytree(src / "img", out / "img", dirs_exist_ok=True)
    for name in (".nojekyll", ".gdignore"):
        (out / name).touch()
    latest = {k: v for k, v in values.items() if k not in ("site_url",)}
    latest["available"] = bool(release)
    latest["notarized"] = flags["notarized"]
    (out / "latest.json").write_text(json.dumps(latest, indent=2) + "\n")
    return latest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(ROOT / "build" / "site"))
    parser.add_argument("--repo", default="")
    parser.add_argument("--offline", action="store_true", help="skip GitHub; build the no-release page")
    args = parser.parse_args()

    out = Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    release, url = None, ""
    if not args.offline:
        repo, tok = repo_name(args.repo), token()
        try:
            release = fetch_release(repo, tok, out)
            url = site_url(repo, tok)
        except urllib.error.URLError as e:
            print(f"build_site: GitHub API failed for {repo} ({e}); building without a release")
    latest = build(out, release, url)
    if release:
        where = "copied into the site" if not release["public"] else "linked from the release"
        print(f"build_site: {release['tag']} ({latest['dmg_name']}, {latest['size_mb']}), .dmg {where}")
    else:
        print("build_site: no release yet; the page says the first build is on its way")
    print(f"build_site: wrote {out}")


if __name__ == "__main__":
    main()
