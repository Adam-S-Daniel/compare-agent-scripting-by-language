"""
Batch File Renamer — rename files in a directory using regex patterns.

Features:
  - Plan renames using regex search/replace on filenames
  - Preview mode: see what would change without modifying anything
  - Conflict detection: error if two files would get the same name
  - Undo capability: generate a reverse-rename plan or shell script
  - Actual execution: rename files on disk

Developed using red/green TDD — see test_renamer.py for the test suite.
"""

import os
import re
import stat
from collections import defaultdict
from typing import List, Tuple, Optional


class RenameConflictError(Exception):
    """Raised when a rename plan would produce duplicate target filenames."""
    pass


class BatchRenamer:
    """Core engine for regex-based batch file renaming."""

    # -- Planning (no filesystem side effects) --------------------------------

    def plan_renames(
        self,
        files: List[str],
        pattern: str,
        replacement: str,
    ) -> List[Tuple[str, str]]:
        """
        Compute the list of (old_name, new_name) rename operations.

        Args:
            files: List of filenames (just names, not full paths).
            pattern: Regex pattern to search for in each filename.
            replacement: Replacement string (may use \\1, \\2 for groups).

        Returns:
            List of (old_name, new_name) tuples for files that would change.

        Raises:
            ValueError: If the regex pattern is invalid or empty.
            RenameConflictError: If two files would get the same target name.
        """
        # Validate inputs
        if not pattern:
            raise ValueError("Regex pattern must not be empty")

        try:
            compiled = re.compile(pattern)
        except re.error as e:
            raise ValueError(f"Invalid regex pattern '{pattern}': {e}")

        # Build the rename plan: compute new name for each matching file
        plan = []
        for filename in files:
            new_name = compiled.sub(replacement, filename, count=1)
            if new_name != filename:
                plan.append((filename, new_name))

        # Conflict detection: check for duplicate target names
        self._check_conflicts(files, plan)

        return plan

    def _check_conflicts(
        self,
        all_files: List[str],
        plan: List[Tuple[str, str]],
    ) -> None:
        """
        Check for naming conflicts in the rename plan.

        Two types of conflict:
          1. Two renamed files would get the same target name.
          2. A renamed file would clash with an existing file that isn't being renamed.

        Raises:
            RenameConflictError with details about the conflict.
        """
        # Collect all target names and their sources
        target_sources: dict[str, list[str]] = defaultdict(list)
        for old, new in plan:
            target_sources[new].append(old)

        # Type 1: Multiple files -> same target
        for target, sources in target_sources.items():
            if len(sources) > 1:
                source_list = ", ".join(sources)
                raise RenameConflictError(
                    f"Conflict: multiple files would be renamed to '{target}': {source_list}"
                )

        # Type 2: Target clashes with an existing file not being renamed
        renamed_sources = {old for old, _ in plan}
        for target, sources in target_sources.items():
            if target in all_files and target not in renamed_sources:
                raise RenameConflictError(
                    f"Conflict: '{sources[0]}' would be renamed to '{target}', "
                    f"which already exists and is not being renamed"
                )

    # -- Preview mode ---------------------------------------------------------

    def preview(
        self,
        files: List[str],
        pattern: str,
        replacement: str,
    ) -> List[str]:
        """
        Return human-readable preview of what renames would occur.

        Args:
            files: List of filenames.
            pattern: Regex pattern.
            replacement: Replacement string.

        Returns:
            List of "old_name -> new_name" strings.
        """
        plan = self.plan_renames(files, pattern, replacement)
        return [f"{old} -> {new}" for old, new in plan]

    # -- Undo generation ------------------------------------------------------

    def generate_undo(
        self,
        plan: List[Tuple[str, str]],
    ) -> List[Tuple[str, str]]:
        """
        Generate a reverse rename plan from an existing plan.

        Args:
            plan: List of (old_name, new_name) tuples.

        Returns:
            List of (new_name, old_name) tuples that would reverse the renames.
        """
        return [(new, old) for old, new in plan]

    def generate_undo_script(
        self,
        plan: List[Tuple[str, str]],
        directory: str = ".",
    ) -> str:
        """
        Generate a bash script that undoes the renames.

        Args:
            plan: The rename plan to reverse.
            directory: The directory where the files live (used in the script).

        Returns:
            String containing a complete bash script.
        """
        lines = [
            "#!/bin/bash",
            "# Undo script — reverses batch rename operations",
            "# Generated by BatchRenamer",
            "set -e",
            "",
        ]

        undo_plan = self.generate_undo(plan)
        for old, new in undo_plan:
            # Quote filenames to handle spaces/special chars
            lines.append(f'mv -- "{old}" "{new}"')

        lines.append("")  # trailing newline
        return "\n".join(lines)

    def write_undo_script(
        self,
        plan: List[Tuple[str, str]],
        script_path: str,
        directory: str = ".",
    ) -> None:
        """
        Write an undo script to a file and make it executable.

        Args:
            plan: The rename plan to reverse.
            script_path: Path where the script should be written.
            directory: Directory context for the script.
        """
        content = self.generate_undo_script(plan, directory)
        with open(script_path, "w") as f:
            f.write(content)
        # Make executable (owner rwx, group/other rx)
        os.chmod(script_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)

    # -- Directory scanning ---------------------------------------------------

    def scan_directory(self, directory: str) -> List[str]:
        """
        List files (not subdirectories) in a directory.

        Args:
            directory: Path to the directory to scan.

        Returns:
            Sorted list of filenames.

        Raises:
            FileNotFoundError: If the directory does not exist.
        """
        if not os.path.exists(directory):
            raise FileNotFoundError(
                f"Directory '{directory}' does not exist"
            )

        return sorted(
            entry for entry in os.listdir(directory)
            if os.path.isfile(os.path.join(directory, entry))
        )

    # -- Execution ------------------------------------------------------------

    def execute(
        self,
        directory: str,
        plan: List[Tuple[str, str]],
    ) -> int:
        """
        Execute a rename plan on actual files in a directory.

        Args:
            directory: Path to the directory containing the files.
            plan: List of (old_name, new_name) tuples.

        Returns:
            Number of files successfully renamed.
        """
        count = 0
        for old_name, new_name in plan:
            old_path = os.path.join(directory, old_name)
            new_path = os.path.join(directory, new_name)
            os.rename(old_path, new_path)
            count += 1
        return count
