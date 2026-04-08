"""Batch file renamer: rename files using regex patterns with preview, undo, and conflict detection."""

import os
import re
import shlex
import stat


def compute_renames(files, pattern, replacement):
    """Compute a mapping of old_name -> new_name for files matching the regex pattern.

    Only includes files where the name actually changes.
    The regex is applied to the filename (not the full path).
    """
    renames = {}
    regex = re.compile(pattern)
    for filename in files:
        new_name = regex.sub(replacement, filename)
        if new_name != filename:
            renames[filename] = new_name
    return renames


def detect_conflicts(renames, existing_files=None):
    """Detect naming conflicts in a proposed rename plan.

    Checks two kinds of conflict:
    1. Multiple source files mapping to the same target name.
    2. A target name colliding with an existing file that isn't itself being renamed.

    Returns a dict: {target_name: [list of sources that collide]}.
    """
    from collections import defaultdict

    # Build target -> list of sources
    target_sources = defaultdict(list)
    for old, new in renames.items():
        target_sources[new].append(old)

    conflicts = {}

    # Check for multiple sources -> same target
    for target, sources in target_sources.items():
        if len(sources) > 1:
            conflicts[target] = sorted(sources)

    # Check for collision with existing files not being renamed away
    if existing_files is not None:
        renamed_away = set(renames.keys())
        for target, sources in target_sources.items():
            if target in conflicts:
                continue  # already flagged
            # Conflict if target exists AND isn't being renamed itself
            if target in existing_files and target not in renamed_away:
                conflicts[target] = sorted(sources) + ["(already exists)"]

    return conflicts


def preview_renames(renames):
    """Return a human-readable preview of planned renames.

    Shows each rename as 'old_name -> new_name', one per line.
    Returns a single string with all lines joined.
    """
    if not renames:
        return "No files match the pattern."
    lines = []
    for old, new in sorted(renames.items()):
        lines.append(f"{old} -> {new}")
    return "\n".join(lines)


def generate_undo_script(renames):
    """Generate a bash script that reverses all renames.

    Each rename old->new becomes 'mv new old' in the undo script.
    Uses shlex.quote to safely handle filenames with special characters.
    """
    lines = ["#!/bin/bash", "# Undo script — reverses the batch rename operation", "set -e", ""]
    for old, new in sorted(renames.items()):
        lines.append(f"mv {shlex.quote(new)} {shlex.quote(old)}")
    lines.append("")
    return "\n".join(lines)


def execute_renames(directory, renames):
    """Execute renames on disk inside `directory`.

    Before renaming:
    - Checks for conflicts and raises ValueError if any are found.
    - Checks that all source files exist and raises FileNotFoundError otherwise.

    After renaming, writes an undo script to directory/undo_renames.sh.
    """
    # Validate sources exist
    for old in renames:
        src = os.path.join(directory, old)
        if not os.path.exists(src):
            raise FileNotFoundError(f"Source file not found: {old}")

    # Check conflicts (both duplicate targets and collisions with existing non-renamed files)
    existing = os.listdir(directory)
    conflicts = detect_conflicts(renames, existing)
    if conflicts:
        details = "; ".join(
            f"{target} <- {', '.join(sources)}" for target, sources in conflicts.items()
        )
        raise ValueError(f"Conflict detected, aborting: {details}")

    # Perform the renames
    for old, new in renames.items():
        os.rename(os.path.join(directory, old), os.path.join(directory, new))

    # Write the undo script
    undo_path = os.path.join(directory, "undo_renames.sh")
    with open(undo_path, "w") as f:
        f.write(generate_undo_script(renames))
    os.chmod(undo_path, os.stat(undo_path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def main():
    """CLI entry point: renamer.py DIRECTORY PATTERN REPLACEMENT [--preview]"""
    import argparse
    import sys

    parser = argparse.ArgumentParser(
        description="Batch rename files using regex patterns.",
    )
    parser.add_argument("directory", help="Directory containing files to rename")
    parser.add_argument("pattern", help="Regex pattern to match filenames")
    parser.add_argument("replacement", help="Replacement string (supports \\1 backreferences)")
    parser.add_argument("--preview", action="store_true", help="Show what would change without renaming")
    args = parser.parse_args()

    if not os.path.isdir(args.directory):
        print(f"Error: '{args.directory}' is not a directory", file=sys.stderr)
        sys.exit(1)

    # List only files (not directories) in the target directory
    files = sorted(
        f for f in os.listdir(args.directory)
        if os.path.isfile(os.path.join(args.directory, f))
    )

    try:
        renames = compute_renames(files, args.pattern, args.replacement)
    except re.error as e:
        print(f"Error: invalid regex pattern: {e}", file=sys.stderr)
        sys.exit(1)

    if args.preview:
        print(preview_renames(renames))
        return

    if not renames:
        print("No files match the pattern.")
        return

    # Check for conflicts before executing
    existing = os.listdir(args.directory)
    conflicts = detect_conflicts(renames, existing)
    if conflicts:
        for target, sources in conflicts.items():
            print(f"Conflict: {', '.join(sources)} -> {target}", file=sys.stderr)
        sys.exit(1)

    execute_renames(args.directory, renames)
    print(f"Renamed {len(renames)} file(s). Undo script: {os.path.join(args.directory, 'undo_renames.sh')}")


if __name__ == "__main__":
    main()
