"""TDD tests for the PR label assigner."""
import json
import subprocess
import sys
from pathlib import Path

import pytest

from label_assigner import assign_labels, load_rules, main


# Fixture: sample rules used across tests. Rules carry an explicit priority so
# we can deterministically order labels in the final output.
SAMPLE_RULES = [
    {"pattern": "docs/**", "label": "documentation", "priority": 10},
    {"pattern": "src/api/**", "label": "api", "priority": 20},
    {"pattern": "**/*.test.*", "label": "tests", "priority": 30},
    {"pattern": "**/*.md", "label": "documentation", "priority": 10},
    {"pattern": "src/**", "label": "backend", "priority": 5},
]


def test_no_files_yields_no_labels():
    assert assign_labels([], SAMPLE_RULES) == []


def test_single_file_matches_single_rule():
    assert assign_labels(["docs/intro.md"], SAMPLE_RULES) == ["documentation"]


def test_glob_double_star_matches_nested():
    assert "api" in assign_labels(["src/api/v1/users.py"], SAMPLE_RULES)


def test_file_can_match_multiple_labels():
    # src/api/users.test.py matches src/api/** (api), **/*.test.* (tests),
    # and src/** (backend) — all three labels should be present.
    labels = assign_labels(["src/api/users.test.py"], SAMPLE_RULES)
    assert set(labels) == {"api", "tests", "backend"}


def test_labels_are_deduplicated_across_files():
    files = ["docs/a.md", "docs/b.md", "README.md"]
    assert assign_labels(files, SAMPLE_RULES) == ["documentation"]


def test_labels_are_sorted_by_priority_descending():
    # tests=30, api=20, backend=5 → tests first, backend last.
    files = ["src/api/users.test.py"]
    assert assign_labels(files, SAMPLE_RULES) == ["tests", "api", "backend"]


def test_load_rules_from_yaml_file(tmp_path):
    cfg = tmp_path / "rules.yml"
    cfg.write_text(
        "- pattern: 'docs/**'\n  label: documentation\n  priority: 10\n"
        "- pattern: 'src/**'\n  label: backend\n  priority: 5\n"
    )
    rules = load_rules(str(cfg))
    assert rules[0]["label"] == "documentation"
    assert rules[1]["priority"] == 5


def test_load_rules_missing_file_raises():
    with pytest.raises(FileNotFoundError, match="rules file"):
        load_rules("/nonexistent/rules.yml")


def test_load_rules_invalid_entry_raises(tmp_path):
    cfg = tmp_path / "bad.yml"
    cfg.write_text("- pattern: 'docs/**'\n")  # missing label
    with pytest.raises(ValueError, match="label"):
        load_rules(str(cfg))


def test_main_cli_outputs_labels(tmp_path, capsys, monkeypatch):
    rules_file = tmp_path / "rules.yml"
    rules_file.write_text(
        "- pattern: 'docs/**'\n  label: documentation\n  priority: 10\n"
        "- pattern: 'src/api/**'\n  label: api\n  priority: 20\n"
    )
    files_file = tmp_path / "files.txt"
    files_file.write_text("docs/intro.md\nsrc/api/v1.py\n")

    rc = main(["--rules", str(rules_file), "--files", str(files_file)])
    captured = capsys.readouterr()
    assert rc == 0
    payload = json.loads(captured.out)
    assert payload["labels"] == ["api", "documentation"]


def test_main_handles_missing_rules_gracefully(capsys):
    rc = main(["--rules", "/nope.yml", "--files", "/dev/null"])
    captured = capsys.readouterr()
    assert rc != 0
    assert "rules file" in captured.err
