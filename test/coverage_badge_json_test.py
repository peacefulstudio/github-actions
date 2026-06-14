#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import importlib.util
import json
import os
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'coverage_badge_json.py')
spec = importlib.util.spec_from_file_location('coverage_badge_json', SCRIPT_PATH)
badge_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(badge_module)


class TestCoverageBadgeColor(unittest.TestCase):

    def test_at_or_above_ninety_matches_github_passing_green(self):
        self.assertEqual(badge_module.color_for(90), badge_module.GITHUB_PASSING_GREEN)
        self.assertEqual(badge_module.color_for(100), badge_module.GITHUB_PASSING_GREEN)

    def test_eighty_to_eighty_nine_is_green(self):
        self.assertEqual(badge_module.color_for(80), 'green')
        self.assertEqual(badge_module.color_for(89), 'green')

    def test_seventy_to_seventy_nine_is_yellowgreen(self):
        self.assertEqual(badge_module.color_for(70), 'yellowgreen')
        self.assertEqual(badge_module.color_for(79), 'yellowgreen')

    def test_sixty_to_sixty_nine_is_yellow(self):
        self.assertEqual(badge_module.color_for(60), 'yellow')
        self.assertEqual(badge_module.color_for(69), 'yellow')

    def test_fifty_to_fifty_nine_is_orange(self):
        self.assertEqual(badge_module.color_for(50), 'orange')
        self.assertEqual(badge_module.color_for(59), 'orange')

    def test_below_fifty_is_red(self):
        self.assertEqual(badge_module.color_for(49), 'red')
        self.assertEqual(badge_module.color_for(0), 'red')


class TestCoverageBadgeJson(unittest.TestCase):

    def test_json_shape_for_high_coverage(self):
        document = json.loads(badge_module.badge_json(85, 'coverage'))
        self.assertEqual(
            document,
            {
                'schemaVersion': 1,
                'label': 'coverage',
                'message': '85%',
                'color': 'green',
            },
        )

    def test_label_is_passed_through(self):
        document = json.loads(badge_module.badge_json(92, 'C# coverage'))
        self.assertEqual(document['label'], 'C# coverage')
        self.assertEqual(document['message'], '92%')
        self.assertEqual(document['color'], badge_module.GITHUB_PASSING_GREEN)


if __name__ == '__main__':
    unittest.main()
