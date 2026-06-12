#!/usr/bin/env python3
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

SCRIPT_PATH = os.path.join(
    os.path.dirname(__file__), '..', 'scripts', 'resolve-dotnet-coverage-version.py'
)
spec = importlib.util.spec_from_file_location('resolve_dotnet_coverage_version', SCRIPT_PATH)
resolve_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolve_module)


def write_props(root, relative_dir, content):
    directory = os.path.join(root, relative_dir)
    os.makedirs(directory, exist_ok=True)
    path = os.path.normpath(os.path.join(directory, 'Directory.Packages.props'))
    with open(path, 'w') as f:
        f.write(content)
    return path


def props_with_pin(version, attribute='Include'):
    return (
        '<Project>\n'
        '  <ItemGroup>\n'
        '    <PackageVersion Include="xunit.v3" Version="3.2.2" />\n'
        f'    <PackageVersion {attribute}="Microsoft.Testing.Extensions.CodeCoverage" Version="{version}" />\n'
        '  </ItemGroup>\n'
        '</Project>\n'
    )


PROPS_WITHOUT_PIN = (
    '<Project>\n'
    '  <ItemGroup>\n'
    '    <PackageVersion Include="xunit.v3" Version="3.2.2" />\n'
    '  </ItemGroup>\n'
    '</Project>\n'
)


class TestResolveDotnetCoverageVersion(unittest.TestCase):

    def test_single_pin_in_nested_directory_resolves(self):
        with tempfile.TemporaryDirectory() as root:
            write_props(root, 'tests', props_with_pin('18.8.0'))
            self.assertEqual(resolve_module.resolve_version(root), '18.8.0')

    def test_no_pin_anywhere_raises(self):
        with tempfile.TemporaryDirectory() as root:
            write_props(root, '.', PROPS_WITHOUT_PIN)
            with self.assertRaises(resolve_module.VersionResolutionError) as ctx:
                resolve_module.resolve_version(root)
            self.assertIn('Microsoft.Testing.Extensions.CodeCoverage', str(ctx.exception))
            self.assertIn('Directory.Packages.props', str(ctx.exception))

    def test_conflicting_versions_raise_listing_both_files(self):
        with tempfile.TemporaryDirectory() as root:
            first = write_props(root, '.', props_with_pin('18.0.6'))
            second = write_props(root, 'tests', props_with_pin('18.8.0'))
            with self.assertRaises(resolve_module.VersionResolutionError) as ctx:
                resolve_module.resolve_version(root)
            self.assertIn(first, str(ctx.exception))
            self.assertIn(second, str(ctx.exception))
            self.assertIn('18.0.6', str(ctx.exception))
            self.assertIn('18.8.0', str(ctx.exception))

    def test_identical_pins_in_two_files_resolve(self):
        with tempfile.TemporaryDirectory() as root:
            write_props(root, '.', props_with_pin('18.8.0'))
            write_props(root, 'tests', props_with_pin('18.8.0'))
            self.assertEqual(resolve_module.resolve_version(root), '18.8.0')

    def test_update_attribute_resolves(self):
        with tempfile.TemporaryDirectory() as root:
            write_props(root, '.', props_with_pin('19.0.0', attribute='Update'))
            self.assertEqual(resolve_module.resolve_version(root), '19.0.0')

    def test_msbuild_property_version_raises(self):
        with tempfile.TemporaryDirectory() as root:
            write_props(root, '.', props_with_pin('$(CodeCoverageVersion)'))
            with self.assertRaises(resolve_module.VersionResolutionError) as ctx:
                resolve_module.resolve_version(root)
            self.assertIn('literal', str(ctx.exception))

    def test_malformed_xml_is_skipped_with_warning(self):
        with tempfile.TemporaryDirectory() as root:
            malformed = write_props(root, 'broken', '<Project><unclosed\n')
            write_props(root, 'tests', props_with_pin('18.8.0'))
            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                version = resolve_module.resolve_version(root)
            self.assertEqual(version, '18.8.0')
            self.assertIn('::warning::', stderr.getvalue())
            self.assertIn(malformed, stderr.getvalue())


if __name__ == '__main__':
    unittest.main()
