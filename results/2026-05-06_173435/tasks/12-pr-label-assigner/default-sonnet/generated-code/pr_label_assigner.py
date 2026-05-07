#!/usr/bin/env python3
"""PR Label Assigner — assigns GitHub labels based on changed file paths.

Rules are glob patterns mapped to labels. Priority (lower = higher) controls
ordering when multiple rules match the same file; all matching labels are
collected into the final set (no exclusion by default).

Glob semantics:
  *    — matches any character except /
  **   — matches any character including / (recursive wildcard)
  **/  — matches any directory prefix (including none), e.g. **/*.py
  ?    — matches any single character except /

If a pattern contains no '/', it is matched against the filename only (basename).
Otherwise the full relative path is matched.
"""

import argparse
import json
import os
import re
import sys


# ---------------------------------------------------------------------------
# Glob → regex conversion
# ---------------------------------------------------------------------------

def _glob_to_regex(pattern: str) -> str:
    """Convert a glob pattern to a compiled-ready regex string.

    Handles *, **, **/, and ? with proper directory-boundary semantics.
    """
    result: list[str] = []
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if c == '*':
            if i + 1 < len(pattern) and pattern[i + 1] == '*':
                i += 2
                if i < len(pattern) and pattern[i] == '/':
                    # **/ means "any directory path, including none"
                    result.append('(.*/)?')
                    i += 1
                else:
                    # ** at end-of-pattern: match everything remaining
                    result.append('.*')
                continue
            else:
                # Single *: match anything except /
                result.append('[^/]*')
        elif c == '?':
            result.append('[^/]')
        elif c in r'\.+^${}[]|()\|':
            result.append('\\' + c)
        else:
            result.append(c)
        i += 1
    return '^' + ''.join(result) + '$'


def pattern_matches(file_path: str, pattern: str) -> bool:
    """Return True if file_path matches the glob pattern.

    If pattern has no '/', match against the filename (basename) only so that
    patterns like '*.test.*' match 'src/utils.test.js'.
    """
    if '/' not in pattern:
        target = os.path.basename(file_path)
    else:
        target = file_path
    regex = _glob_to_regex(pattern)
    return bool(re.match(regex, target))


# ---------------------------------------------------------------------------
# Core label-assignment logic
# ---------------------------------------------------------------------------

def assign_labels(file_paths: list[str], rules: list[dict]) -> set[str]:
    """Return the set of labels matching the given changed file paths.

    Rules are sorted by 'priority' (lower number = higher priority) before
    evaluation. All matching rules contribute their labels; the result is the
    union across all files and all matching rules.

    Args:
        file_paths: Relative paths of files changed in the PR.
        rules: List of rule dicts, each with keys:
               - pattern (str): glob pattern
               - label (str): label to apply on match
               - priority (int, optional): sort order; defaults to 0

    Returns:
        Set of label strings. Empty set when nothing matches.
    """
    sorted_rules = sorted(rules, key=lambda r: r.get('priority', 0))
    labels: set[str] = set()
    for file_path in file_paths:
        for rule in sorted_rules:
            if pattern_matches(file_path, rule['pattern']):
                labels.add(rule['label'])
    return labels


# ---------------------------------------------------------------------------
# Config / file-list I/O
# ---------------------------------------------------------------------------

def load_config(config_path: str) -> list[dict]:
    """Load label rules from a JSON config file.

    Accepts either a bare list of rule objects or a dict with a 'rules' key.

    Raises:
        FileNotFoundError: when the config file does not exist.
        ValueError: when the file contains invalid JSON or an unrecognised structure.
    """
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Config file not found: {config_path}")
    try:
        with open(config_path, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in config file '{config_path}': {exc}") from exc

    if isinstance(data, list):
        return data
    if isinstance(data, dict) and 'rules' in data:
        return data['rules']
    raise ValueError(
        f"Config file '{config_path}' must contain a JSON array or a dict with a 'rules' key"
    )


def load_files(files_path: str) -> list[str]:
    """Load changed file paths from a plain-text file (one path per line).

    Raises:
        FileNotFoundError: when the file does not exist.
    """
    if not os.path.exists(files_path):
        raise FileNotFoundError(f"Files list not found: {files_path}")
    with open(files_path, 'r') as f:
        return [line.strip() for line in f if line.strip()]


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description='Assign PR labels based on changed file paths.'
    )
    parser.add_argument(
        '--config', default='label_config.json',
        help='Path to the label rules config (JSON). Default: label_config.json'
    )
    parser.add_argument(
        '--files',
        help='Path to a text file listing changed file paths (one per line). '
             'Omit to use built-in mock data.'
    )
    parser.add_argument(
        '--output', choices=['text', 'json'], default='text',
        help='Output format. Default: text'
    )
    args = parser.parse_args()

    try:
        rules = load_config(args.config)
    except (FileNotFoundError, ValueError) as exc:
        print(f"Error loading config: {exc}", file=sys.stderr)
        return 1

    if args.files:
        try:
            file_paths = load_files(args.files)
        except FileNotFoundError as exc:
            print(f"Error loading file list: {exc}", file=sys.stderr)
            return 1
    else:
        # Built-in mock data for quick demonstration
        file_paths = [
            "docs/README.md",
            "src/api/users.py",
            "src/utils.test.js",
        ]
        print("(Using mock file list — pass --files to specify real paths)")

    labels = assign_labels(file_paths, rules)
    sorted_labels = sorted(labels)

    if args.output == 'json':
        print(json.dumps(sorted_labels))
    else:
        print(f"LABELS: {sorted_labels}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
