"""Environment matrix generator for GitHub Actions strategy.matrix.

Generates build matrices with support for include/exclude rules, max-parallel
limits, fail-fast configuration, and size validation.
"""
import json
from dataclasses import dataclass, field
from typing import Any, Optional


class MatrixValidationError(Exception):
    """Raised when matrix validation fails."""

    pass


@dataclass
class MatrixConfig:
    """Configuration for matrix generation.

    Attributes:
        os_versions: List of OS versions (e.g., ["ubuntu-latest", "macos-latest"])
        language_versions: List of language versions (e.g., ["3.9", "3.10"])
        feature_flags: Optional list of feature flags (default: [])
        include: Optional list of specific combinations to include
        exclude: Optional list of combinations to exclude
        max_parallel: Maximum parallel jobs (None for no limit)
        fail_fast: Whether to fail fast on first failure (default: True)
        max_size: Maximum matrix size before validation error (default: 256)
    """

    os_versions: list[str]
    language_versions: list[str]
    feature_flags: list[str] = field(default_factory=list)
    include: list[dict[str, Any]] = field(default_factory=list)
    exclude: list[dict[str, Any]] = field(default_factory=list)
    max_parallel: Optional[int] = None
    fail_fast: bool = True
    max_size: int = 256


class MatrixGenerator:
    """Generates GitHub Actions build matrix from configuration."""

    def __init__(self, config: MatrixConfig) -> None:
        """Initialize generator with configuration."""
        self.config = config

    def generate(self) -> dict[str, Any]:
        """Generate and return the complete matrix.

        Returns:
            Dictionary with include, exclude, fail-fast, and optional max-parallel keys.

        Raises:
            MatrixValidationError: If configuration is invalid or matrix exceeds max size.
        """
        self._validate_config()

        # Use include list if provided, otherwise generate from combinations
        if self.config.include:
            include_list = self.config.include.copy()
        else:
            include_list = self._generate_combinations()

        # Apply excludes
        if self.config.exclude:
            include_list = self._apply_excludes(include_list)

        # Build the final matrix structure
        matrix: dict[str, Any] = {
            "include": include_list,
            "fail-fast": self.config.fail_fast,
        }

        # Add max-parallel if specified
        if self.config.max_parallel is not None:
            matrix["max-parallel"] = self.config.max_parallel

        # Add exclude list if specified
        if self.config.exclude:
            matrix["exclude"] = self.config.exclude

        return matrix

    def to_json(self) -> str:
        """Return matrix as JSON string.

        Returns:
            JSON representation of the matrix.
        """
        return json.dumps(self.generate(), indent=2)

    def _validate_config(self) -> None:
        """Validate configuration.

        Raises:
            MatrixValidationError: If configuration is invalid.
        """
        if not self.config.os_versions:
            raise MatrixValidationError("os_versions cannot be empty")
        if not self.config.language_versions:
            raise MatrixValidationError("language_versions cannot be empty")

        # Check if potential matrix size exceeds limit before generating
        flags_count = len(self.config.feature_flags) if self.config.feature_flags else 1
        potential_size = len(self.config.os_versions) * len(
            self.config.language_versions
        ) * flags_count

        if potential_size > self.config.max_size:
            raise MatrixValidationError(
                f"Matrix size ({potential_size}) exceeds maximum size "
                f"({self.config.max_size})"
            )

    def _generate_combinations(self) -> list[dict[str, Any]]:
        """Generate cartesian product of OS, language versions, and feature flags.

        Returns:
            List of combination dictionaries.
        """
        combinations: list[dict[str, Any]] = []

        # Deduplicate OS versions
        unique_os = list(dict.fromkeys(self.config.os_versions))

        if self.config.feature_flags:
            # If feature flags exist, create combinations with each flag
            for os_ver in unique_os:
                for lang_ver in self.config.language_versions:
                    for flag in self.config.feature_flags:
                        combinations.append({
                            "os": os_ver,
                            "language_version": lang_ver,
                            "feature_flag": flag,
                        })
        else:
            # Otherwise just create OS x language combinations
            for os_ver in unique_os:
                for lang_ver in self.config.language_versions:
                    combinations.append({
                        "os": os_ver,
                        "language_version": lang_ver,
                    })

        return combinations

    def _apply_excludes(self, combinations: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Filter out excluded combinations.

        Args:
            combinations: List of combinations to filter.

        Returns:
            Filtered list without excluded combinations.
        """
        result = []
        for combo in combinations:
            if not self._is_excluded(combo):
                result.append(combo)
        return result

    def _is_excluded(self, combo: dict[str, Any]) -> bool:
        """Check if a combination is excluded.

        Args:
            combo: Combination dictionary to check.

        Returns:
            True if the combination matches any exclude rule.
        """
        for exclude_rule in self.config.exclude:
            if self._matches_rule(combo, exclude_rule):
                return True
        return False

    def _matches_rule(self, combo: dict[str, Any], rule: dict[str, Any]) -> bool:
        """Check if a combination matches an exclude/include rule.

        Args:
            combo: Combination dictionary.
            rule: Rule dictionary (partial match).

        Returns:
            True if all keys in rule match corresponding values in combo.
        """
        for key, value in rule.items():
            if combo.get(key) != value:
                return False
        return True
