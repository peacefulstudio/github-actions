#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

PACKAGE_ID = 'Microsoft.Testing.Extensions.CodeCoverage'
PROPS_FILENAME = 'Directory.Packages.props'


class VersionResolutionError(Exception):
    pass


def _pinned_versions(props_file: Path) -> list[str]:
    try:
        tree = ElementTree.parse(props_file)
    except ElementTree.ParseError:
        print(
            f'::warning::resolve-dotnet-coverage-version: skipping unparseable XML file {props_file}',
            file=sys.stderr,
        )
        return []
    return [
        element.attrib['Version']
        for element in tree.iter('PackageVersion')
        if (element.get('Include') or element.get('Update')) == PACKAGE_ID
        and 'Version' in element.attrib
    ]


def collect_pins(root_dir: str) -> list[tuple[Path, str]]:
    return [
        (props_file, version)
        for props_file in sorted(Path(root_dir).rglob(PROPS_FILENAME))
        for version in _pinned_versions(props_file)
    ]


def resolve_version(root_dir: str) -> str:
    pins = collect_pins(root_dir)
    if not pins:
        raise VersionResolutionError(
            f"no {PACKAGE_ID} pin found in any {PROPS_FILENAME} under '{root_dir}' — "
            f'pin it in {PROPS_FILENAME}; it is required for MTP to emit cobertura files at all'
        )
    property_pins = [(path, version) for path, version in pins if '$(' in version]
    if property_pins:
        listing = ', '.join(f'{path}: {version}' for path, version in property_pins)
        raise VersionResolutionError(
            f'{PACKAGE_ID} version must be a literal, not an MSBuild property: {listing}'
        )
    if len({version for _, version in pins}) > 1:
        listing = ', '.join(f'{path}: {version}' for path, version in pins)
        raise VersionResolutionError(f'conflicting {PACKAGE_ID} versions: {listing}')
    return pins[0][1]


if __name__ == '__main__':
    try:
        print(resolve_version(sys.argv[1]))
    except VersionResolutionError as error:
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
