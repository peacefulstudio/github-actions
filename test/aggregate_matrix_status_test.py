# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import aggregate_matrix_status


class AggregateMatrixStatusTest(unittest.TestCase):
    def _write(self, directory, name, status):
        with open(os.path.join(directory, f'{name}.txt'), 'w') as handle:
            handle.write(f'{name} {status}\n')

    def test_parses_os_arch_and_pass_fail_sorted_by_name(self):
        with tempfile.TemporaryDirectory() as directory:
            self._write(directory, 'windows-amd64', 'failure')
            self._write(directory, 'ubuntu-amd64', 'success')
            result = json.loads(aggregate_matrix_status.aggregate(directory))
            self.assertEqual(
                result,
                [
                    {'name': 'ubuntu-amd64', 'os': 'ubuntu', 'arch': 'amd64', 'passed': True},
                    {'name': 'windows-amd64', 'os': 'windows', 'arch': 'amd64', 'passed': False},
                ],
            )

    def test_arch_with_hyphen_keeps_remainder(self):
        with tempfile.TemporaryDirectory() as directory:
            self._write(directory, 'ubuntu-24.04-arm', 'success')
            result = json.loads(aggregate_matrix_status.aggregate(directory))
            self.assertEqual(result[0]['os'], 'ubuntu')
            self.assertEqual(result[0]['arch'], '24.04-arm')

    def test_empty_directory_yields_empty_array(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(aggregate_matrix_status.aggregate(directory), '[]')


if __name__ == '__main__':
    unittest.main()
