"""
Multi-file search-and-replace tool with preview mode, backup creation,
and a summary report.

Features:
  - Recursively find files matching a glob pattern
  - Search files for a regex pattern
  - Preview mode: show matches with context without modifying files
  - Backup creation: copy originals before modifying
  - Replace mode: perform substitution and report changes
  - Summary report: file, line number, old text, new text
"""

import os
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional


# ── Data classes for structured results ──


@dataclass
class Match:
    """A single regex match within a file."""
    file: Path
    line_number: int       # 1-based
    line_text: str         # full original line (stripped of newline)
    match_text: str        # the matched substring


@dataclass
class Change:
    """A single replacement made in a file."""
    file: Path
    line_number: int       # 1-based
    old_text: str          # original line content
    new_text: str          # line content after replacement


@dataclass
class Report:
    """Summary report of a search-and-replace operation."""
    changes: List[Change] = field(default_factory=list)
    files_modified: int = 0
    total_replacements: int = 0
    backups_created: List[Path] = field(default_factory=list)

    def summary(self) -> str:
        """Return a human-readable summary string."""
        lines = [
            f"Files modified: {self.files_modified}",
            f"Total replacements: {self.total_replacements}",
        ]
        if self.backups_created:
            lines.append(f"Backups created: {len(self.backups_created)}")
        lines.append("")
        lines.append("Changes:")
        for c in self.changes:
            lines.append(f"  {c.file}:{c.line_number}")
            lines.append(f"    - {c.old_text}")
            lines.append(f"    + {c.new_text}")
        return "\n".join(lines)


# ── Core functions ──


def find_files(root: Path, glob_pattern: str) -> List[Path]:
    """Recursively find files under *root* matching *glob_pattern*.

    Returns a list of Path objects sorted by name for determinism.
    Only regular files are returned (not directories).
    """
    root = Path(root)
    if not root.is_dir():
        raise FileNotFoundError(f"Root directory does not exist: {root}")
    results = sorted(p for p in root.glob(glob_pattern) if p.is_file())
    return results


def search_files(
    root: Path,
    glob_pattern: str,
    regex_pattern: str,
    context_lines: int = 0,
) -> List[Match]:
    """Search files matching *glob_pattern* under *root* for *regex_pattern*.

    Returns a list of Match objects. Raises re.error for invalid regex.
    context_lines is accepted but context is handled at display time.
    """
    compiled = re.compile(regex_pattern)
    files = find_files(root, glob_pattern)
    matches: List[Match] = []

    for filepath in files:
        try:
            content = filepath.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError) as exc:
            # Skip binary / unreadable files gracefully
            continue
        for lineno, line in enumerate(content.splitlines(), start=1):
            for m in compiled.finditer(line):
                matches.append(Match(
                    file=filepath,
                    line_number=lineno,
                    line_text=line,
                    match_text=m.group(),
                ))
    return matches


def preview(
    root: Path,
    glob_pattern: str,
    regex_pattern: str,
    replacement: str,
    context_lines: int = 1,
) -> str:
    """Show what changes *would* be made, without modifying any files.

    Returns a formatted preview string with context around each match.
    """
    matches = search_files(root, glob_pattern, regex_pattern)
    if not matches:
        return "No matches found."

    compiled = re.compile(regex_pattern)
    lines_out: List[str] = []

    for match in matches:
        new_line = compiled.sub(replacement, match.line_text)
        # Read surrounding context from the file
        try:
            all_lines = match.file.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, PermissionError):
            continue

        total = len(all_lines)
        idx = match.line_number - 1  # 0-based index
        start = max(0, idx - context_lines)
        end = min(total, idx + context_lines + 1)

        lines_out.append(f"--- {match.file}:{match.line_number} ---")
        for i in range(start, end):
            prefix = "  "
            if i == idx:
                # Show old and new for the matching line
                lines_out.append(f"- {all_lines[i]}")
                lines_out.append(f"+ {new_line}")
            else:
                lines_out.append(f"  {all_lines[i]}")
        lines_out.append("")

    return "\n".join(lines_out)


def create_backup(filepath: Path, backup_suffix: str = ".bak") -> Path:
    """Create a backup copy of *filepath*.

    Returns the path to the backup file.
    Raises FileNotFoundError if the source doesn't exist.
    """
    filepath = Path(filepath)
    if not filepath.exists():
        raise FileNotFoundError(f"Cannot back up non-existent file: {filepath}")
    backup_path = filepath.with_suffix(filepath.suffix + backup_suffix)
    shutil.copy2(filepath, backup_path)
    return backup_path


def search_and_replace(
    root: Path,
    glob_pattern: str,
    regex_pattern: str,
    replacement: str,
    create_backups: bool = True,
    backup_suffix: str = ".bak",
) -> Report:
    """Perform search-and-replace across files, returning a Report.

    For each file that has matches:
      1. Optionally create a backup of the original
      2. Replace all occurrences of *regex_pattern* with *replacement*
      3. Record each changed line in the report

    Raises re.error for invalid regex patterns.
    """
    compiled = re.compile(regex_pattern)
    files = find_files(root, glob_pattern)
    report = Report()

    for filepath in files:
        try:
            original_content = filepath.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue

        original_lines = original_content.splitlines(keepends=True)
        new_lines: List[str] = []
        file_changed = False

        for lineno, line in enumerate(original_lines, start=1):
            new_line = compiled.sub(replacement, line)
            new_lines.append(new_line)
            if new_line != line:
                file_changed = True
                report.changes.append(Change(
                    file=filepath,
                    line_number=lineno,
                    old_text=line.rstrip("\n").rstrip("\r"),
                    new_text=new_line.rstrip("\n").rstrip("\r"),
                ))
                report.total_replacements += 1

        if file_changed:
            # Create backup before writing
            if create_backups:
                backup_path = create_backup(filepath, backup_suffix)
                report.backups_created.append(backup_path)
            filepath.write_text("".join(new_lines), encoding="utf-8")
            report.files_modified += 1

    return report
