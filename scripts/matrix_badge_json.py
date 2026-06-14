#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
"""Build a shields.io endpoint JSON document for one CI matrix shard badge."""
import json
import sys

GITHUB_PASSING_GREEN = '#28a745'
GITHUB_FAILING_RED = '#d73a49'

NAMED_LOGO_BY_OS = {
    'ubuntu': 'ubuntu',
    'macos': 'apple',
}

WINDOWS_LOGO_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="white" d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/></svg>'


def logo_fields_for_os(os_name):
    if os_name == 'windows':
        return {'logoSvg': WINDOWS_LOGO_SVG}
    return {'namedLogo': NAMED_LOGO_BY_OS.get(os_name, os_name), 'logoColor': 'white'}


def badge_json(os_name, arch, passed):
    return json.dumps(
        {
            'schemaVersion': 1,
            'label': arch,
            'message': 'passing' if passed else 'failing',
            'color': GITHUB_PASSING_GREEN if passed else GITHUB_FAILING_RED,
            **logo_fields_for_os(os_name),
        }
    )


def parse_passed(token):
    return token.strip().lower() in ('true', 'success', 'passing', '1')


def main(argv):
    if len(argv) != 4:
        print('error: usage: matrix_badge_json.py <os> <arch> <passed:true|false>', file=sys.stderr)
        return 2
    print(badge_json(argv[1], argv[2], parse_passed(argv[3])))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
