#!/usr/bin/env python3
"""Unit tests for tools/perf_matrix.py (run by tools/check.sh)."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).parent))
import perf_matrix as pm  # noqa: E402


def names(runs):
    return [r.config.name for r in runs]


class ParseConfigs(unittest.TestCase):
    def test_columns_overrides_and_control(self):
        control, configs = pm.parse_configs(
            "# comment\n"
            "\n"
            "control |  | --pf-x=1\n"
            "a | --rendering-method mobile +rendering/driver/depth_prepass/enable=false | --y=2\n"
            "b |  | --pf-z=3   # trailing comment\n"
            "c\n"
        )
        self.assertEqual(control.game, ["--pf-x=1"])
        self.assertEqual([c.name for c in configs], ["a", "b", "c"])
        a = configs[0]
        self.assertEqual(a.engine, ["--rendering-method", "mobile"])
        self.assertEqual(a.overrides, ["+rendering/driver/depth_prepass/enable=false"])
        self.assertEqual(a.game, ["--y=2"])
        self.assertEqual(configs[1].game, ["--pf-z=3"])
        self.assertEqual(configs[2].engine + configs[2].game, [])

    def test_errors(self):
        bad = {
            "dup": "a||\na||\n",
            "name": "a b||\n",
            "columns": "a|||\n",
            "override": "a|+nosection=1|\n",
            "separator": "a|--|\n",
            "engine arg in game column": "a||--rendering-method mobile\n",
        }
        for why, text in bad.items():
            with self.subTest(why), self.assertRaises(pm.ConfigError):
                pm.parse_configs(text)


class Plan(unittest.TestCase):
    def setUp(self):
        self.control, self.configs = pm.parse_configs("a||\nb||\nc||\nd||\ne||\n")

    def test_controls_interleaved_and_serpentine(self):
        runs = pm.plan(self.control, self.configs, repeats=2, control_every=2)
        self.assertEqual(
            names(runs),
            ["control", "a", "b", "control", "c", "d", "control", "e", "control",
             "e", "d", "control", "c", "b", "control", "a", "control"],
        )
        self.assertEqual([r.seq for r in runs], list(range(1, len(runs) + 1)))
        self.assertEqual({r.role for r in runs if r.config.name == "control"}, {"control"})
        self.assertEqual([r.repeat for r in runs if r.config.name == "a"], [1, 2])

    def test_no_double_control_when_list_divides(self):
        runs = pm.plan(self.control, self.configs[:4], repeats=1, control_every=2)
        self.assertEqual(names(runs), ["control", "a", "b", "control", "c", "d", "control"])

    def test_scenes_run_back_to_back(self):
        runs = pm.plan(self.control, self.configs[:1], repeats=1, scenes=("battle", "idle"))
        self.assertEqual(
            [(r.config.name, r.scene) for r in runs],
            [("control", "battle"), ("control", "idle"), ("a", "battle"), ("a", "idle"),
             ("control", "battle"), ("control", "idle")],
        )
        self.assertEqual(runs[2].tag, "003-a-battle")


class OverrideCfg(unittest.TestCase):
    def test_groups_by_section_with_marker(self):
        text = pm.override_cfg([
            "+rendering/driver/depth_prepass/enable=false",
            "+display/window/vsync/vsync_mode=0",
            "+rendering/rendering_device/vsync/frame_queue_size=3",
        ])
        self.assertTrue(text.startswith(pm.OVERRIDE_MARKER))
        self.assertIn(
            "[rendering]\ndriver/depth_prepass/enable=false\n"
            "rendering_device/vsync/frame_queue_size=3\n",
            text,
        )
        self.assertIn("[display]\nwindow/vsync/vsync_mode=0\n", text)


class Summary(unittest.TestCase):
    def _matrix(self, rows):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        d = Path(tmp.name)
        (d / "runs").mkdir()
        lines = ["\t".join(pm.RUNS_HEADER)]
        for seq, name, role, status, report in rows:
            tag = f"{seq:03d}-{name}-battle"
            (d / "runs" / f"{tag}.json").write_text(json.dumps(report))
            (d / "runs" / f"{tag}.log").write_text("")
            lines.append("\t".join([
                str(seq), tag, name, role, "battle", "1", status, "0",
                f"runs/{tag}.json", f"runs/{tag}.log", "", "", "", "", "--pf-x=1",
            ]))
        (d / "runs.tsv").write_text("\n".join(lines) + "\n")
        return d

    @staticmethod
    def report(ms, focused=True, prims=1.37e6):
        return {
            "avg_frame_ms": ms, "avg_fps": round(1000 / ms, 1), "low_1pct_fps": 50.0,
            "focused": focused, "max_draw_calls": 2313, "max_primitives": prims,
            "video_mem_mb": 955,
        }

    def test_delta_against_nearest_controls(self):
        d = self._matrix([
            (1, "control", "control", "ok", self.report(20.0)),
            (2, "x", "test", "ok", self.report(18.0)),
            (3, "control", "control", "ok", self.report(22.0)),
            (4, "x", "test", "ok", self.report(17.0)),
            (5, "control", "control", "ok", self.report(20.0)),
            (6, "x", "test", "ok", self.report(5.0, focused=False)),
            (7, "y", "test", "crashed", {"crashed": True, "status": "crashed"}),
            (8, "control", "control", "ok", self.report(30.0, focused=False)),
        ])
        rows = {r["name"]: r for r in pm.summary_rows(pm.load_results(d))}
        # x: 18 - mean(20, 22) = -3; 17 - mean(22, 20) = -4; unfocused run ignored.
        self.assertAlmostEqual(rows["x"]["delta"], -3.5)
        self.assertEqual(rows["x"]["focused"], "2/3")
        self.assertAlmostEqual(rows["x"]["ms"], 17.5)
        self.assertEqual(rows["control"]["delta"], None)
        self.assertAlmostEqual(rows["control"]["ms"], 20.0)
        self.assertEqual(rows["y"]["runs"], "0/1")
        self.assertIn("crashed ×1", rows["y"]["notes"])
        text = pm.render_summary(pm.load_results(d), "t")
        self.assertIn("| x | battle | 3/3 | 2/3 |", text)
        self.assertIn("−3.50", text)
        self.assertIn("## Failed runs", text)

    def test_missing_report_counts_as_no_json(self):
        d = self._matrix([(1, "control", "control", "ok", self.report(20.0))])
        (d / "runs" / "001-control-battle.json").unlink()
        results = pm.load_results(d)
        self.assertEqual(results[0].status, "no-json")

    def test_log_notes(self):
        d = self._matrix([(1, "control", "control", "ok", self.report(20.0))])
        (d / "runs" / "001-control-battle.log").write_text(
            "WARNING: MetalFX temporal upscaling scale is outside limits. Falling back to FSR 2\n"
        )
        self.assertEqual(pm.load_results(d)[0].notes, ["renderer fallback"])


class Misc(unittest.TestCase):
    def test_estimate(self):
        # 2 battle runs of 20 s + 22 s overhead, one 60 s rest.
        self.assertAlmostEqual(pm.estimate_minutes(2, 0, 20, 60), (2 * 42 + 60) / 60)

    def test_fmt(self):
        self.assertEqual(pm._fmt(-1.234, 2, signed=True), "−1.23")
        self.assertEqual(pm._fmt(2313, 0), "2,313")
        self.assertEqual(pm._fmt(None), "—")


if __name__ == "__main__":
    unittest.main(verbosity=1)
