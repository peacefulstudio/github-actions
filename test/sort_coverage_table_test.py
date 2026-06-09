#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '.github', 'actions', 'sort-coverage-table'))
from sort import sort_coverage_table

TABLE_HEADER = "| Name | Line Rate |\n| :-- | :-: |\n"


class TestSortCoverageTable(unittest.TestCase):

    def test_sorts_data_rows_alphabetically(self):
        text = TABLE_HEADER + "| Zoo | 80% |\n| Apple | 90% |\n| Mango | 70% |\n"
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[2], "| Apple | 90% |")
        self.assertEqual(lines[3], "| Mango | 70% |")
        self.assertEqual(lines[4], "| Zoo | 80% |")

    def test_sort_is_case_insensitive(self):
        text = TABLE_HEADER + "| zoo | 80% |\n| Apple | 90% |\n"
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[2], "| Apple | 90% |")
        self.assertEqual(lines[3], "| zoo | 80% |")

    def test_header_and_separator_are_preserved(self):
        text = TABLE_HEADER + "| Zoo | 80% |\n| Apple | 90% |\n"
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[0], "| Name | Line Rate |")
        self.assertEqual(lines[1], "| :-- | :-: |")

    def test_summary_row_stays_last(self):
        text = TABLE_HEADER + "| Zoo | 80% |\n| Apple | 90% |\n| **Summary** | 85% |\n"
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[2], "| Apple | 90% |")
        self.assertEqual(lines[3], "| Zoo | 80% |")
        self.assertEqual(lines[4], "| **Summary** | 85% |")

    def test_non_table_content_passes_through(self):
        text = "![badge](https://img.shields.io/badge/...)\n\n" + TABLE_HEADER + "| Zoo | 80% |\n| Apple | 90% |\n"
        result = sort_coverage_table(text)
        self.assertTrue(result.startswith("![badge](https://img.shields.io/badge/...)\n"))
        lines = result.splitlines()
        self.assertEqual(lines[4], "| Apple | 90% |")
        self.assertEqual(lines[5], "| Zoo | 80% |")

    def test_only_first_table_is_sorted(self):
        text = (
            TABLE_HEADER
            + "| Zoo | 80% |\n| Apple | 90% |\n"
            + "\n"
            + "| Complexity | Function |\n| ---------: | -------- |\n"
            + "| 5 | `apple_func` |\n| 15 | `zoo_func` |\n"
        )
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[2], "| Apple | 90% |")
        self.assertEqual(lines[3], "| Zoo | 80% |")
        self.assertEqual(lines[7], "| 5 | `apple_func` |")
        self.assertEqual(lines[8], "| 15 | `zoo_func` |")

    def test_single_data_row_is_unchanged(self):
        text = TABLE_HEADER + "| OnlyOne | 80% |\n"
        self.assertEqual(sort_coverage_table(text), text)

    def test_no_table_passes_through_unchanged(self):
        text = "Just some text\nNo table here\n"
        self.assertEqual(sort_coverage_table(text), text)

    def test_real_irongut_four_column_output(self):
        text = (
            "![Code Coverage](https://img.shields.io/badge/Code%20Coverage-83%25-yellow)\n"
            "\n"
            "| Name | Line Rate | Branch Rate | Health |\n"
            "| :-- | :-: | :-: | :-: |\n"
            "| com.example.zoo | 90% | N/A | ✔ |\n"
            "| com.example.apple | 70% | N/A | ✗ |\n"
            "| **Summary** | **83%** | **N/A** | |\n"
        )
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[4], "| com.example.apple | 70% | N/A | ✗ |")
        self.assertEqual(lines[5], "| com.example.zoo | 90% | N/A | ✔ |")
        self.assertEqual(lines[6], "| **Summary** | **83%** | **N/A** | |")

    def test_go_fixture_with_details_section_unsorted(self):
        text = (
            "![Code Coverage](https://img.shields.io/badge/Code%20Coverage-75%25-red)\n"
            "\n"
            "| Name | Line Rate | Branch Rate | Complexity | Health |\n"
            "| :-- | :-: | :-: | :-: | :-: |\n"
            "| github.com/example/zoo | 80% | N/A | 3.2 | ✔ |\n"
            "| github.com/example/apple | 70% | N/A | 2.1 | ✗ |\n"
            "| **Summary** | **75%** | **N/A** | **2.7** | |\n"
            "\n"
            "<details>\n"
            "<summary>Cyclomatic complexity — top 10 production functions (average 2.7)</summary>\n"
            "\n"
            "| Complexity | Function | Location | Attended |\n"
            "| ---------: | -------- | -------- | :------- |\n"
            "| 15 | `zoo_func` | `zoo/zoo.go:42` | ✓ 80.0% |\n"
            "| 5 | `apple_func` | `apple/apple.go:10` | ✗ 0.0% |\n"
            "\n"
            "</details>\n"
        )
        lines = sort_coverage_table(text).splitlines()
        self.assertEqual(lines[4], "| github.com/example/apple | 70% | N/A | 2.1 | ✗ |")
        self.assertEqual(lines[5], "| github.com/example/zoo | 80% | N/A | 3.2 | ✔ |")
        self.assertEqual(lines[6], "| **Summary** | **75%** | **N/A** | **2.7** | |")
        self.assertEqual(lines[13], "| 15 | `zoo_func` | `zoo/zoo.go:42` | ✓ 80.0% |")
        self.assertEqual(lines[14], "| 5 | `apple_func` | `apple/apple.go:10` | ✗ 0.0% |")


if __name__ == '__main__':
    unittest.main()
