# Unit tests for the PR label assigner.
# Written TDD-style: each test drives a small piece of functionality.
import json
from pathlib import Path

import pytest

from label_assigner import (
    Rule,
    assign_labels,
    load_rules,
    matches,
)


# --- matching ---------------------------------------------------------------


def test_matches_exact_filename():
    assert matches("README.md", "README.md")


def test_matches_star_extension():
    assert matches("src/app.py", "*.py") is False  # *.py only matches bare name
    assert matches("app.py", "*.py")


def test_matches_double_star_directory():
    assert matches("docs/guide/intro.md", "docs/**")
    assert matches("docs/README.md", "docs/**")
    assert matches("src/README.md", "docs/**") is False


def test_matches_double_star_any_depth_middle():
    # **/ at start means any directory prefix
    assert matches("pkg/foo/bar.test.js", "**/*.test.*")
    assert matches("bar.test.js", "**/*.test.*")


def test_matches_single_star_is_single_segment():
    # * does not cross directory boundaries
    assert matches("src/api/users.py", "src/*/users.py")
    assert matches("src/api/v1/users.py", "src/*/users.py") is False


# --- rule loading -----------------------------------------------------------


def test_load_rules_from_json(tmp_path: Path):
    cfg = tmp_path / "rules.json"
    cfg.write_text(
        json.dumps(
            {
                "rules": [
                    {"pattern": "docs/**", "labels": ["documentation"]},
                    {"pattern": "src/api/**", "labels": ["api"], "priority": 10},
                ]
            }
        )
    )
    rules = load_rules(cfg)
    assert len(rules) == 2
    assert rules[0].pattern == "docs/**"
    assert rules[0].labels == ["documentation"]
    assert rules[0].priority == 0  # default
    assert rules[1].priority == 10


def test_load_rules_missing_file(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        load_rules(tmp_path / "nope.json")


def test_load_rules_invalid_json(tmp_path: Path):
    cfg = tmp_path / "bad.json"
    cfg.write_text("not json{")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_rules(cfg)


def test_load_rules_missing_pattern_field(tmp_path: Path):
    cfg = tmp_path / "bad.json"
    cfg.write_text(json.dumps({"rules": [{"labels": ["x"]}]}))
    with pytest.raises(ValueError, match="pattern"):
        load_rules(cfg)


def test_load_rules_missing_labels_field(tmp_path: Path):
    cfg = tmp_path / "bad.json"
    cfg.write_text(json.dumps({"rules": [{"pattern": "*.py"}]}))
    with pytest.raises(ValueError, match="labels"):
        load_rules(cfg)


# --- label assignment -------------------------------------------------------


def test_assign_labels_single_rule_single_file():
    rules = [Rule(pattern="docs/**", labels=["documentation"])]
    assert assign_labels(["docs/README.md"], rules) == ["documentation"]


def test_assign_labels_no_match_returns_empty():
    rules = [Rule(pattern="docs/**", labels=["documentation"])]
    assert assign_labels(["src/main.py"], rules) == []


def test_assign_labels_multiple_rules_accumulate():
    rules = [
        Rule(pattern="docs/**", labels=["documentation"]),
        Rule(pattern="src/api/**", labels=["api"]),
    ]
    files = ["docs/README.md", "src/api/users.py"]
    assert sorted(assign_labels(files, rules)) == ["api", "documentation"]


def test_assign_labels_deduplicates():
    # Two files each matching the same rule should yield one label.
    rules = [Rule(pattern="docs/**", labels=["documentation"])]
    files = ["docs/a.md", "docs/b.md"]
    assert assign_labels(files, rules) == ["documentation"]


def test_assign_labels_rule_can_emit_multiple_labels():
    rules = [Rule(pattern="src/api/**", labels=["api", "backend"])]
    assert sorted(assign_labels(["src/api/users.py"], rules)) == ["api", "backend"]


def test_assign_labels_one_file_matches_multiple_rules():
    rules = [
        Rule(pattern="src/**", labels=["source"]),
        Rule(pattern="**/*.test.*", labels=["tests"]),
    ]
    assert sorted(assign_labels(["src/foo.test.js"], rules)) == ["source", "tests"]


def test_assign_labels_priority_orders_output():
    # Higher priority labels appear first.
    rules = [
        Rule(pattern="docs/**", labels=["documentation"], priority=1),
        Rule(pattern="src/api/**", labels=["api"], priority=10),
        Rule(pattern="*.test.*", labels=["tests"], priority=5),
    ]
    files = ["docs/a.md", "src/api/x.py", "x.test.js"]
    # Sorted by priority desc, then alphabetical on ties.
    assert assign_labels(files, rules) == ["api", "tests", "documentation"]


def test_assign_labels_priority_conflict_resolution():
    # When the same label comes from rules with different priorities,
    # the highest priority wins for ordering purposes.
    rules = [
        Rule(pattern="**/*.py", labels=["python"], priority=1),
        Rule(pattern="src/api/**", labels=["python"], priority=50),
        Rule(pattern="docs/**", labels=["docs"], priority=5),
    ]
    files = ["src/api/x.py", "docs/a.md"]
    assert assign_labels(files, rules) == ["python", "docs"]


def test_assign_labels_alphabetical_on_equal_priority():
    rules = [
        Rule(pattern="**/*.py", labels=["zeta"], priority=5),
        Rule(pattern="**/*.py", labels=["alpha"], priority=5),
    ]
    assert assign_labels(["x.py"], rules) == ["alpha", "zeta"]


def test_assign_labels_empty_files_list():
    rules = [Rule(pattern="docs/**", labels=["documentation"])]
    assert assign_labels([], rules) == []


def test_assign_labels_empty_rules_list():
    assert assign_labels(["foo.py"], []) == []
