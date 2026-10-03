#!/usr/bin/env python3
"""Build the download site from site/ and the newest GitHub Release.

Fills site/index.html from the newest published release: its .dmg and the
build-info.json that tools/verify_dmg.sh wrote. The tower roster and the
tower and wave counts come from the game's own data (src/data/tower_defs.gd,
src/data/wave_defs.gd, src/ui/tower_info.gd), so the page follows rebalances. A private repo's release files
need a login to download, so for a private repo the .dmg is copied into the
site and served from there; a public repo links to the release file. With no
release (or no token), the page says the first build is on its way.

Usage: tools/build_site.py [--out build/site] [--repo owner/name] [--offline]
Token: GH_TOKEN or GITHUB_TOKEN, else `gh auth token`.
"""

import argparse
import ast
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
# Element colors from src/ui/ui_theme.gd.
ELEMENT_COLORS = {
    "light": "#ffeda3",
    "dark": "#b880fa",
    "aqua": "#61bdff",
    "flame": "#ff8538",
    "verdant": "#80e059",
    "stone": "#c7ad8a",
}
NO_ELEMENT_COLOR = "#c79e52"
# 24x24 stroke icons for the roster cards, by attack type.
ATTACK_ICONS = {
    "pierce": "M5 19 19 5M19 5h-6M19 5v6M5 19l2.5-.5M5 19l.5-2.5",
    "siege": "M11 20a6.5 6.5 0 1 1 0-13 6.5 6.5 0 0 1 0 13zM15.5 8.5 18 6M18 6l2 .5M18 6l-.5-2",
    "magic": "M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9",
    "poison": "M12 3.5c3.8 4.6 5.8 7.8 5.8 10.6a5.8 5.8 0 0 1-11.6 0c0-2.8 2-6 5.8-10.6z",
    "rune": "M13.5 4.5l6 6-3 3-6-6zM10.5 10.5 4 17l3 3 6.5-6.5",
    "aura": "M9 17.5V5.5l10-2v12M9 17.5a2.75 2.75 0 1 1-5.5 0 2.75 2.75 0 0 1 5.5 0z"
    "M19 15.5a2.75 2.75 0 1 1-5.5 0 2.75 2.75 0 0 1 5.5 0z",
}


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


def gd_const(path: Path, name: str):
    """A dictionary or array constant from a GDScript file, as Python data.
    Handles the literals the data files use: strings (also joined with +),
    StringNames, numbers, booleans, Vector2i (as a tuple), nested arrays and
    dictionaries."""
    src = path.read_text()
    m = re.search(rf"^const {name}(?:\s*:\s*[^=]+)?\s*:?=\s*", src, re.M)
    if not m or src[m.end()] not in "{[":
        sys.exit(f"build_site: no {name} constant in {path.relative_to(ROOT)}")
    start, pairs, depth = m.end(), {"{": "}", "[": "]"}, 0
    for end in range(start, len(src)):
        if src[end] == src[start]:
            depth += 1
        elif src[end] == pairs[src[start]]:
            depth -= 1
            if depth == 0:
                break
    text = src[start:end + 1]
    text = re.sub(r"(?m)^\s*#.*$", "", text)
    text = re.sub(r'&"', '"', text)
    text = re.sub(r'"\s*\+\s*"', "", text)
    text = re.sub(r"\bVector2i?\(", "(", text)
    text = re.sub(r"\btrue\b", "True", text)
    text = re.sub(r"\bfalse\b", "False", text)
    try:
        return ast.literal_eval(text)
    except (SyntaxError, ValueError) as e:
        sys.exit(f"build_site: can't read {name} in {path.relative_to(ROOT)}: {e}")


def game_data() -> dict:
    defs = ROOT / "src" / "data" / "tower_defs.gd"
    info = ROOT / "src" / "ui" / "tower_info.gd"
    maps = ROOT / "src" / "data" / "map_defs.gd"
    return {
        "towers": gd_const(defs, "TOWERS"),
        "order": gd_const(defs, "BUILD_ORDER"),
        "epics": gd_const(defs, "EPICS"),
        "short": gd_const(info, "SHORT_NAMES"),
        "blurbs": gd_const(info, "BLURBS"),
        "families": gd_const(info, "FAMILY_NAMES"),
        "attacks": gd_const(info, "ATTACK_NAMES"),
        "elements": gd_const(info, "ELEMENT_NAMES"),
        "waves": gd_const(ROOT / "src" / "data" / "wave_defs.gd", "WAVES"),
        "maps": gd_const(maps, "MAPS"),
        "map_order": gd_const(maps, "ORDER"),
    }


def and_list(words: list) -> str:
    return " and ".join(filter(None, [", ".join(words[:-1]), words[-1]]))


def num(v) -> str:
    return f"{v:g}"


def pct(v) -> str:
    return f"{round(v * 100)}"


def nth(v) -> str:
    v = int(v)
    suffix = "th" if 10 <= v % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(v % 10, "th")
    return f"{v}{suffix}"


# What each tower stat reads like on a level card, in display order. The main
# stats show on every level; the rest only where they first appear or change.
STAT_WORDS = [
    ("damage", lambda v: f"{num(v)} damage" if v else ""),
    ("poison_dps", lambda v: f"{num(v)} poison/s"),
    ("cloud_dps", lambda v: f"{num(v)} poison/s clouds"),
    ("aura_damage", lambda v: f"+{pct(v)}% tower damage"),
    ("aura_haste", lambda v: f"+{pct(v)}% attack speed" if v else ""),
    ("multishot", lambda v: f"{v} arrows" if v > 1 else ""),
    ("pierce", lambda v: f"pierces {v}"),
    ("lance_length", lambda v: f"{num(v)} m lance"),
    ("cone_degrees", lambda v: f"{num(v)}° cone"),
    ("splash", lambda v: f"splash {num(v)}"),
    ("slow", lambda v: f"slows {pct(v)}%"),
    ("slow_splash", lambda v: f"slow splash {num(v)}" if v else ""),
    ("ring_every", lambda v: f"frost ring every {nth(v)} shot" if v else ""),
    ("root", lambda v: f"roots {num(v)} s"),
    ("shred", lambda v: f"shreds {num(v)} armor"),
    ("poison_stacks", lambda v: f"stacks {v}×"),
    ("contagion_radius", lambda v: f"spreads {num(v)} m"),
    ("max_clouds", lambda v: f"up to {v} clouds"),
    ("crater_dps", lambda v: f"crater {num(v)}/s"),
    ("freeze_every", lambda v: f"freezes every {nth(v)} breath"),
    ("min_range", lambda v: f"min range {num(v)}"),
]
MAIN_STATS = {"damage", "poison_dps", "cloud_dps", "aura_damage"}


def level_words(tower: dict, levels: int) -> list:
    """One line per level: the stats that matter at that level."""
    lines = []
    for i in range(levels):
        words = []
        for key, say in STAT_WORDS:
            if key not in tower:
                continue
            v = tower[key][i] if isinstance(tower[key], list) else tower[key]
            prev = None
            if i > 0:
                prev = tower[key][i - 1] if isinstance(tower[key], list) else tower[key]
            if key not in MAIN_STATS and i > 0 and v == prev:
                continue
            text = say(v)
            if text:
                words.append(text)
        line = ", ".join(words)
        lines.append(line[:1].upper() + line[1:])
    return lines


def roster_html(data: dict) -> str:
    """Tower cards and one detail panel per tower; the page script shows one
    panel at a time, and without scripts every panel is listed."""
    esc = html.escape
    ids = list(data["order"]) + list(data["epics"])
    cards, panels = [], []
    for n, tid in enumerate(ids):
        t = data["towers"][tid]
        epic = tid in data["epics"]
        key = "G" if epic else str((n + 1) % 10)
        element = t.get("element")
        color = ELEMENT_COLORS.get(element, NO_ELEMENT_COLOR)
        element_name = data["elements"].get(element, "No element")
        family = data["families"].get(t["family"], t["family"].title())
        attack = t.get("attack")
        icon = ATTACK_ICONS.get(attack or "aura", ATTACK_ICONS["aura"])
        if epic:
            price = f"+{t['fuse_cost']}"
            costs = [("Fuse", price)]
        else:
            price = str(t["cost"][0])
            costs = [("Level 1", price)] + [(f"Level {i + 2}", f"+{c}") for i, c in enumerate(t["cost"][1:])]
        rng = t["range"] if isinstance(t["range"], list) else [t["range"]]
        reach = num(rng[0]) if rng[0] == rng[-1] else f"{num(rng[0])} to {num(rng[-1])}"
        # The element chip wears the element's color; the rest are plain.
        chips = [
            ("", f"{family} Epic" if epic else family),
            (' class="chip-el"' if element else "", element_name),
            ("", f"{data['attacks'][attack]} attack" if attack else "Aura"),
            ("", "Buffs towers in range" if t["kind"] == "aura" else ("Hits air and ground" if t.get("air") else "Ground only")),
            ("", f"Range {reach}"),
        ]
        blurb = data["blurbs"].get(tid, "")
        if epic:
            blurb += f" Fuse two level-3 {family} towers to build it."
        short = data["short"].get(tid, t["name"])
        pressed = "true" if n == 0 else "false"
        cards.append(
            f'<button type="button" class="card" data-tower="{esc(tid)}" aria-pressed="{pressed}" '
            f'aria-controls="tower-{esc(tid)}" style="--el: {color}">'
            f'<span class="card-key">{key}</span>'
            f'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="{icon}"/></svg>'
            f'<span class="card-name">{esc(short)}</span>'
            f'<span class="card-cost">{esc(price)}</span></button>'
        )
        levels = "".join(
            f'<li><span class="lv">{label}</span><span class="lv-cost">{esc(cost)}</span>'
            f'<span class="lv-fx">{esc(words)}</span></li>'
            for (label, cost), words in zip(costs, level_words(t, len(costs)))
        )
        panels.append(
            f'<article class="panel" id="tower-{esc(tid)}" style="--el: {color}">'
            f'<div class="panel-main"><h3>{esc(t["name"])}</h3>'
            f'<p class="panel-blurb">{esc(blurb.strip())}</p>'
            f'<ul class="chips">{"".join(f"<li{cls}>{esc(c)}</li>" for cls, c in chips)}</ul></div>'
            f'<ol class="levels" aria-label="Cost and effect per level">{levels}</ol></article>'
        )
    # Epics start their own row, under a line that says how to get one.
    towers = len(data["order"])
    if len(cards) > towers:
        cards.insert(towers, '<p class="roster-sep">Epics, each fused from two level-3 towers of one family</p>')
    return (
        '<div class="roster" role="group" aria-label="Towers">\n'
        + "\n".join(cards)
        + '\n</div>\n<div class="panels" aria-live="polite">\n'
        + "\n".join(panels)
        + "\n</div>"
    )


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
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Jost:wght@300..700&display=swap">
{style}
<style>
.credits {{ padding-block: 48px 72px; display: grid; gap: 14px; max-width: 52rem; }}
.credits h1 {{ font: 400 var(--step-2)/1.1 var(--font); }}
.credits h2 {{ margin-top: 24px; font-size: var(--step-1); }}
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
    data = game_data()
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
        "tower_count": len(data["order"]),
        "epic_count": len(data["epics"]),
        "wave_count": len(data["waves"]),
        "map_count": len(data["map_order"]),
        "map_names": and_list([data["maps"][m]["name"] for m in data["map_order"]]),
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
    page = render(template, values, flags)
    if "<!--roster-->" not in page:
        sys.exit("build_site: site/index.html has no <!--roster--> marker")
    page = page.replace("<!--roster-->", roster_html(data))
    (out / "index.html").write_text(page)
    style = re.search(r"<style>.*?</style>", template, re.S).group(0)
    (out / "credits.html").write_text(credits_html(style))
    shutil.copytree(src / "img", out / "img", dirs_exist_ok=True)
    for name in (".nojekyll", ".gdignore"):
        (out / name).touch()
    latest = {k: v for k, v in values.items() if k not in ("site_url", "tower_count", "epic_count", "wave_count", "map_count", "map_names")}
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
