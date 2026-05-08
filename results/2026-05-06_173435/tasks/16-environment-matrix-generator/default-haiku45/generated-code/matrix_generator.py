"""GitHub Actions build matrix generator with TDD approach."""
import itertools
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


class MatrixValidationError(Exception):
    """Raised when matrix configuration is invalid."""

    pass


@dataclass
class MatrixConfig:
    """Configuration for matrix generation."""

    os: List[str] = field(default_factory=list)
    python_version: List[str] = field(default_factory=list)
    node_version: List[str] = field(default_factory=list)
    max_parallel: Optional[int] = None
    fail_fast: bool = True
    max_size: int = 256
    include: List[Dict[str, Any]] = field(default_factory=list)
    exclude: List[Dict[str, Any]] = field(default_factory=list)


class MatrixGenerator:
    """Generate GitHub Actions build matrix from configuration."""

    def __init__(self, config: MatrixConfig):
        """Initialize generator with configuration."""
        self.config = config

    def generate(self) -> Dict[str, Any]:
        """Generate matrix JSON suitable for GitHub Actions strategy.matrix.

        Returns:
            Dictionary with 'include' key containing all matrix combinations.

        Raises:
            MatrixValidationError: If matrix exceeds max_size limit.
        """
        # Build base matrix from all combinations of provided dimensions
        base_matrix = self._build_base_matrix()

        # Apply exclude rules
        matrix_include = self._apply_exclude(base_matrix)

        # Apply include rules
        matrix_include.extend(self.config.include)

        # Validate size
        if len(matrix_include) > self.config.max_size:
            raise MatrixValidationError(
                f"Matrix size {len(matrix_include)} exceeds maximum {self.config.max_size}"
            )

        # Build result
        result: Dict[str, Any] = {"include": matrix_include}

        # Add optional fields
        if self.config.max_parallel:
            result["max-parallel"] = self.config.max_parallel

        if not self.config.fail_fast:
            result["fail-fast"] = False

        return result

    def _build_base_matrix(self) -> List[Dict[str, str]]:
        """Build all combinations from non-empty dimensions."""
        dimensions = {}

        if self.config.os:
            dimensions["os"] = self.config.os
        if self.config.python_version:
            dimensions["python_version"] = self.config.python_version
        if self.config.node_version:
            dimensions["node_version"] = self.config.node_version

        if not dimensions:
            return []

        # Generate all combinations
        keys = dimensions.keys()
        values = dimensions.values()
        combinations = itertools.product(*values)

        matrix = []
        for combo in combinations:
            entry = dict(zip(keys, combo))
            matrix.append(entry)

        return matrix

    def _apply_exclude(self, matrix: List[Dict[str, str]]) -> List[Dict[str, str]]:
        """Remove entries matching exclude rules."""
        result = []

        for entry in matrix:
            excluded = False
            for exclude_rule in self.config.exclude:
                # Check if entry matches all fields in exclude rule
                if all(entry.get(k) == v for k, v in exclude_rule.items()):
                    excluded = True
                    break
            if not excluded:
                result.append(entry)

        return result
