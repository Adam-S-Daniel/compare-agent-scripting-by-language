# TDD tests for PR label assigner
# Red/green cycle: write failing test, implement minimum code, refactor
import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ---- CYCLE 1: single rule, single file match ----
# RED: This fails because label_assigner doesn't exist yet
def test_single_rule_matches_docs_file():
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    files = ["docs/README.md"]
    assert assign_labels(files, rules) == {"documentation"}


# ---- CYCLE 2: no match returns empty set ----
def test_no_match_returns_empty():
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    files = ["src/main.py"]
    assert assign_labels(files, rules) == set()


# ---- CYCLE 3: multiple rules, multiple labels ----
def test_multiple_rules_produce_multiple_labels():
    from label_assigner import assign_labels
    rules = [
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
        {"pattern": "src/api/**", "label": "api", "priority": 2},
    ]
    files = ["docs/intro.md", "src/api/routes.py"]
    assert assign_labels(files, rules) == {"documentation", "api"}


# ---- CYCLE 4: glob wildcard *.test.* pattern ----
def test_test_file_pattern():
    from label_assigner import assign_labels
    rules = [{"pattern": "*.test.*", "label": "tests", "priority": 1}]
    files = ["app.test.js", "utils.test.ts"]
    assert assign_labels(files, rules) == {"tests"}


# ---- CYCLE 5: one file matches multiple rules -> multiple labels ----
def test_one_file_matches_multiple_rules():
    from label_assigner import assign_labels
    rules = [
        {"pattern": "src/**", "label": "source", "priority": 1},
        {"pattern": "src/api/**", "label": "api", "priority": 2},
    ]
    files = ["src/api/handler.py"]
    assert assign_labels(files, rules) == {"source", "api"}


# ---- CYCLE 6: priority ordering - highest priority label wins when conflicting ----
# When two rules match and both produce a "type" label, only the highest-priority one applies.
# "Conflict" means two rules assign the same label slot (defined by priority group).
# Here we test that rules are processed in priority order (lowest number = highest priority).
def test_priority_order_is_respected():
    from label_assigner import assign_labels
    # priority 1 (highest) matches first, priority 3 (lowest) matches last
    rules = [
        {"pattern": "src/**", "label": "backend", "priority": 3},
        {"pattern": "src/api/**", "label": "api-high-prio", "priority": 1},
    ]
    files = ["src/api/v2.py"]
    labels = assign_labels(files, rules)
    # Both should match; priority just determines ordering, all labels are returned
    assert "api-high-prio" in labels
    assert "backend" in labels


# ---- CYCLE 7: load config from JSON file ----
def test_load_rules_from_json(tmp_path):
    import json
    from label_assigner import load_rules, assign_labels
    config = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "*.md", "label": "markdown", "priority": 2},
        ]
    }
    config_file = tmp_path / "labels.json"
    config_file.write_text(json.dumps(config))
    rules = load_rules(str(config_file))
    assert len(rules) == 2
    labels = assign_labels(["docs/guide.md"], rules)
    assert "documentation" in labels


# ---- CYCLE 8: missing config file raises meaningful error ----
def test_missing_config_raises_error():
    from label_assigner import load_rules
    with pytest.raises(FileNotFoundError, match="Config file not found"):
        load_rules("/nonexistent/path/labels.json")


# ---- CYCLE 9: invalid JSON in config raises meaningful error ----
def test_invalid_json_raises_error(tmp_path):
    from label_assigner import load_rules
    bad_file = tmp_path / "bad.json"
    bad_file.write_text("{ not valid json }")
    with pytest.raises(ValueError, match="Invalid JSON"):
        load_rules(str(bad_file))


# ---- CYCLE 10: deep glob pattern (multiple directory levels) ----
def test_deep_glob_pattern():
    from label_assigner import assign_labels
    rules = [{"pattern": "src/**/*.py", "label": "python", "priority": 1}]
    files = ["src/services/auth/login.py", "src/utils/helpers.py"]
    assert assign_labels(files, rules) == {"python"}


# ---- CYCLE 11: case-sensitive matching ----
def test_case_sensitive_matching():
    from label_assigner import assign_labels
    rules = [{"pattern": "Docs/**", "label": "documentation", "priority": 1}]
    files = ["docs/readme.md"]
    # "docs" != "Docs" - case sensitive
    assert assign_labels(files, rules) == set()


# ---- CYCLE 12: mixed file list produces correct label set ----
def test_mixed_file_list():
    from label_assigner import assign_labels
    rules = [
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
        {"pattern": "src/api/**", "label": "api", "priority": 2},
        {"pattern": "*.test.*", "label": "tests", "priority": 3},
        {"pattern": "src/**", "label": "source", "priority": 4},
    ]
    files = [
        "docs/installation.md",
        "src/api/endpoints.py",
        "src/utils/helper.test.js",
        "src/models/user.py",
    ]
    labels = assign_labels(files, rules)
    assert labels == {"documentation", "api", "tests", "source"}


# ---- CYCLE 13: empty file list returns empty set ----
def test_empty_file_list():
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    assert assign_labels([], rules) == set()


# ---- CYCLE 14: empty rules list returns empty set ----
def test_empty_rules_list():
    from label_assigner import assign_labels
    assert assign_labels(["src/main.py"], []) == set()


# ---- CYCLE 15: get_sorted_labels returns labels in priority order ----
def test_get_sorted_labels_priority_order():
    from label_assigner import assign_labels_with_priority
    rules = [
        {"pattern": "src/**", "label": "source", "priority": 3},
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
        {"pattern": "*.test.*", "label": "tests", "priority": 2},
    ]
    files = ["docs/guide.md", "src/main.py", "app.test.js"]
    result = assign_labels_with_priority(files, rules)
    # Labels sorted by their rule's minimum priority (ascending = highest priority first)
    assert result[0]["label"] == "documentation"
    assert result[1]["label"] == "tests"
    assert result[2]["label"] == "source"
