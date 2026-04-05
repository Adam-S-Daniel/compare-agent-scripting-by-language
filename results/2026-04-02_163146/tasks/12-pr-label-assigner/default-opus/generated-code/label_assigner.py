"""
PR Label Assigner — assigns labels to a PR based on changed file paths.

Given a list of changed file paths and configurable path-to-label mapping rules
(supporting glob patterns), this module determines which labels should be applied.

Features:
  - Glob pattern matching (**, *, ?, [abc])
  - Multiple labels per file
  - Priority ordering when rules conflict on the same file
  - Configurable rules via dict/JSON-like structures
  - Graceful error handling with meaningful messages

Approach:
  - Each Rule has a glob pattern, a label, and an optional priority (default 0).
  - For each file, we find all matching rules. If multiple rules match the same
    file, we group by the minimum (highest) priority and only keep labels from
    rules at that priority level. This means a more specific, higher-priority
    rule can override a broader, lower-priority one on a per-file basis.
  - Labels from different files are accumulated into the final set.
  - We use fnmatch for glob matching, with special handling for ** (recursive).
"""

from dataclasses import dataclass
from fnmatch import fnmatch


@dataclass
class Rule:
    """A mapping rule: files matching `pattern` get the `label` applied.

    priority: lower number = higher priority. Default 0 (highest).
    When two rules match the same file, only labels from the highest-priority
    (lowest number) rules are kept for that file.
    """
    pattern: str
    label: str
    priority: int = 0


def _matches(filepath: str, pattern: str) -> bool:
    """Check if a filepath matches a glob pattern.

    Handles ** for recursive directory matching by checking both the full path
    and just the basename (for patterns like *.test.* that should match nested files).
    """
    # Direct fnmatch check (handles *, ?, [abc], etc.)
    if fnmatch(filepath, pattern):
        return True

    # For patterns with **, we need recursive matching.
    # fnmatch doesn't natively support **, so we handle it:
    # "docs/**" should match "docs/foo" and "docs/a/b/c.md"
    if "**" in pattern:
        # Split pattern on ** and check prefix/suffix
        parts = pattern.split("**")
        if len(parts) == 2:
            prefix, suffix = parts
            # Remove trailing/leading slashes from the split parts
            prefix = prefix.rstrip("/")
            suffix = suffix.lstrip("/")

            if prefix and not filepath.startswith(prefix + "/"):
                return False
            if prefix and filepath.startswith(prefix + "/"):
                remaining = filepath[len(prefix) + 1:]
                if not suffix:
                    return True
                return fnmatch(remaining, suffix)

    # For basename-only patterns WITH glob characters (e.g., *.test.*), match
    # against the filename component of nested paths. This allows *.test.* to
    # match src/foo.test.js. We only do this for patterns with wildcards so that
    # exact patterns like "Makefile" don't accidentally match "src/Makefile".
    if "/" not in pattern and any(c in pattern for c in ("*", "?", "[")):
        basename = filepath.rsplit("/", 1)[-1] if "/" in filepath else filepath
        if fnmatch(basename, pattern):
            return True

    return False


def assign_labels(files: list, rules: list) -> set:
    """Assign labels to a set of changed files based on matching rules.

    Args:
        files: List of changed file paths (strings).
        rules: List of Rule objects defining pattern-to-label mappings.

    Returns:
        A set of label strings that should be applied.

    Raises:
        TypeError: If file paths are not strings.
    """
    # Validate inputs
    for f in files:
        if not isinstance(f, str):
            raise TypeError(
                f"File paths must be strings, got {type(f).__name__}: {f!r}"
            )

    labels = set()

    for filepath in files:
        # Find all rules that match this file
        matches = [(rule, rule.priority) for rule in rules if _matches(filepath, rule.pattern)]

        if not matches:
            continue

        # Find the best (lowest number) priority among matching rules
        best_priority = min(m[1] for m in matches)

        # Keep only labels from rules at the best priority level
        for rule, priority in matches:
            if priority == best_priority:
                labels.add(rule.label)

    return labels


def load_rules_from_config(config: list) -> list:
    """Load rules from a list-of-dicts configuration.

    Each dict must have 'pattern' and 'label' keys; 'priority' is optional (default 0).

    Args:
        config: List of dicts, each with 'pattern', 'label', and optionally 'priority'.

    Returns:
        List of Rule objects.

    Raises:
        ValueError: If a config entry is missing required fields.
    """
    rules = []
    for i, entry in enumerate(config):
        if "pattern" not in entry:
            raise ValueError(
                f"Rule at index {i} is missing required 'pattern' field: {entry!r}"
            )
        if "label" not in entry:
            raise ValueError(
                f"Rule at index {i} is missing required 'label' field: {entry!r}"
            )
        rules.append(Rule(
            pattern=entry["pattern"],
            label=entry["label"],
            priority=entry.get("priority", 0),
        ))
    return rules


# ---------------------------------------------------------------------------
# CLI entry point: demonstrates usage with mock PR data
# ---------------------------------------------------------------------------
def main():
    """Demonstrate the label assigner with a mock PR."""
    # Configurable rules (would typically come from a YAML/JSON config file)
    config = [
        {"pattern": "docs/**", "label": "documentation", "priority": 5},
        {"pattern": "src/api/**", "label": "api", "priority": 1},
        {"pattern": "src/**", "label": "source", "priority": 10},
        {"pattern": "*.test.*", "label": "tests", "priority": 5},
        {"pattern": ".github/**", "label": "ci/cd", "priority": 3},
        {"pattern": "*.md", "label": "documentation", "priority": 8},
        {"pattern": "Dockerfile", "label": "infrastructure", "priority": 2},
        {"pattern": "*.lock", "label": "dependencies", "priority": 4},
        {"pattern": "package.json", "label": "dependencies", "priority": 4},
    ]

    rules = load_rules_from_config(config)

    # Mock PR changed files
    mock_files = [
        "docs/api-guide.md",
        "src/api/handlers/user.py",
        "src/utils/helpers.py",
        "tests/unit/auth.test.js",
        ".github/workflows/ci.yml",
        "README.md",
        "Dockerfile",
        "package.json",
    ]

    print("PR Label Assigner")
    print("=" * 50)
    print(f"\nChanged files ({len(mock_files)}):")
    for f in mock_files:
        print(f"  - {f}")

    print(f"\nConfigured rules ({len(rules)}):")
    for r in rules:
        print(f"  [{r.priority:2d}] {r.pattern:<20s} -> {r.label}")

    labels = assign_labels(mock_files, rules)

    print(f"\nAssigned labels ({len(labels)}):")
    for label in sorted(labels):
        print(f"  * {label}")

    # Show per-file breakdown
    print("\nPer-file breakdown:")
    for filepath in mock_files:
        file_labels = assign_labels([filepath], rules)
        print(f"  {filepath:<45s} -> {', '.join(sorted(file_labels)) or '(none)'}")


if __name__ == "__main__":
    main()
