#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
"""Print the integer line-coverage percentage from a merged cobertura XML file."""
import sys
import xml.etree.ElementTree as ElementTree
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation


def extract_percentage(cobertura_path):
    try:
        root = ElementTree.parse(cobertura_path).getroot()
    except FileNotFoundError as error:
        raise CoverageExtractionError(f"cobertura file not found: {cobertura_path}") from error
    except OSError as error:
        raise CoverageExtractionError(f"cannot read cobertura file '{cobertura_path}': {error}") from error
    except ElementTree.ParseError as error:
        raise CoverageExtractionError(f"cobertura file '{cobertura_path}' is not valid XML: {error}") from error

    line_rate = root.get('line-rate')
    if line_rate is None:
        raise CoverageExtractionError(
            f"cobertura root element in '{cobertura_path}' has no 'line-rate' attribute"
        )
    try:
        rate = Decimal(line_rate)
    except InvalidOperation as error:
        raise CoverageExtractionError(
            f"line-rate '{line_rate}' in '{cobertura_path}' is not a number"
        ) from error

    percent = (rate * 100).quantize(Decimal('1'), rounding=ROUND_HALF_UP)
    return int(percent)


class CoverageExtractionError(Exception):
    pass


def main(argv):
    if len(argv) != 2:
        print('error: usage: extract_coverage.py <merged-cobertura-xml>', file=sys.stderr)
        return 2
    try:
        print(extract_percentage(argv[1]))
    except CoverageExtractionError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
