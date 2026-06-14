#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
"""Aggregate per-shard CI result markers into a matrix-status JSON array."""
import json
import os
import sys

PASSING_STATUS = 'success'


def split_os_arch(name):
    os_name, separator, arch = name.partition('-')
    return os_name, arch if separator else ''


def read_marker(path):
    with open(path) as handle:
        text = handle.read().strip()
    name, _, status = text.partition(' ')
    return name, status


def aggregate(directory):
    shards = []
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        if not os.path.isfile(path):
            continue
        name, status = read_marker(path)
        os_name, arch = split_os_arch(name)
        shards.append(
            {
                'name': name,
                'os': os_name,
                'arch': arch,
                'passed': status == PASSING_STATUS,
            }
        )
    return json.dumps(shards)


def main(argv):
    if len(argv) != 2:
        print('error: usage: aggregate_matrix_status.py <results-dir>', file=sys.stderr)
        return 2
    print(aggregate(argv[1]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
