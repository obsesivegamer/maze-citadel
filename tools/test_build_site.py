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


if __name__ == "__main__":
    unittest.main()
