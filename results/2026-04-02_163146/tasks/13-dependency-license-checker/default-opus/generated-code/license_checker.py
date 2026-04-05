"""
Dependency License Checker

Parses dependency manifests (package.json, requirements.txt), looks up each
dependency's license via a pluggable lookup function, checks it against
an allow/deny-list config, and produces a compliance report.

Built using red/green/refactor TDD — each section corresponds to a test cycle.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional


# ═══════════════════════════════════════════════════════════════════════
# Data types (Cycle 1 & 3)
# ═══════════════════════════════════════════════════════════════════════

@dataclass(frozen=True)
class DependencyInfo:
    """A single dependency extracted from a manifest file."""
    name: str
    version: str


# ═══════════════════════════════════════════════════════════════════════
# Cycle 3: License configuration with allow/deny classification
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class LicenseConfig:
    """
    Holds allow-list and deny-list of license identifiers.
    Classification is case-insensitive.
    """
    allowed: list[str] = field(default_factory=list)
    denied: list[str] = field(default_factory=list)

    def classify(self, license_id: str) -> str:
        """Classify a license as 'approved', 'denied', or 'unknown'."""
        lower = license_id.lower()
        if any(a.lower() == lower for a in self.allowed):
            return "approved"
        if any(d.lower() == lower for d in self.denied):
            return "denied"
        return "unknown"

    @classmethod
    def from_dict(cls, data: dict) -> LicenseConfig:
        """Create a LicenseConfig from a plain dict (e.g. parsed from JSON)."""
        return cls(
            allowed=data.get("allowed", []),
            denied=data.get("denied", []),
        )


# ═══════════════════════════════════════════════════════════════════════
# Cycle 5: Compliance report
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class ComplianceReport:
    """
    The final output: a list of dependency check results plus summary stats.
    is_compliant is True only when every dependency is 'approved'.
    """
    dependencies: list[dict] = field(default_factory=list)
    summary: dict = field(default_factory=dict)

    @property
    def is_compliant(self) -> bool:
        """Compliant only if there are zero denied or unknown licenses."""
        return (
            self.summary.get("denied", 0) == 0
            and self.summary.get("unknown", 0) == 0
        )

    def to_dict(self) -> dict:
        """Serialize the report to a plain dict."""
        return {
            "dependencies": self.dependencies,
            "summary": self.summary,
            "is_compliant": self.is_compliant,
        }

    def to_json(self, indent: int = 2) -> str:
        """Serialize the report to a JSON string."""
        return json.dumps(self.to_dict(), indent=indent)


# ═══════════════════════════════════════════════════════════════════════
# Cycle 1 & 2: Manifest parsing (package.json + requirements.txt)
# ═══════════════════════════════════════════════════════════════════════

# Regex to split a requirements.txt line into name and version specifier.
# Matches package names followed by optional version operators (==, >=, <=, ~=, !=, <, >).
_REQ_SPLIT = re.compile(r"^([A-Za-z0-9_][A-Za-z0-9._-]*)(.*)")


def parse_manifest(file_path: str) -> list[DependencyInfo]:
    """
    Parse a dependency manifest and return a list of DependencyInfo.

    Supported formats (detected by file extension):
      - package.json  (npm/Node.js)
      - requirements.txt  (pip/Python)

    Raises:
      FileNotFoundError: if the file does not exist
      ValueError: if the file content cannot be parsed
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Manifest file not found: {file_path}")

    content = path.read_text(encoding="utf-8")

    if file_path.endswith("requirements.txt"):
        return _parse_requirements_txt(content)
    else:
        # Default to package.json parsing (covers .json files)
        return _parse_package_json(content)


def _parse_package_json(content: str) -> list[DependencyInfo]:
    """Extract dependencies from a package.json string."""
    try:
        data = json.loads(content)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse package.json: {e}") from e

    deps: list[DependencyInfo] = []

    for section in ("dependencies", "devDependencies"):
        for name, version in data.get(section, {}).items():
            deps.append(DependencyInfo(name=name, version=version))

    return deps


def _parse_requirements_txt(content: str) -> list[DependencyInfo]:
    """Extract dependencies from a requirements.txt string."""
    deps: list[DependencyInfo] = []

    for raw_line in content.splitlines():
        line = raw_line.strip()

        # Skip empty lines, comments, and pip options (--index-url, -e, etc.)
        if not line or line.startswith("#") or line.startswith("-"):
            continue

        match = _REQ_SPLIT.match(line)
        if not match:
            continue

        name = match.group(1)
        version_spec = match.group(2).strip()

        deps.append(DependencyInfo(
            name=name,
            version=version_spec if version_spec else "*",
        ))

    return deps


# ═══════════════════════════════════════════════════════════════════════
# Cycle 4: Check a single dependency's license
# ═══════════════════════════════════════════════════════════════════════

# Type alias for the license lookup callable:
#   (package_name, version) -> license_identifier_or_None
LicenseLookup = Callable[[str, str], Optional[str]]


def check_license(
    dep: DependencyInfo,
    config: LicenseConfig,
    lookup: LicenseLookup,
) -> dict:
    """
    Look up a dependency's license and classify it.

    Returns a dict with keys: name, version, license, status, and optionally error.
    If the lookup function raises, the error is captured and status becomes 'unknown'.
    """
    result: dict = {
        "name": dep.name,
        "version": dep.version,
        "license": None,
        "status": "unknown",
    }

    try:
        license_id = lookup(dep.name, dep.version)
    except Exception as e:
        result["error"] = str(e)
        return result

    result["license"] = license_id

    if license_id is not None:
        result["status"] = config.classify(license_id)

    return result


# ═══════════════════════════════════════════════════════════════════════
# Cycle 5: Generate the full compliance report
# ═══════════════════════════════════════════════════════════════════════

def generate_report(
    manifest_path: str,
    config: LicenseConfig,
    lookup: LicenseLookup,
) -> ComplianceReport:
    """
    End-to-end: parse manifest → look up each license → build report.

    Args:
        manifest_path: path to package.json or requirements.txt
        config: LicenseConfig with allow/deny lists
        lookup: callable that resolves (name, version) → license string or None
    """
    deps = parse_manifest(manifest_path)
    results = [check_license(dep, config, lookup) for dep in deps]

    approved = sum(1 for r in results if r["status"] == "approved")
    denied = sum(1 for r in results if r["status"] == "denied")
    unknown = sum(1 for r in results if r["status"] == "unknown")

    return ComplianceReport(
        dependencies=results,
        summary={
            "total": len(results),
            "approved": approved,
            "denied": denied,
            "unknown": unknown,
        },
    )


# ═══════════════════════════════════════════════════════════════════════
# Cycle 6: Mock license lookup (built-in, for testing and demos)
# ═══════════════════════════════════════════════════════════════════════

# A realistic mapping of well-known packages to their SPDX license identifiers.
_MOCK_LICENSE_DB: dict[str, str] = {
    # npm / Node.js ecosystem
    "express": "MIT",
    "lodash": "MIT",
    "react": "MIT",
    "react-dom": "MIT",
    "next": "MIT",
    "typescript": "Apache-2.0",
    "webpack": "MIT",
    "jest": "MIT",
    "axios": "MIT",
    "moment": "MIT",
    "chalk": "MIT",
    "debug": "MIT",
    "uuid": "MIT",
    "commander": "MIT",
    "yargs": "MIT",
    "eslint": "MIT",
    "prettier": "MIT",
    # Python ecosystem
    "requests": "Apache-2.0",
    "flask": "BSD-3-Clause",
    "django": "BSD-3-Clause",
    "numpy": "BSD-3-Clause",
    "pandas": "BSD-3-Clause",
    "scipy": "BSD-3-Clause",
    "fastapi": "MIT",
    "sqlalchemy": "MIT",
    "pytest": "MIT",
    "black": "MIT",
    "mypy": "MIT",
    "celery": "BSD-3-Clause",
    "pillow": "MIT-CMU",
    # GPL examples (commonly denied in corporate settings)
    "readline": "GPL-3.0",
    "ghostscript": "AGPL-3.0",
    "mysql-connector-python": "GPL-2.0",
}


def mock_license_lookup(name: str, version: str) -> Optional[str]:
    """
    A built-in mock that returns realistic license data for well-known packages.
    Returns None for unknown packages (simulating a registry miss).
    """
    return _MOCK_LICENSE_DB.get(name)


# ═══════════════════════════════════════════════════════════════════════
# Cycle 7: Config file loading
# ═══════════════════════════════════════════════════════════════════════

def load_config(config_path: str) -> LicenseConfig:
    """
    Load a LicenseConfig from a JSON file.

    Expected format:
        {
            "allowed": ["MIT", "Apache-2.0", ...],
            "denied": ["GPL-3.0", ...]
        }

    Raises:
        FileNotFoundError: if the config file doesn't exist
        ValueError: if the config file isn't valid JSON
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse config file: {e}") from e

    return LicenseConfig.from_dict(data)


# ═══════════════════════════════════════════════════════════════════════
# CLI entry point (optional, for standalone use)
# ═══════════════════════════════════════════════════════════════════════

def main() -> None:
    """Command-line interface for the license checker."""
    import sys

    if len(sys.argv) < 3:
        print("Usage: python license_checker.py <manifest> <config.json>")
        print("  manifest:    path to package.json or requirements.txt")
        print("  config.json: path to license config (allowed/denied lists)")
        sys.exit(1)

    manifest_path = sys.argv[1]
    config_path = sys.argv[2]

    try:
        config = load_config(config_path)
        report = generate_report(manifest_path, config, mock_license_lookup)
        print(report.to_json())
        sys.exit(0 if report.is_compliant else 1)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
