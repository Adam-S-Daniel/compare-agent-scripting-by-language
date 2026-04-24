"""Tests for PR label assigner.

Uses red/green TDD: each test written FIRST to fail, then minimum code added.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

# Make the parent directory importable so we can exercise the module directly.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from pr_label_assigner import (  # noqa: E402
    assign_labels,
    load_rules,
    match_pattern,
)


# --- Glob matching ----------------------------------------------------------

def test_match_pattern_exact():
    # An exact file path pattern matches itself.
    assert match_pattern("README.md", "README.md")


def test_match_pattern_single_star_in_one_segment():
    # A single `*` matches anything inside ONE path segment only.
    assert match_pattern("README.md", "*.md")
    assert not match_pattern("docs/README.md", "*.md")


def test_match_pattern_double_star_crosses_directories():
    # `**` is the classic globstar: it crosses directory boundaries.
    assert match_pattern("docs/guide.md", "docs/**")
    assert match_pattern("docs/a/b/c.md", "docs/**")
    assert match_pattern("src/api/v1/users.py", "src/api/**")


def test_match_pattern_double_star_anywhere():
    # `**/foo` should match `foo` at any depth (including the root).
    assert match_pattern("foo.test.js", "**/*.test.*")
    assert match_pattern("src/deep/foo.test.js", "**/*.test.*")


def test_match_pattern_question_mark():
    # `?` matches exactly one non-slash character.
    assert match_pattern("a.md", "?.md")
    assert not match_pattern("ab.md", "?.md")


# --- Rules loading ----------------------------------------------------------

def test_load_rules_from_json(tmp_path):
    # Rules are loaded from a JSON config file.
    config = tmp_path / "rules.json"
    config.write_text(json.dumps({
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"]},
        ]
    }))
    rules = load_rules(config)
    assert len(rules) == 1
    assert rules[0]["pattern"] == "docs/**"
    assert rules[0]["labels"] == ["documentation"]


def test_load_rules_missing_file_raises_friendly_error(tmp_path):
    # A missing config file should raise a FileNotFoundError with the path in the message.
    missing = tmp_path / "nope.json"
    with pytest.raises(FileNotFoundError) as exc_info:
        load_rules(missing)
    assert "nope.json" in str(exc_info.value)


def test_load_rules_malformed_json_raises_friendly_error(tmp_path):
    # Malformed JSON should raise ValueError mentioning the file.
    config = tmp_path / "bad.json"
    config.write_text("{not valid json")
    with pytest.raises(ValueError) as exc_info:
        load_rules(config)
    assert "bad.json" in str(exc_info.value)


def test_load_rules_requires_rules_key(tmp_path):
    # If the top-level `rules` key is missing, we surface a clear error.
    config = tmp_path / "no_rules.json"
    config.write_text(json.dumps({"wrong_key": []}))
    with pytest.raises(ValueError) as exc_info:
        load_rules(config)
    assert "rules" in str(exc_info.value)


# --- Label assignment -------------------------------------------------------

def test_assign_labels_empty_file_list_returns_no_labels():
    # No changed files => no labels applied.
    rules = [{"pattern": "docs/**", "labels": ["documentation"]}]
    assert assign_labels([], rules) == []


def test_assign_labels_single_match():
    rules = [{"pattern": "docs/**", "labels": ["documentation"]}]
    assert assign_labels(["docs/intro.md"], rules) == ["documentation"]


def test_assign_labels_multiple_labels_per_rule():
    # A single rule can attach multiple labels.
    rules = [{"pattern": "src/api/**", "labels": ["api", "backend"]}]
    result = assign_labels(["src/api/v1/users.py"], rules)
    assert set(result) == {"api", "backend"}


def test_assign_labels_multiple_files_union_labels():
    # Labels from different files/rules are unioned.
    rules = [
        {"pattern": "docs/**", "labels": ["documentation"]},
        {"pattern": "src/api/**", "labels": ["api"]},
    ]
    result = assign_labels(
        ["docs/readme.md", "src/api/users.py"],
        rules,
    )
    assert set(result) == {"documentation", "api"}


def test_assign_labels_file_matches_multiple_rules():
    # One file can match multiple rules, and all of their labels apply.
    rules = [
        {"pattern": "**/*.test.*", "labels": ["tests"]},
        {"pattern": "src/**", "labels": ["source"]},
    ]
    result = assign_labels(["src/foo.test.js"], rules)
    assert set(result) == {"tests", "source"}


def test_assign_labels_deduplicates():
    # If two files both add the same label, it appears only once.
    rules = [{"pattern": "docs/**", "labels": ["documentation"]}]
    result = assign_labels(["docs/a.md", "docs/b.md"], rules)
    assert result == ["documentation"]


def test_assign_labels_no_matching_rules():
    # When no rule matches any file, no labels are produced.
    rules = [{"pattern": "docs/**", "labels": ["documentation"]}]
    assert assign_labels(["src/foo.py"], rules) == []


# --- Priority / conflict resolution ----------------------------------------

def test_priority_orders_output_highest_first():
    # Higher priority values come first in the output list.
    rules = [
        {"pattern": "docs/**", "labels": ["documentation"], "priority": 1},
        {"pattern": "src/api/**", "labels": ["api"], "priority": 10},
    ]
    result = assign_labels(
        ["docs/x.md", "src/api/y.py"],
        rules,
    )
    # "api" comes from priority=10, "documentation" from priority=1.
    assert result == ["api", "documentation"]


def test_priority_conflict_resolution_same_group_higher_wins():
    # When two rules belong to the same `group`, only the highest-priority one's
    # labels survive for files matched by both — this is the "conflict" case.
    rules = [
        {"pattern": "src/**", "labels": ["source"], "group": "area", "priority": 1},
        {"pattern": "src/api/**", "labels": ["api"], "group": "area", "priority": 10},
    ]
    # This file matches both rules; the higher-priority one wins the group.
    result = assign_labels(["src/api/users.py"], rules)
    assert result == ["api"]


def test_priority_default_is_zero_and_stable():
    # Rules without an explicit priority default to 0. Ties keep config order.
    rules = [
        {"pattern": "a/**", "labels": ["first"]},
        {"pattern": "b/**", "labels": ["second"]},
    ]
    result = assign_labels(["a/x", "b/y"], rules)
    assert result == ["first", "second"]


# --- CLI --------------------------------------------------------------------

def _run_cli(*args, cwd=None):
    """Run the CLI and return (returncode, stdout, stderr)."""
    cmd = [sys.executable, str(ROOT / "pr_label_assigner.py"), *args]
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_outputs_labels_as_json(tmp_path):
    # The CLI reads rules + a file list and prints JSON labels on stdout.
    config = tmp_path / "rules.json"
    config.write_text(json.dumps({
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"]},
            {"pattern": "src/api/**", "labels": ["api"], "priority": 5},
        ]
    }))
    files = tmp_path / "files.txt"
    files.write_text("docs/readme.md\nsrc/api/users.py\n")

    code, out, err = _run_cli("--rules", str(config), "--files", str(files))
    assert code == 0, err
    payload = json.loads(out)
    assert payload == ["api", "documentation"]


def test_cli_reads_files_from_stdin_when_dash(tmp_path):
    # Using `--files -` reads the file list from stdin (handy for `git diff | ...`).
    config = tmp_path / "rules.json"
    config.write_text(json.dumps({
        "rules": [
            {"pattern": "**/*.test.*", "labels": ["tests"]},
        ]
    }))
    cmd = [sys.executable, str(ROOT / "pr_label_assigner.py"),
           "--rules", str(config), "--files", "-"]
    proc = subprocess.run(
        cmd, input="src/foo.test.js\n", capture_output=True, text=True,
    )
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout) == ["tests"]


def test_cli_missing_rules_file_exits_nonzero(tmp_path):
    # Missing rules file must exit with a non-zero code and a helpful stderr.
    code, _, err = _run_cli("--rules", str(tmp_path / "nope.json"),
                            "--files", "-")
    assert code != 0
    assert "nope.json" in err
