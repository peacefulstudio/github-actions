# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import matrix_badge_json


class MatrixBadgeJsonTest(unittest.TestCase):
    def test_passing_ubuntu_uses_green_and_ubuntu_logo(self):
        result = json.loads(matrix_badge_json.badge_json('ubuntu', 'arm64', True))
        self.assertEqual(result['schemaVersion'], 1)
        self.assertEqual(result['label'], 'arm64')
        self.assertEqual(result['message'], 'passing')
        self.assertEqual(result['color'], '#28a745')
        self.assertEqual(result['namedLogo'], 'ubuntu')
        self.assertEqual(result['logoColor'], 'white')

    def test_failing_uses_red(self):
        result = json.loads(matrix_badge_json.badge_json('windows', 'amd64', False))
        self.assertEqual(result['message'], 'failing')
        self.assertEqual(result['color'], '#d73a49')

    def test_windows_uses_custom_logo_svg_not_named_logo(self):
        result = json.loads(matrix_badge_json.badge_json('windows', 'amd64', True))
        self.assertIn('logoSvg', result)
        self.assertIn('<svg', result['logoSvg'])
        self.assertNotIn('namedLogo', result)

    def test_macos_maps_to_apple_logo(self):
        result = json.loads(matrix_badge_json.badge_json('macos', 'arm64', True))
        self.assertEqual(result['namedLogo'], 'apple')

    def test_unknown_os_falls_back_to_os_name_as_logo(self):
        result = json.loads(matrix_badge_json.badge_json('freebsd', 'amd64', True))
        self.assertEqual(result['namedLogo'], 'freebsd')


if __name__ == '__main__':
    unittest.main()
