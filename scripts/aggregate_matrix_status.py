#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
"""Aggregate per-shard CI result markers into a matrix-status JSON array."""
import json
import os
import sys

PASSING_STATUS = 'success'
FAILING_STATUS = 'failure'
KNOWN_STATUSES = (PASSING_STATUS, FAILING_STATUS)


def split_os_arch(name):
    os_name, separator, arch = name.partition('-')
    return os_name, arch if separator else ''


def read_marker(path):
    with open(path) as handle:
        text = handle.read().strip()
    name, _, status = text.partition(' ')
    if not name or not status:
        raise ValueError(f'malformed matrix marker: {path}')
    if status not in KNOWN_STATUSES:
        raise ValueError(f'unknown matrix status in {path}: {status}')
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
