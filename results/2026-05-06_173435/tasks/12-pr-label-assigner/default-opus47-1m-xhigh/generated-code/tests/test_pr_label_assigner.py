"""Tests for the PR label assigner.

We follow strict red/green TDD: each test below was written before the
corresponding production code. The first test (test_empty_files_returns_no_labels)
was the initial red, then production code grew to satisfy each test in turn.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

# Add the repo root to sys.path so we can import the script under test.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from pr_label_assigner import (  # noqa: E402
    LabelAssigner,
    LabelAssignerError,
    load_rules,
)


# ---------------------------------------------------------------------------
# Core matching: empty input, single rule, no match.
# ---------------------------------------------------------------------------
def test_empty_files_returns_no_labels():
    """An empty changed-file list must produce zero labels."""
    rules = [{"pattern": "docs/**", "label": "documentation"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels([]) == []


def test_single_file_matching_one_rule():
    """A file matching a single rule yields exactly that label."""
    rules = [{"pattern": "docs/**", "label": "documentation"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["docs/intro.md"]) == ["documentation"]


def test_no_matching_rule_returns_no_labels():
    """A file that matches nothing yields no labels (not an error)."""
    rules = [{"pattern": "docs/**", "label": "documentation"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["src/main.py"]) == []


# ---------------------------------------------------------------------------
# Glob semantics.
# ---------------------------------------------------------------------------
def test_double_star_matches_recursive_subdirs():
    rules = [{"pattern": "docs/**", "label": "documentation"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["docs/a/b/c/deep.md"]) == ["documentation"]


def test_single_star_does_not_cross_directory_boundary():
    """`src/*` matches `src/foo.py` but not `src/sub/foo.py`."""
    rules = [{"pattern": "src/*", "label": "src-shallow"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["src/foo.py"]) == ["src-shallow"]
    assert assigner.assign_labels(["src/sub/foo.py"]) == []


def test_basename_pattern_matches_anywhere():
    """A pattern with no slashes is treated as basename-anywhere (gitignore-ish)."""
    rules = [{"pattern": "*.test.*", "label": "tests"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["foo.test.js"]) == ["tests"]
    assert assigner.assign_labels(["src/lib/foo.test.js"]) == ["tests"]


def test_question_mark_matches_one_char():
    rules = [{"pattern": "v?.txt", "label": "versioned"}]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["v1.txt"]) == ["versioned"]
    assert assigner.assign_labels(["v12.txt"]) == []


# ---------------------------------------------------------------------------
# Multiple rules and labels.
# ---------------------------------------------------------------------------
def test_one_file_can_match_multiple_rules():
    """A file may pick up several labels when multiple rules match."""
    rules = [
        {"pattern": "src/api/**", "label": "api"},
        {"pattern": "**/*.py", "label": "python"},
    ]
    assigner = LabelAssigner(rules)
    labels = assigner.assign_labels(["src/api/handler.py"])
    assert set(labels) == {"api", "python"}


def test_multiple_files_yield_union_of_labels():
    rules = [
        {"pattern": "docs/**", "label": "documentation"},
        {"pattern": "src/api/**", "label": "api"},
    ]
    assigner = LabelAssigner(rules)
    labels = assigner.assign_labels(["docs/a.md", "src/api/x.py"])
    assert set(labels) == {"documentation", "api"}


def test_duplicate_labels_are_deduplicated():
    """If two files both produce 'docs', the label appears only once."""
    rules = [{"pattern": "docs/**", "label": "documentation"}]
    assigner = LabelAssigner(rules)
    labels = assigner.assign_labels(["docs/a.md", "docs/b.md"])
    assert labels == ["documentation"]


def test_output_is_sorted_for_determinism():
    """Output ordering is deterministic — alphabetical when priorities are equal."""
    rules = [
        {"pattern": "z/**", "label": "zeta"},
        {"pattern": "a/**", "label": "alpha"},
        {"pattern": "m/**", "label": "mu"},
    ]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["z/x", "a/x", "m/x"]) == ["alpha", "mu", "zeta"]


# ---------------------------------------------------------------------------
# Priority and groups (conflict resolution).
# ---------------------------------------------------------------------------
def test_priority_orders_output_descending():
    """Higher-priority labels come first in the output."""
    rules = [
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
        {"pattern": "src/**", "label": "code", "priority": 10},
    ]
    assigner = LabelAssigner(rules)
    assert assigner.assign_labels(["docs/a.md", "src/x.py"]) == ["code", "documentation"]


def test_within_a_group_only_highest_priority_wins():
    """Group-scoped conflict resolution: only one label per group, highest priority."""
    rules = [
        {"pattern": "**/*.py", "label": "size/small", "priority": 1, "group": "size"},
        {"pattern": "**/*.py", "label": "size/large", "priority": 10, "group": "size"},
    ]
    assigner = LabelAssigner(rules)
    # Both rules match foo.py, but only the higher-priority size/* wins.
    assert assigner.assign_labels(["foo.py"]) == ["size/large"]


def test_groups_are_independent():
    """Different groups don't suppress each other."""
    rules = [
        {"pattern": "**/*.py", "label": "lang/python", "priority": 1, "group": "lang"},
        {"pattern": "**/*.py", "label": "area/backend", "priority": 1, "group": "area"},
    ]
    assigner = LabelAssigner(rules)
    assert set(assigner.assign_labels(["foo.py"])) == {"lang/python", "area/backend"}


def test_ungrouped_rules_do_not_conflict():
    """Rules without a group always contribute their labels, even if 'similar'."""
    rules = [
        {"pattern": "**/*.py", "label": "type-a", "priority": 1},
        {"pattern": "**/*.py", "label": "type-b", "priority": 5},
    ]
    assigner = LabelAssigner(rules)
    # Both labels present; sorted by priority desc.
    assert assigner.assign_labels(["foo.py"]) == ["type-b", "type-a"]


# ---------------------------------------------------------------------------
# Config loading and validation (error handling).
# ---------------------------------------------------------------------------
def test_load_rules_from_json_file(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({"rules": [{"pattern": "docs/**", "label": "docs"}]}))
    rules = load_rules(cfg)
    assert rules == [{"pattern": "docs/**", "label": "docs"}]


def test_load_rules_missing_file_raises(tmp_path):
    with pytest.raises(LabelAssignerError, match="not found"):
        load_rules(tmp_path / "missing.json")


def test_load_rules_invalid_json_raises(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text("{not valid json")
    with pytest.raises(LabelAssignerError, match="invalid JSON"):
        load_rules(cfg)


def test_load_rules_missing_pattern_field_raises(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({"rules": [{"label": "docs"}]}))
    with pytest.raises(LabelAssignerError, match="pattern"):
        load_rules(cfg)


def test_load_rules_missing_label_field_raises(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({"rules": [{"pattern": "docs/**"}]}))
    with pytest.raises(LabelAssignerError, match="label"):
        load_rules(cfg)


def test_load_rules_top_level_must_have_rules_key(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps([{"pattern": "docs/**", "label": "docs"}]))
    with pytest.raises(LabelAssignerError, match="rules"):
        load_rules(cfg)


# ---------------------------------------------------------------------------
# CLI integration (end-to-end via subprocess).
# ---------------------------------------------------------------------------
def _write_files_json(path, files):
    path.write_text(json.dumps({"files": files}))


def _write_rules_json(path, rules):
    path.write_text(json.dumps({"rules": rules}))


def test_cli_outputs_labels_one_per_line(tmp_path):
    rules_file = tmp_path / "rules.json"
    files_file = tmp_path / "files.json"
    _write_rules_json(rules_file, [
        {"pattern": "docs/**", "label": "documentation"},
        {"pattern": "src/api/**", "label": "api"},
    ])
    _write_files_json(files_file, ["docs/a.md", "src/api/h.py"])

    result = subprocess.run(
        [sys.executable, str(ROOT / "pr_label_assigner.py"),
         "--rules", str(rules_file),
         "--files", str(files_file)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    lines = [ln for ln in result.stdout.strip().splitlines() if ln]
    assert sorted(lines) == ["api", "documentation"]


def test_cli_json_output_format(tmp_path):
    rules_file = tmp_path / "rules.json"
    files_file = tmp_path / "files.json"
    _write_rules_json(rules_file, [
        {"pattern": "docs/**", "label": "documentation"},
    ])
    _write_files_json(files_file, ["docs/a.md"])

    result = subprocess.run(
        [sys.executable, str(ROOT / "pr_label_assigner.py"),
         "--rules", str(rules_file),
         "--files", str(files_file),
         "--format", "json"],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload == {"labels": ["documentation"]}


def test_cli_handles_missing_rules_file_gracefully(tmp_path):
    files_file = tmp_path / "files.json"
    _write_files_json(files_file, ["docs/a.md"])

    result = subprocess.run(
        [sys.executable, str(ROOT / "pr_label_assigner.py"),
         "--rules", str(tmp_path / "missing.json"),
         "--files", str(files_file)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode != 0
    assert "not found" in result.stderr.lower()
