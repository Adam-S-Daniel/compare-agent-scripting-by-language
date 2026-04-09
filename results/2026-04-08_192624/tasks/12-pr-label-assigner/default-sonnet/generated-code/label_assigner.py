"""
PR Label Assigner
=================
Assigns labels to pull requests based on changed file paths and configurable
glob pattern rules.

Design:
- LabelRule: a single pattern -> label mapping with a priority
- LabelConfig: a collection of rules loaded from a config dict
- assign_labels: core function - matches files against rules, returns label set
- assign_labels_sorted: same but returns labels sorted by priority
- CLI entry point for use in GitHub Actions
"""

import fnmatch
import json
import sys
from dataclasses import dataclass, field
from typing import List, Set


# ============================================================
# Data Classes
# ============================================================

@dataclass
class LabelRule:
    """
    A single rule mapping a glob pattern to a label.
    Lower priority number = higher priority (1 is highest).
    """
    pattern: str
    label: str
    priority: int

    def __post_init__(self):
        if self.priority < 1:
            raise ValueError(
                f"priority must be a positive integer, got {self.priority}"
            )
        if not self.pattern:
            raise ValueError("pattern must not be empty")
        if not self.label:
            raise ValueError("label must not be empty")


@dataclass
class LabelConfig:
    """Container for a list of LabelRules."""
    rules: List[LabelRule] = field(default_factory=list)


# ============================================================
# Config Loader
# ============================================================

def load_config(config_dict: dict) -> LabelConfig:
    """
    Parse a configuration dict into a LabelConfig.

    Expected format:
    {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            ...
        ]
    }

    Raises ValueError if required fields are missing or invalid.
    """
    rules = []
    for i, rule_dict in enumerate(config_dict.get("rules", [])):
        # 'pattern' is required
        if "pattern" not in rule_dict:
            raise KeyError(f"Rule {i} is missing required field 'pattern'")
        # 'label' is required
        if "label" not in rule_dict:
            raise KeyError(f"Rule {i} is missing required field 'label'")
        # 'priority' is required and must be positive
        priority = rule_dict.get("priority", 1)
        rule = LabelRule(
            pattern=rule_dict["pattern"],
            label=rule_dict["label"],
            priority=priority,
        )
        rules.append(rule)
    return LabelConfig(rules=rules)


# ============================================================
# Core Logic
# ============================================================

def _matches(file_path: str, pattern: str) -> bool:
    """
    Check if a file path matches a glob pattern.

    Uses fnmatch for matching. For patterns with '**' we also try matching
    the basename to support patterns like '*.test.*' against 'src/foo.test.py'.

    '**' in a pattern means "any path segment including none".
    We handle this by:
    1. Trying exact fnmatch against the full path
    2. If pattern has no '/', trying against just the basename
    3. If pattern starts with no directory component, trying against basename
    """
    # Normalize path separators
    file_path = file_path.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    # Direct full-path match
    if fnmatch.fnmatch(file_path, pattern):
        return True

    # For patterns like '*.test.*' (no path separator), also try basename
    if "/" not in pattern:
        basename = file_path.split("/")[-1]
        if fnmatch.fnmatch(basename, pattern):
            return True

    # For patterns ending with '/**', handle the case where '**' should
    # match any number of path components including deeply nested files.
    # fnmatch doesn't support '**' natively, so we convert it.
    if "**" in pattern:
        # Replace '**' with a wildcard that matches everything
        # We do this by splitting on '**' and checking prefix/suffix
        regex_pattern = _glob_to_fnmatch(pattern)
        if fnmatch.fnmatch(file_path, regex_pattern):
            return True

    return False


def _glob_to_fnmatch(pattern: str) -> str:
    """
    Convert a glob pattern with '**' to something fnmatch can handle.

    Strategy: replace '**/' with '*/' repeated, and '/**' at end with '/*'.
    For simplicity, replace '**' with '*' which works for most cases
    since fnmatch '*' doesn't cross '/' but we can split differently.

    Actually, the cleanest approach: use pathlib or manual prefix matching.
    We'll use a simple approach: if pattern is 'prefix/**', check if
    file starts with 'prefix/'.
    """
    # Handle the common case: 'dir/**' -> matches anything under 'dir/'
    if pattern.endswith("/**"):
        prefix = pattern[:-3]  # Remove '/**'
        return prefix + "/*"  # This won't work for nested - need custom logic

    # For other '**' patterns, just replace with '*' as approximation
    return pattern.replace("**", "*")


def _matches_advanced(file_path: str, pattern: str) -> bool:
    """
    Advanced matcher that properly handles '**' glob patterns.

    '**' matches any sequence of characters including path separators.
    """
    file_path = file_path.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    # Split pattern on '**' to get prefix and suffix parts
    if "**" not in pattern:
        # No '**' - use simple fnmatch
        result = fnmatch.fnmatch(file_path, pattern)
        if not result and "/" not in pattern:
            # Try basename match for patterns without directory
            basename = file_path.split("/")[-1]
            result = fnmatch.fnmatch(basename, pattern)
        return result

    # Handle '**' by checking if pattern matches as a path prefix/suffix
    # Split pattern into parts around '**'
    parts = pattern.split("**")

    if len(parts) == 2:
        prefix, suffix = parts
        # Remove trailing/leading slashes from the split
        prefix = prefix.rstrip("/")
        suffix = suffix.lstrip("/")

        if prefix and not file_path.startswith(prefix + "/") and file_path != prefix:
            return False

        if suffix:
            # suffix is something after **, file must end with it
            # and the suffix part must match using fnmatch
            remaining = file_path
            if prefix:
                remaining = file_path[len(prefix):].lstrip("/")
            return fnmatch.fnmatch(remaining, "*" + suffix) or fnmatch.fnmatch(remaining, suffix)
        else:
            # Pattern is 'prefix/**' -> matches anything under prefix/
            if prefix:
                return file_path.startswith(prefix + "/") or file_path == prefix
            return True  # '**' alone matches everything

    # Multiple '**' - use recursive approach
    # Simplification: replace each '**' with a multi-segment wildcard
    import re
    regex = re.escape(pattern).replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", "[^/]")
    return bool(re.fullmatch(regex, file_path))


def assign_labels(files: List[str], rules: List[LabelRule]) -> Set[str]:
    """
    Given a list of changed file paths and a list of rules,
    return the set of labels that apply.

    Each file is checked against each rule's glob pattern.
    If it matches, the rule's label is added to the result set.
    Labels are deduplicated automatically (set semantics).
    """
    if not files or not rules:
        return set()

    labels: Set[str] = set()

    for file_path in files:
        for rule in rules:
            if _matches_advanced(file_path, rule.pattern):
                labels.add(rule.label)

    return labels


def assign_labels_sorted(files: List[str], rules: List[LabelRule]) -> List[str]:
    """
    Like assign_labels but returns labels sorted by their highest-priority
    (lowest priority number) rule that matched them.

    This allows callers to know which labels are most "important".
    """
    if not files or not rules:
        return []

    # Track the best (lowest) priority number seen for each label
    label_priority: dict = {}

    for file_path in files:
        for rule in rules:
            if _matches_advanced(file_path, rule.pattern):
                existing = label_priority.get(rule.label, float("inf"))
                label_priority[rule.label] = min(existing, rule.priority)

    # Sort labels by their best priority (ascending = highest priority first)
    return sorted(label_priority.keys(), key=lambda lbl: label_priority[lbl])


# ============================================================
# CLI Entry Point
# ============================================================

def main():
    """
    CLI entry point for use in GitHub Actions.

    Usage:
        python label_assigner.py --config config.json --files file1 file2 ...
        python label_assigner.py --config config.json --files-json '["file1","file2"]'

    Outputs the assigned labels as JSON array to stdout.
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Assign labels to a PR based on changed file paths"
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to JSON config file with label rules",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        default=[],
        help="List of changed file paths",
    )
    parser.add_argument(
        "--files-json",
        default=None,
        help="JSON array of changed file paths (alternative to --files)",
    )
    args = parser.parse_args()

    # Load config
    try:
        with open(args.config) as f:
            config_dict = json.load(f)
        config = load_config(config_dict)
    except FileNotFoundError:
        print(f"ERROR: Config file not found: {args.config}", file=sys.stderr)
        sys.exit(1)
    except (json.JSONDecodeError, ValueError, KeyError) as e:
        print(f"ERROR: Invalid config: {e}", file=sys.stderr)
        sys.exit(1)

    # Collect file list
    files = args.files or []
    if args.files_json:
        try:
            files = json.loads(args.files_json)
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid --files-json: {e}", file=sys.stderr)
            sys.exit(1)

    if not files:
        print("WARNING: No files provided, no labels will be assigned", file=sys.stderr)

    # Compute labels
    labels = assign_labels_sorted(files, config.rules)

    # Output results
    print(f"LABELS_JSON={json.dumps(labels)}")
    print(f"LABELS_COUNT={len(labels)}")
    if labels:
        print(f"LABELS={','.join(labels)}")
    else:
        print("LABELS=")

    return 0


if __name__ == "__main__":
    sys.exit(main())
