"""
TDD tests for PR label assigner.
Red/Green methodology: each test was written to fail first,
then minimum code was added to make it pass.
"""

import pytest
import json
from label_assigner import assign_labels, load_config, LabelConfig, LabelRule


# ============================================================
# Test 1 (RED): Basic single rule matching
# ============================================================
def test_single_rule_docs():
    """A file in docs/ should get the 'documentation' label."""
    rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
    files = ["docs/README.md"]
    labels = assign_labels(files, rules)
    assert "documentation" in labels


# ============================================================
# Test 2 (RED): No match returns empty set
# ============================================================
def test_no_match_returns_empty():
    """Files that don't match any rule should return no labels."""
    rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
    files = ["src/main.py"]
    labels = assign_labels(files, rules)
    assert labels == set()


# ============================================================
# Test 3 (RED): Multiple labels from multiple rules
# ============================================================
def test_multiple_rules_multiple_labels():
    """A PR with docs and src files should get both labels."""
    rules = [
        LabelRule(pattern="docs/**", label="documentation", priority=1),
        LabelRule(pattern="src/**", label="backend", priority=1),
    ]
    files = ["docs/api.md", "src/server.py"]
    labels = assign_labels(files, rules)
    assert labels == {"documentation", "backend"}


# ============================================================
# Test 4 (RED): One file matching multiple rules
# ============================================================
def test_one_file_multiple_rules():
    """A test file in src/ should get both 'backend' and 'tests' labels."""
    rules = [
        LabelRule(pattern="src/**", label="backend", priority=1),
        LabelRule(pattern="*.test.*", label="tests", priority=1),
    ]
    files = ["src/server.test.py"]
    labels = assign_labels(files, rules)
    assert "backend" in labels
    assert "tests" in labels


# ============================================================
# Test 5 (RED): Priority ordering - higher priority wins conflict
# ============================================================
def test_priority_ordering():
    """
    When two rules conflict (same file, same conceptual slot),
    lower priority number = higher priority. The result should
    still contain both labels since each rule adds its label.
    Priority affects ordering when reporting, not exclusion.

    But if we have an exclusive mode, higher priority wins.
    Here we test that priority is respected in output ordering.
    """
    rules = [
        LabelRule(pattern="src/api/**", label="api", priority=1),
        LabelRule(pattern="src/**", label="backend", priority=2),
    ]
    files = ["src/api/routes.py"]
    labels = assign_labels(files, rules)
    # Both labels apply - priority just affects order
    assert "api" in labels
    assert "backend" in labels


# ============================================================
# Test 6 (RED): Glob pattern *.test.* matches test files
# ============================================================
def test_glob_test_pattern():
    """Files matching *.test.* should get 'tests' label."""
    rules = [LabelRule(pattern="*.test.*", label="tests", priority=1)]
    files = ["MyComponent.test.tsx", "utils.test.js", "server.test.py"]
    labels = assign_labels(files, rules)
    assert "tests" in labels


# ============================================================
# Test 7 (RED): Glob pattern ** works across directories
# ============================================================
def test_double_star_glob():
    """src/api/** should match deeply nested files."""
    rules = [LabelRule(pattern="src/api/**", label="api", priority=1)]
    files = ["src/api/v2/routes/users.py"]
    labels = assign_labels(files, rules)
    assert "api" in labels


# ============================================================
# Test 8 (RED): Load config from dict
# ============================================================
def test_load_config_from_dict():
    """Config loading should produce LabelRule objects."""
    config_dict = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
        ]
    }
    config = load_config(config_dict)
    assert len(config.rules) == 2
    assert config.rules[0].label == "documentation"
    assert config.rules[1].label == "api"


# ============================================================
# Test 9 (RED): Full pipeline with config
# ============================================================
def test_full_pipeline_with_config():
    """End-to-end test: config + files -> labels."""
    config_dict = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
            {"pattern": "src/**", "label": "backend", "priority": 3},
            {"pattern": "*.test.*", "label": "tests", "priority": 4},
            {"pattern": "*.md", "label": "documentation", "priority": 5},
        ]
    }
    config = load_config(config_dict)
    files = [
        "docs/getting-started.md",
        "src/api/users.py",
        "src/utils/helper.test.py",
        "README.md",
    ]
    labels = assign_labels(files, config.rules)
    assert "documentation" in labels
    assert "api" in labels
    assert "backend" in labels
    assert "tests" in labels


# ============================================================
# Test 10 (RED): Empty file list returns empty labels
# ============================================================
def test_empty_file_list():
    """Empty file list should return no labels."""
    rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
    labels = assign_labels([], rules)
    assert labels == set()


# ============================================================
# Test 11 (RED): Empty rules returns empty labels
# ============================================================
def test_empty_rules():
    """No rules should return no labels."""
    labels = assign_labels(["docs/README.md"], [])
    assert labels == set()


# ============================================================
# Test 12 (RED): Duplicate labels are deduplicated
# ============================================================
def test_deduplication():
    """Multiple files matching same rule should yield one label."""
    rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
    files = ["docs/README.md", "docs/api.md", "docs/guide.md"]
    labels = assign_labels(files, rules)
    assert labels == {"documentation"}


# ============================================================
# Test 13 (RED): Case-sensitive matching
# ============================================================
def test_case_sensitive_matching():
    """Pattern matching should be case-sensitive."""
    rules = [LabelRule(pattern="DOCS/**", label="documentation", priority=1)]
    files = ["docs/README.md"]
    labels = assign_labels(files, rules)
    # 'docs' != 'DOCS' -> no match
    assert "documentation" not in labels


# ============================================================
# Test 14 (RED): Priority is sorted correctly in output
# ============================================================
def test_priority_sorted_output():
    """assign_labels_sorted returns labels in priority order."""
    from label_assigner import assign_labels_sorted
    rules = [
        LabelRule(pattern="*.test.*", label="tests", priority=3),
        LabelRule(pattern="docs/**", label="documentation", priority=1),
        LabelRule(pattern="src/**", label="backend", priority=2),
    ]
    files = ["docs/guide.md", "src/app.test.py"]
    ordered = assign_labels_sorted(files, rules)
    # documentation (priority 1) should come before backend (2) and tests (3)
    assert ordered.index("documentation") < ordered.index("tests")


# ============================================================
# Test 15 (RED): Config validation - invalid priority raises error
# ============================================================
def test_config_validation_invalid_priority():
    """Priority must be a positive integer."""
    config_dict = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": -1},
        ]
    }
    with pytest.raises(ValueError, match="priority"):
        load_config(config_dict)


# ============================================================
# Test 16 (RED): Config validation - missing pattern raises error
# ============================================================
def test_config_validation_missing_pattern():
    """Rules must have a pattern field."""
    config_dict = {
        "rules": [
            {"label": "documentation", "priority": 1},
        ]
    }
    with pytest.raises((ValueError, KeyError)):
        load_config(config_dict)


# ============================================================
# Test 17 (RED): Mock PR fixture test
# ============================================================
def test_mock_pr_fixture():
    """Test with a realistic mock PR file list."""
    # This simulates a PR that touches API docs, backend code, and tests
    mock_pr_files = [
        "src/api/v1/users.py",
        "src/api/v1/orders.py",
        "src/models/user.py",
        "tests/test_users.py",
        "docs/api/users.md",
        "README.md",
    ]
    config_dict = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "*.md", "label": "documentation", "priority": 2},
            {"pattern": "src/api/**", "label": "api", "priority": 3},
            {"pattern": "src/**", "label": "backend", "priority": 4},
            {"pattern": "tests/**", "label": "tests", "priority": 5},
            {"pattern": "*.test.*", "label": "tests", "priority": 6},
        ]
    }
    config = load_config(config_dict)
    labels = assign_labels(mock_pr_files, config.rules)
    assert "documentation" in labels
    assert "api" in labels
    assert "backend" in labels
    assert "tests" in labels


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
