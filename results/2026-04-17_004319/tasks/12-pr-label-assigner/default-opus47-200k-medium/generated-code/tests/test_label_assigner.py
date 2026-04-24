# TDD tests for the PR label assigner.
# Each test below was added red-first: written to fail, then the
# implementation in label_assigner.py was extended just enough to pass.
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from label_assigner import assign_labels, load_rules, LabelRule  # noqa: E402


# --- Step 1 (red): a single rule matching a single file produces one label ---
def test_single_rule_single_file_yields_one_label():
    rules = [LabelRule(pattern="docs/**", label="documentation")]
    files = ["docs/intro.md"]
    assert assign_labels(files, rules) == ["documentation"]


# --- Step 2: multiple files, one matching label ---
def test_multiple_files_dedupes_label():
    rules = [LabelRule(pattern="docs/**", label="documentation")]
    files = ["docs/a.md", "docs/sub/b.md", "src/x.py"]
    assert assign_labels(files, rules) == ["documentation"]


# --- Step 3: a file matching multiple rules picks up multiple labels ---
def test_file_matches_multiple_rules():
    rules = [
        LabelRule(pattern="src/**", label="source"),
        LabelRule(pattern="*.test.*", label="tests"),
    ]
    files = ["src/foo.test.py"]
    out = assign_labels(files, rules)
    assert set(out) == {"source", "tests"}


# --- Step 4: glob patterns work for nested directories ---
def test_nested_glob_matching():
    rules = [LabelRule(pattern="src/api/**", label="api")]
    files = ["src/api/v1/users.py", "src/api/handlers/auth.py", "src/db/conn.py"]
    out = assign_labels(files, rules)
    assert out == ["api"]


# --- Step 5: priority ordering is preserved (lower priority value -> earlier) ---
def test_priority_ordering_in_output():
    rules = [
        LabelRule(pattern="*.test.*", label="tests", priority=2),
        LabelRule(pattern="src/**", label="source", priority=1),
        LabelRule(pattern="docs/**", label="documentation", priority=3),
    ]
    files = ["src/a.py", "src/b.test.py", "docs/readme.md"]
    out = assign_labels(files, rules)
    assert out == ["source", "tests", "documentation"]


# --- Step 6: no matches => empty list, not an error ---
def test_no_matching_rules_returns_empty():
    rules = [LabelRule(pattern="docs/**", label="documentation")]
    files = ["src/a.py"]
    assert assign_labels(files, rules) == []


# --- Step 7: load_rules parses a JSON config file ---
def test_load_rules_from_json(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
        ]
    }))
    rules = load_rules(str(cfg))
    assert len(rules) == 2
    assert rules[0].label == "documentation"
    assert rules[1].pattern == "src/api/**"


# --- Step 8: load_rules raises a clear error if the file is missing ---
def test_load_rules_missing_file_raises():
    with pytest.raises(FileNotFoundError) as exc:
        load_rules("/nonexistent/rules.json")
    assert "rules" in str(exc.value).lower() or "not found" in str(exc.value).lower()


# --- Step 9: load_rules raises on malformed JSON with a clear message ---
def test_load_rules_bad_json_raises(tmp_path):
    cfg = tmp_path / "bad.json"
    cfg.write_text("{not valid json")
    with pytest.raises(ValueError) as exc:
        load_rules(str(cfg))
    assert "json" in str(exc.value).lower()


# --- Step 10: CLI integration — runs the script end-to-end ---
def test_cli_outputs_labels(tmp_path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
            {"pattern": "*.test.*", "label": "tests", "priority": 3},
        ]
    }))
    files = tmp_path / "files.txt"
    files.write_text("docs/intro.md\nsrc/api/v1/users.py\nsrc/api/v1/users.test.py\n")

    result = subprocess.run(
        [sys.executable, str(ROOT / "label_assigner.py"),
         "--rules", str(cfg), "--files", str(files)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    out = result.stdout.strip().splitlines()
    # Order follows priority
    assert out == ["documentation", "api", "tests"]
