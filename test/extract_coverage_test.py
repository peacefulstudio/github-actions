#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'extract_coverage.py')


def run_extract(xml_path):
    return subprocess.run(
        [sys.executable, SCRIPT_PATH, xml_path],
        capture_output=True,
        text=True,
    )


def write_coverage_xml(line_rate=None):
    attribute = f' line-rate="{line_rate}"' if line_rate is not None else ''
    return f'<?xml version="1.0" ?>\n<coverage{attribute} version="1.9"></coverage>\n'


def write_temp(content):
    handle = tempfile.NamedTemporaryFile('w', suffix='.xml', delete=False)
    handle.write(content)
    handle.close()
    return handle.name


class TestExtractCoverage(unittest.TestCase):

    def test_normal_cobertura_reports_rounded_percent(self):
        path = write_temp(write_coverage_xml('0.8523'))
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '85')

    def test_rounds_half_up_at_boundary(self):
        path = write_temp(write_coverage_xml('0.855'))
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '86')

    def test_rounds_down_just_below_boundary(self):
        path = write_temp(write_coverage_xml('0.8549'))
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '85')

    def test_full_coverage_is_hundred(self):
        path = write_temp(write_coverage_xml('1.0'))
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '100')

    def test_zero_coverage_is_zero(self):
        path = write_temp(write_coverage_xml('0.0'))
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '0')

    def test_missing_file_exits_non_zero(self):
        result = run_extract(os.path.join(tempfile.gettempdir(), 'does-not-exist-coverage.xml'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('error:', result.stderr)

    def test_missing_line_rate_attribute_exits_non_zero(self):
        path = write_temp(write_coverage_xml(None))
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('error:', result.stderr)

    def test_unparseable_file_exits_non_zero(self):
        path = write_temp('<coverage line-rate="0.5"\n')
        self.addCleanup(os.unlink, path)
        result = run_extract(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('error:', result.stderr)


if __name__ == '__main__':
    unittest.main()
