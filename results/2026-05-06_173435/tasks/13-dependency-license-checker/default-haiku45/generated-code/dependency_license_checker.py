#!/usr/bin/env python3
"""
Dependency License Checker - validates project dependencies against license allow/deny lists.

Parses dependency manifests (package.json, requirements.txt, Pipfile), extracts dependency
names and versions, checks them against configured license policies, and generates compliance
reports.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass


@dataclass
class Dependency:
    """Represents a project dependency."""
    name: str
    version: str


@dataclass
class LicenseConfig:
    """Configuration for license validation."""
    allow_list: List[str]
    deny_list: List[str]


class LicenseLookup:
    """Mock license lookup service. In production, this would query a real service."""

    def __init__(self, license_map: Optional[Dict[str, str]] = None):
        """
        Initialize with optional license map for testing.

        Args:
            license_map: Dict mapping dependency names to their licenses
        """
        self.license_map = license_map or {}

    def get_license(self, name: str, version: str) -> Optional[str]:
        """
        Look up the license for a dependency.

        Args:
            name: Dependency name
            version: Dependency version

        Returns:
            License name or None if not found
        """
        return self.license_map.get(name)


class ManifestParser:
    """Parses various dependency manifest formats."""

    @staticmethod
    def parse_package_json(file_path: Path) -> List[Dependency]:
        """
        Parse dependencies from package.json.

        Args:
            file_path: Path to package.json

        Returns:
            List of Dependency objects

        Raises:
            ValueError: If file is invalid JSON
        """
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in {file_path}: {e}")
        except FileNotFoundError:
            raise ValueError(f"File not found: {file_path}")

        dependencies = []

        # Parse dependencies
        for name, version in data.get('dependencies', {}).items():
            dependencies.append(Dependency(name=name, version=version))

        # Parse devDependencies
        for name, version in data.get('devDependencies', {}).items():
            dependencies.append(Dependency(name=name, version=version))

        return dependencies

    @staticmethod
    def parse_requirements_txt(file_path: Path) -> List[Dependency]:
        """
        Parse dependencies from requirements.txt.

        Args:
            file_path: Path to requirements.txt

        Returns:
            List of Dependency objects

        Raises:
            ValueError: If file format is invalid
        """
        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
        except FileNotFoundError:
            raise ValueError(f"File not found: {file_path}")

        dependencies = []

        for line in lines:
            line = line.strip()

            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue

            # Parse different version specifiers
            for separator in ['==', '>=', '<=', '~=', '!=']:
                if separator in line:
                    name, version = line.split(separator, 1)
                    dependencies.append(Dependency(
                        name=name.strip(),
                        version=version.strip()
                    ))
                    break
            else:
                # If no separator, assume it's just the name
                dependencies.append(Dependency(name=line, version='*'))

        return dependencies


class ComplianceChecker:
    """Checks dependencies against license policies."""

    def __init__(self, license_config: LicenseConfig, lookup: LicenseLookup):
        """
        Initialize the compliance checker.

        Args:
            license_config: LicenseConfig with allow and deny lists
            lookup: LicenseLookup service
        """
        self.config = license_config
        self.lookup = lookup

    def check_dependency(self, dependency: Dependency) -> Tuple[str, str]:
        """
        Check a dependency's license status.

        Args:
            dependency: Dependency to check

        Returns:
            Tuple of (status, license) where status is 'approved', 'denied', or 'unknown'
        """
        license_name = self.lookup.get_license(dependency.name, dependency.version)

        if license_name is None:
            return ('unknown', None)

        if license_name in self.config.deny_list:
            return ('denied', license_name)

        if license_name in self.config.allow_list:
            return ('approved', license_name)

        return ('unknown', license_name)

    def generate_report(self, dependencies: List[Dependency]) -> str:
        """
        Generate a compliance report for a list of dependencies.

        Args:
            dependencies: List of dependencies to check

        Returns:
            Formatted compliance report as string
        """
        results = {
            'approved': [],
            'denied': [],
            'unknown': []
        }

        for dep in dependencies:
            status, license_name = self.check_dependency(dep)
            results[status].append({
                'name': dep.name,
                'version': dep.version,
                'license': license_name
            })

        # Format report
        report_lines = [
            "Dependency License Compliance Report",
            "=" * 40,
            ""
        ]

        for category in ['approved', 'denied', 'unknown']:
            report_lines.append(f"{category.upper()} ({len(results[category])})")
            report_lines.append("-" * 40)

            if results[category]:
                for item in results[category]:
                    if item['license']:
                        report_lines.append(
                            f"  {item['name']} ({item['version']}) - {item['license']}"
                        )
                    else:
                        report_lines.append(f"  {item['name']} ({item['version']})")
            else:
                report_lines.append("  (none)")

            report_lines.append("")

        # Summary
        report_lines.append("SUMMARY")
        report_lines.append("-" * 40)
        report_lines.append(f"Total approved:  {len(results['approved'])}")
        report_lines.append(f"Total denied:    {len(results['denied'])}")
        report_lines.append(f"Total unknown:   {len(results['unknown'])}")

        return "\n".join(report_lines)


def main():
    """Main entry point for the CLI."""
    if len(sys.argv) < 2:
        print("Usage: dependency_license_checker.py <manifest_file>")
        sys.exit(1)

    manifest_file = Path(sys.argv[1])

    # Determine manifest type and parse
    if manifest_file.name == 'package.json':
        dependencies = ManifestParser.parse_package_json(manifest_file)
    elif manifest_file.name == 'requirements.txt':
        dependencies = ManifestParser.parse_requirements_txt(manifest_file)
    else:
        print(f"Unsupported manifest type: {manifest_file.name}")
        sys.exit(1)

    # Load license config (mock for now)
    config = LicenseConfig(
        allow_list=['MIT', 'Apache-2.0', 'ISC'],
        deny_list=['GPL-2.0', 'GPL-3.0']
    )

    # Create lookup service (empty for now - will be populated in tests)
    lookup = LicenseLookup()

    # Generate report
    checker = ComplianceChecker(config, lookup)
    report = checker.generate_report(dependencies)

    print(report)


if __name__ == '__main__':
    main()
