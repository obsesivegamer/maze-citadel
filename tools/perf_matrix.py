#!/usr/bin/env python3
"""Planner and summariser for tools/perf_matrix.sh.

  perf_matrix.py plan <configs> [--repeats N] [--control-every N] [--scenes a,b] [--only a,b]
      prints one run per line, fields separated by \\x1f:
      seq, tag, name, role, scene, repeat, engine args, override tokens, game args
  perf_matrix.py override-cfg <+section/key=value ...>
      prints an override.cfg for those startup-only project settings
  perf_matrix.py estimate <battle runs> <idle runs> <seconds> <rest> [captures]
      prints the expected wall-clock minutes
  perf_matrix.py brief <report.json> <tag>
      prints one progress line for a finished run
  perf_matrix.py summarise <matrix dir>
      writes <dir>/summary.md from runs.tsv and the bench JSONs, and prints it

Config file: one configuration per line, `name | engine args | game args`;
`#` starts a comment. Engine args go before `--`; a `+section/key=value`
token among them is a startup-only project setting, written to a temporary
override.cfg for that run. A line named `control` replaces the default
control (the preset with no extra arguments).
"""

from __future__ import annotations

import json
import re
import statistics
import sys
from dataclasses import dataclass, field
from pathlib import Path

SEP = "\x1f"
OVERRIDE_MARKER = "; perf_matrix.sh: temporary, removed after each run"
NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")
OVERRIDE_RE = re.compile(r"^\+([A-Za-z0-9_]+)/([A-Za-z0-9_./-]+)=(.*)$")
# Seconds a run takes besides the measured window: launch, the 4 s bench
# warm-up and quit, plus ~12 s of warp to wave 24 for the battle (timed
# headless). A capture warps too and renders two views.
OVERHEAD_S = {"battle": 22, "idle": 10}
CAPTURE_S = 30
LOG_NOTES = (("PerfRender:", "bad --pf value"), ("Falling back", "renderer fallback"))
RUNS_HEADER = [
    "seq", "tag", "name", "role", "scene", "repeat", "status", "exit",
    "json", "log", "started", "ended", "engine", "overrides", "game",
]


class ConfigError(ValueError):
    pass


@dataclass
class Config:
    name: str
    engine: list[str] = field(default_factory=list)
    overrides: list[str] = field(default_factory=list)
    game: list[str] = field(default_factory=list)


@dataclass
class Run:
    seq: int
    config: Config
    role: str
    scene: str
    repeat: int

    @property
    def tag(self) -> str:
        return f"{self.seq:03d}-{self.config.name}-{self.scene}"


def parse_configs(text: str) -> tuple[Config, list[Config]]:
    """The control and the test configurations, in file order."""
    control = Config("control")
    configs: list[Config] = []
    seen = set()
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) > 3:
            raise ConfigError(f"line {lineno}: expected `name | engine args | game args`")
        parts += [""] * (3 - len(parts))
        name, engine, game = parts
        if not NAME_RE.match(name):
            raise ConfigError(f"line {lineno}: bad name {name!r} (letters, digits, . _ -)")
        if name in seen:
            raise ConfigError(f"line {lineno}: duplicate name {name!r}")
        seen.add(name)
        c = Config(name)
        for tok in engine.split():
            if tok.startswith("+"):
                if not OVERRIDE_RE.match(tok):
                    raise ConfigError(f"line {lineno}: override {tok!r} is not +section/key=value")
                c.overrides.append(tok)
            elif tok == "--":
                raise ConfigError(f"line {lineno}: no `--` in engine args; use the game column")
            else:
                c.engine.append(tok)
        for tok in game.split():
            if not tok.startswith("--"):
                raise ConfigError(
                    f"line {lineno}: game arg {tok!r} must look like --key=value "
                    "(engine args go in the middle column)"
                )
            c.game.append(tok)
        if name == "control":
            control = c
        else:
            configs.append(c)
    return control, configs


def plan(
    control: Config,
    configs: list[Config],
    repeats: int = 3,
    control_every: int = 4,
    scenes: tuple[str, ...] = ("battle",),
) -> list[Run]:
    """Every repeat runs all configurations with a control before the first
    and after every `control_every` (and after the last). Even repeats run the
    list backwards so slow heat build-up doesn't favour the first configs."""
    slots: list[tuple[Config, str, int]] = [(control, "control", 1)]
    for r in range(1, repeats + 1):
        order = configs if r % 2 == 1 else list(reversed(configs))
        for i, c in enumerate(order, 1):
            slots.append((c, "test", r))
            if (control_every > 0 and i % control_every == 0) or i == len(order):
                slots.append((control, "control", r))
    runs: list[Run] = []
    for c, role, r in slots:
        for s in scenes:
            runs.append(Run(len(runs) + 1, c, role, s, r))
    return runs


def override_cfg(tokens: list[str]) -> str:
    sections: dict[str, list[str]] = {}
    for tok in tokens:
        m = OVERRIDE_RE.match(tok)
        if not m:
            raise ConfigError(f"override {tok!r} is not +section/key=value")
        sections.setdefault(m.group(1), []).append(f"{m.group(2)}={m.group(3)}")
    lines = [OVERRIDE_MARKER]
    for section, keys in sections.items():
        lines += ["", f"[{section}]"] + keys
    return "\n".join(lines) + "\n"


def estimate_minutes(
    battle: int, idle: int, seconds: float, rest: float, captures: int = 0
) -> float:
    runs = battle + idle
    total = (
        runs * seconds
        + battle * OVERHEAD_S["battle"]
        + idle * OVERHEAD_S["idle"]
        + max(runs - 1, 0) * rest
        + captures * CAPTURE_S
    )
    return total / 60.0


# ---------------------------------------------------------------- summary


@dataclass
class Result:
    seq: int
    name: str
    role: str
    scene: str
    status: str
    exit: str
    engine: str
    overrides: str
    game: str
    report: dict
    notes: list[str]

    @property
    def ok(self) -> bool:
        return self.status == "ok"

    @property
    def focused(self) -> bool:
        return bool(self.report.get("focused"))


def load_results(matrix: Path) -> list[Result]:
    out = []
    lines = (matrix / "runs.tsv").read_text().splitlines()
    for line in lines[1:]:
        if not line.strip():
            continue
        row = dict(zip(RUNS_HEADER, line.split("\t")))
        report: dict = {}
        status = row.get("status", "")
        try:
            report = json.loads((matrix / row["json"]).read_text())
        except (OSError, ValueError, KeyError):
            if status == "ok":
                status = "no-json"
        if report.get("crashed"):
            status = report.get("status", "crashed")
        out.append(
            Result(
                seq=int(row["seq"]),
                name=row["name"],
                role=row["role"],
                scene=row["scene"],
                status=status,
                exit=row.get("exit", ""),
                engine=row.get("engine", ""),
                overrides=row.get("overrides", ""),
                game=row.get("game", ""),
                report=report,
                notes=_log_notes(matrix / row.get("log", "")),
            )
        )
    return out


def _log_notes(log: Path) -> list[str]:
    try:
        text = log.read_text(errors="replace") if log.is_file() else ""
    except OSError:
        return []
    return [note for needle, note in LOG_NOTES if needle in text]


def measured(results: list[Result]) -> list[Result]:
    """Runs whose numbers count: finished and focused. If none was focused
    (a headless plumbing test), every finished run, so the table still fills."""
    ok = [r for r in results if r.ok]
    focused = [r for r in ok if r.focused]
    return focused or ok


def control_ms(run: Result, controls: list[Result]) -> float | None:
    """Mean frame time of the nearest control before and after `run`."""
    before = [c for c in controls if c.seq < run.seq]
    after = [c for c in controls if c.seq > run.seq]
    near = []
    if before:
        near.append(max(before, key=lambda c: c.seq))
    if after:
        near.append(min(after, key=lambda c: c.seq))
    if not near:
        return None
    return statistics.mean(c.report["avg_frame_ms"] for c in near)


def _median(runs: list[Result], key: str) -> float | None:
    values = [r.report[key] for r in runs if isinstance(r.report.get(key), (int, float))]
    return statistics.median(values) if values else None


def _fmt(value: float | None, digits: int = 1, signed: bool = False) -> str:
    if value is None:
        return "—"
    text = f"{value:+.{digits}f}" if signed else f"{value:,.{digits}f}"
    return text.replace("-", "−")


def _control_first(r: Result) -> tuple[bool, int]:
    return (r.role != "control", r.seq)


def summary_rows(results: list[Result]) -> list[dict]:
    order: list[tuple[str, str]] = []
    for r in sorted(results, key=_control_first):
        if (r.name, r.scene) not in order:
            order.append((r.name, r.scene))
    rows = []
    for name, scene in order:
        runs = [r for r in results if r.name == name and r.scene == scene]
        good = measured(runs)
        controls = measured([r for r in results if r.role == "control" and r.scene == scene])
        deltas = []
        if runs[0].role != "control":
            for r in good:
                ctrl = control_ms(r, [c for c in controls if c.focused == r.focused])
                if ctrl is not None:
                    deltas.append(r.report["avg_frame_ms"] - ctrl)
        notes = []
        for status in ("crashed", "timeout", "no-json"):
            n = sum(1 for r in runs if r.status == status)
            if n:
                notes.append(f"{status} ×{n}")
        n = sum(1 for r in runs if r.ok and r.exit not in ("", "0"))
        if n:
            notes.append(f"exit≠0 after report ×{n}")
        notes += dict.fromkeys(note for r in runs for note in r.notes)
        prims = _median(good, "max_primitives")
        rows.append(
            {
                "name": name,
                "scene": scene,
                "role": runs[0].role,
                "runs": f"{sum(1 for r in runs if r.ok)}/{len(runs)}",
                "focused": f"{sum(1 for r in runs if r.ok and r.focused)}/{len(runs)}",
                "fps": _median(good, "avg_fps"),
                "low": _median(good, "low_1pct_fps"),
                "ms": _median(good, "avg_frame_ms"),
                "delta": statistics.median(deltas) if deltas else None,
                "draws": _median(good, "max_draw_calls"),
                "prims_m": prims / 1e6 if prims is not None else None,
                "vmem": _median(good, "video_mem_mb"),
                "notes": ", ".join(notes),
            }
        )
    return rows


def render_summary(results: list[Result], title: str, params: str = "") -> str:
    rows = summary_rows(results)
    out = [f"# {title}", ""]
    if params:
        out += [f"`{params.strip()}`", ""]
    out += [
        "Medians over focused runs. Δ ms is each run's frame time minus the mean of the",
        "nearest control before and after it (same scene), then the median; negative is faster.",
        "",
        "| Config | Scene | OK | Focused | Avg fps | 1% low | Frame ms | Δ ms vs control "
        "| Draw calls | Primitives | Video MB | Notes |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        out.append(
            "| {name} | {scene} | {runs} | {focused} | {fps} | {low} | {ms} | {delta} "
            "| {draws} | {prims} | {vmem} | {notes} |".format(
                name=f"**{row['name']}**" if row["role"] == "control" else row["name"],
                scene=row["scene"],
                runs=row["runs"],
                focused=row["focused"],
                fps=_fmt(row["fps"]),
                low=_fmt(row["low"]),
                ms=_fmt(row["ms"], 2),
                delta=_fmt(row["delta"], 2, signed=True),
                draws=_fmt(row["draws"], 0),
                prims=_fmt(row["prims_m"], 2) + (" M" if row["prims_m"] is not None else ""),
                vmem=_fmt(row["vmem"], 0),
                notes=row["notes"],
            )
        )
    out += [
        "",
        "## Configurations",
        "",
        "Reported: the rendering method and override.cfg values from the config's first report,",
        "to confirm the engine took them.",
        "",
        "| Config | Engine args | override.cfg | Game args | Reported |",
        "|---|---|---|---|---|",
    ]
    names = list(dict.fromkeys(r.name for r in sorted(results, key=_control_first)))
    for name in names:
        runs = [r for r in results if r.name == name]
        first = runs[0]
        report = next((r.report for r in runs if r.ok), {})
        reported = report.get("rendering_method", "")
        for k, v in report.get("project_overrides", {}).items():
            reported += f", {k}={v}"
        out.append(
            f"| {name} | {_code(first.engine)} | {_code(first.overrides)} "
            f"| {_code(first.game)} | {reported} |"
        )
    bad = [r for r in results if not r.ok]
    if bad:
        out += ["", "## Failed runs", "", "| Seq | Config | Scene | Status | Exit |",
                "|---|---|---|---|---|"]
        for r in bad:
            out.append(f"| {r.seq} | {r.name} | {r.scene} | {r.status} | {r.exit} |")
    return "\n".join(out) + "\n"


def brief(report_path: Path, tag: str) -> str:
    """One progress line for a finished run."""
    try:
        r = json.loads(report_path.read_text())
    except (OSError, ValueError):
        return f"{tag:34} no report"
    if r.get("crashed"):
        return f"{tag:34} {r.get('status', 'crashed').upper()} (exit {r.get('exit_code')})"
    return (
        f"{tag:34} {r.get('avg_fps')} fps · 1% low {r.get('low_1pct_fps')}"
        f" · {r.get('avg_frame_ms')} ms · focused {r.get('focused')}"
    )


def _code(text: str) -> str:
    return f"`{text}`" if text else ""


# ---------------------------------------------------------------- CLI


def _opt(args: list[str], name: str, default: str) -> str:
    for a in args:
        if a.startswith(f"--{name}="):
            return a.split("=", 1)[1]
    return default


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, args = argv[0], argv[1:]
    try:
        if cmd == "plan":
            control, configs = parse_configs(Path(args[0]).read_text())
            only = [n for n in _opt(args, "only", "").split(",") if n]
            unknown = [n for n in only if n not in {c.name for c in configs}]
            if unknown:
                raise ConfigError(f"--only names not in the file: {', '.join(unknown)}")
            if only:
                configs = [c for c in configs if c.name in only]
            scenes = tuple(s for s in _opt(args, "scenes", "battle").split(",") if s)
            bad = [s for s in scenes if s not in ("battle", "idle")]
            if bad or not scenes:
                raise ConfigError(f"scenes must be battle and/or idle, got {bad or 'none'}")
            runs = plan(
                control,
                configs,
                int(_opt(args, "repeats", "3")),
                int(_opt(args, "control-every", "4")),
                scenes,
            )
            for r in runs:
                c = r.config
                print(SEP.join([
                    str(r.seq), r.tag, c.name, r.role, r.scene, str(r.repeat),
                    " ".join(c.engine), " ".join(c.overrides), " ".join(c.game),
                ]))
        elif cmd == "override-cfg":
            sys.stdout.write(override_cfg(args))
        elif cmd == "brief":
            print(brief(Path(args[0]), args[1]))
        elif cmd == "estimate":
            caps = int(args[4]) if len(args) > 4 else 0
            minutes = estimate_minutes(
                int(args[0]), int(args[1]), float(args[2]), float(args[3]), caps
            )
            print(f"{minutes:.0f}")
        elif cmd == "summarise":
            matrix = Path(args[0])
            params = matrix / "params.txt"
            text = render_summary(
                load_results(matrix),
                f"Perf matrix {matrix.name}",
                params.read_text() if params.is_file() else "",
            )
            (matrix / "summary.md").write_text(text)
            sys.stdout.write(text)
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except ConfigError as e:
        print(f"perf_matrix: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
