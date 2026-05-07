"""Unit tests for the PR label assigner.

Built via red/green TDD. Each test was written failing first, then the
minimum production code added to make it pass.
"""
import json
from pathlib import Path

import pytest

from label_assigner import (
    LabelRule,
    LabelAssignerError,
    assign_labels,
    load_rules,
    main,
)


# --- Test 1: basic single-pattern match ---------------------------------
def test_single_rule_matches_one_file():
    rules = [LabelRule(pattern="docs/**", label="documentation")]
    files = ["docs/intro.md"]
    assert assign_labels(rules, files) == ["documentation"]


# --- Test 2: no match yields empty list ---------------------------------
def test_no_match_returns_empty():
    rules = [LabelRule(pattern="docs/**", label="documentation")]
    files = ["src/main.py"]
    assert assign_labels(rules, files) == []


# --- Test 3: multiple rules, multiple labels (deduplicated, sorted) -----
def test_multiple_rules_dedup_sorted():
    rules = [
        LabelRule(pattern="docs/**", label="documentation"),
        LabelRule(pattern="src/api/**", label="api"),
    ]
    files = ["docs/a.md", "docs/b.md", "src/api/users.py"]
    # docs label appears twice from two files but must be deduped
    assert assign_labels(rules, files) == ["api", "documentation"]


# --- Test 4: a single file can earn multiple labels ---------------------
def test_one_file_multiple_labels():
    rules = [
        LabelRule(pattern="src/api/**", label="api"),
        LabelRule(pattern="**/*.py", label="python"),
    ]
    files = ["src/api/users.py"]
    assert assign_labels(rules, files) == ["api", "python"]


# --- Test 5: glob handles *.test.* style patterns -----------------------
def test_test_file_glob():
    rules = [LabelRule(pattern="**/*.test.*", label="tests")]
    files = ["src/foo.test.js", "src/foo.js"]
    assert assign_labels(rules, files) == ["tests"]


# --- Test 6: priority — when conflicting rules match same file, highest
# priority wins, and the loser's label is suppressed for that file ------
def test_priority_conflict_resolution():
    # Two rules both match the same file; they belong to the same conflict
    # *group* (both tagged group="layer"). The rule with the higher priority
    # number wins, and its label is the only one applied for files in that
    # group.
    rules = [
        LabelRule(pattern="src/**", label="backend", group="layer", priority=1),
        LabelRule(pattern="src/api/**", label="api", group="layer", priority=10),
    ]
    files = ["src/api/users.py"]
    # api wins because its priority is higher; backend is suppressed for
    # this file even though its pattern also matches.
    assert assign_labels(rules, files) == ["api"]


# --- Test 7: priority only suppresses inside the same group -------------
def test_priority_only_within_group():
    rules = [
        LabelRule(pattern="src/**", label="backend", group="layer", priority=1),
        LabelRule(pattern="src/api/**", label="api", group="layer", priority=10),
        LabelRule(pattern="**/*.py", label="python"),  # no group => independent
    ]
    files = ["src/api/users.py"]
    assert assign_labels(rules, files) == ["api", "python"]


# --- Test 8: load_rules from a JSON config file -------------------------
def test_load_rules_from_json(tmp_path: Path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({
        "rules": [
            {"pattern": "docs/**", "label": "documentation"},
            {"pattern": "src/api/**", "label": "api",
             "group": "layer", "priority": 10},
        ]
    }))
    rules = load_rules(str(cfg))
    assert len(rules) == 2
    assert rules[0].pattern == "docs/**"
    assert rules[0].label == "documentation"
    assert rules[1].priority == 10
    assert rules[1].group == "layer"


# --- Test 9: load_rules from a YAML config file -------------------------
def test_load_rules_from_yaml(tmp_path: Path):
    cfg = tmp_path / "rules.yaml"
    cfg.write_text(
        "rules:\n"
        "  - pattern: 'docs/**'\n"
        "    label: documentation\n"
        "  - pattern: 'src/api/**'\n"
        "    label: api\n"
        "    group: layer\n"
        "    priority: 10\n"
    )
    rules = load_rules(str(cfg))
    assert [r.label for r in rules] == ["documentation", "api"]
    assert rules[1].group == "layer"
    assert rules[1].priority == 10


# --- Test 10: malformed config file gives a meaningful error ------------
def test_load_rules_missing_file():
    with pytest.raises(LabelAssignerError, match="not found"):
        load_rules("/nonexistent/path/rules.json")


def test_load_rules_invalid_schema(tmp_path: Path):
    cfg = tmp_path / "bad.json"
    cfg.write_text(json.dumps({"rules": [{"label": "oops"}]}))  # no pattern
    with pytest.raises(LabelAssignerError, match="pattern"):
        load_rules(str(cfg))


def test_load_rules_unknown_extension(tmp_path: Path):
    cfg = tmp_path / "rules.txt"
    cfg.write_text("hello")
    with pytest.raises(LabelAssignerError, match="extension"):
        load_rules(str(cfg))


# --- Test 11: main() — end-to-end CLI behavior --------------------------
def test_main_prints_labels(tmp_path: Path, capsys):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({
        "rules": [
            {"pattern": "docs/**", "label": "documentation"},
            {"pattern": "**/*.py", "label": "python"},
        ]
    }))
    files_file = tmp_path / "files.txt"
    files_file.write_text("docs/a.md\nsrc/b.py\n")

    rc = main(["--rules", str(cfg), "--files", str(files_file)])
    out = capsys.readouterr().out

    assert rc == 0
    # main prints one label per line, sorted, plus a JSON summary line
    lines = out.strip().splitlines()
    assert "documentation" in lines
    assert "python" in lines
    # summary line begins with LABELS_JSON= and is parseable
    summary = [l for l in lines if l.startswith("LABELS_JSON=")][0]
    payload = json.loads(summary[len("LABELS_JSON="):])
    assert payload == ["documentation", "python"]


def test_main_handles_missing_rules_file(tmp_path: Path, capsys):
    files_file = tmp_path / "files.txt"
    files_file.write_text("a.md\n")
    rc = main(["--rules", "/no/such/file.json", "--files", str(files_file)])
    err = capsys.readouterr().err
    assert rc != 0
    assert "not found" in err or "error" in err.lower()


# --- Test 12: empty files list returns no labels -----------------------
def test_empty_files_list():
    rules = [LabelRule(pattern="**/*", label="any")]
    assert assign_labels(rules, []) == []


# --- Test 13: blank lines / whitespace in the files file are ignored ---
def test_main_ignores_blank_lines(tmp_path: Path, capsys):
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps({"rules": [
        {"pattern": "**/*.py", "label": "python"},
    ]}))
    files_file = tmp_path / "files.txt"
    files_file.write_text("\n  src/a.py  \n\n\n")
    rc = main(["--rules", str(cfg), "--files", str(files_file)])
    out = capsys.readouterr().out
    assert rc == 0
    summary = [l for l in out.splitlines() if l.startswith("LABELS_JSON=")][0]
    assert json.loads(summary[len("LABELS_JSON="):]) == ["python"]
