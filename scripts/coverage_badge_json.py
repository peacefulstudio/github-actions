#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
"""Build a shields.io endpoint JSON document for a coverage badge."""
import json
import sys

GITHUB_PASSING_GREEN = '#28a745'

COLOR_THRESHOLDS = (
    (90, GITHUB_PASSING_GREEN),
    (80, 'green'),
    (70, 'yellowgreen'),
    (60, 'yellow'),
    (50, 'orange'),
)


def color_for(coverage):
    for threshold, color in COLOR_THRESHOLDS:
        if coverage >= threshold:
            return color
    return 'red'


def badge_json(coverage, label):
    return json.dumps(
        {
            'schemaVersion': 1,
            'label': label,
            'message': f'{coverage}%',
            'color': color_for(coverage),
        }
    )


def main(argv):
    if len(argv) != 3:
        print('error: usage: coverage_badge_json.py <coverage-integer> <label>', file=sys.stderr)
        return 2
    try:
        coverage = int(argv[1])
    except ValueError:
        print(f"error: coverage '{argv[1]}' is not an integer", file=sys.stderr)
        return 1
    print(badge_json(coverage, argv[2]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
