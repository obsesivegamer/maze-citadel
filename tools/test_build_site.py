#!/usr/bin/env python3
"""Unit tests for tools/build_site.py (run by tools/check.sh)."""

import re
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).parent))
import build_site as bs  # noqa: E402


class Roster(unittest.TestCase):
    def test_cards_show_their_build_keys(self):
        data = bs.game_data()
        keys = re.findall(r'<span class="card-key">([^<]*)</span>', bs.roster_html(data))
        regular = [str((n + 1) % 10) for n in range(len(data["order"]))]
        self.assertEqual(keys, regular + ["G"] * len(data["epics"]))


class Power(unittest.TestCase):
    def test_cards_scale_damage_as_eletd_rules_do(self):
        data = bs.game_data()
        rules = bs.default_rules()
        want = {("archer", 2): 0.85, ("ballista", 1): 1.4, ("plague", 1): 1.0, ("runesmith", 3): 2.8}
        for (tid, level), power in want.items():
            got = bs.tower_power(tid, data["towers"][tid], level, rules, data["epics"])
            self.assertAlmostEqual(got, power, msg=tid)


if __name__ == "__main__":
    unittest.main()
