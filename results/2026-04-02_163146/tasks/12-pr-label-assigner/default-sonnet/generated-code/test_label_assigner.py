"""
TDD tests for PR Label Assigner.

Red/Green cycle:
1. Write failing test
2. Write minimum code to pass
3. Refactor
"""

import pytest
from label_assigner import assign_labels, LabelRule, LabelConfig


class TestGlobMatching:
    """Test that individual glob patterns match file paths correctly."""

    def test_docs_glob_matches_docs_file(self):
        # RED: This test fails until we implement glob matching
        rule = LabelRule(pattern="docs/**", label="documentation")
        assert rule.matches("docs/README.md") is True

    def test_docs_glob_does_not_match_src_file(self):
        rule = LabelRule(pattern="docs/**", label="documentation")
        assert rule.matches("src/main.py") is False

    def test_wildcard_extension_matches_test_file(self):
        # *.test.* should match files like foo.test.js, bar.test.py
        rule = LabelRule(pattern="*.test.*", label="tests")
        assert rule.matches("foo.test.js") is True

    def test_wildcard_extension_matches_nested_test_file(self):
        # **/*.test.* should match nested test files
        rule = LabelRule(pattern="**/*.test.*", label="tests")
        assert rule.matches("src/components/Button.test.tsx") is True

    def test_api_glob_matches_api_file(self):
        rule = LabelRule(pattern="src/api/**", label="api")
        assert rule.matches("src/api/users.py") is True

    def test_api_glob_does_not_match_other_src(self):
        rule = LabelRule(pattern="src/api/**", label="api")
        assert rule.matches("src/utils/helpers.py") is False


class TestSingleFileLabeling:
    """Test labeling a single file against a config."""

    def test_docs_file_gets_documentation_label(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="docs/**", label="documentation", priority=1),
        ])
        labels = assign_labels(["docs/guide.md"], config)
        assert "documentation" in labels

    def test_src_api_file_gets_api_label(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="src/api/**", label="api", priority=1),
        ])
        labels = assign_labels(["src/api/routes.py"], config)
        assert "api" in labels

    def test_non_matching_file_gets_no_labels(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="docs/**", label="documentation", priority=1),
        ])
        labels = assign_labels(["src/main.py"], config)
        assert len(labels) == 0


class TestMultipleFilesLabeling:
    """Test that multiple files across different categories produce correct label sets."""

    def test_multiple_files_collect_all_matching_labels(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="docs/**", label="documentation", priority=1),
            LabelRule(pattern="src/api/**", label="api", priority=2),
        ])
        files = ["docs/README.md", "src/api/users.py"]
        labels = assign_labels(files, config)
        assert "documentation" in labels
        assert "api" in labels

    def test_duplicate_labels_are_deduplicated(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="docs/**", label="documentation", priority=1),
        ])
        files = ["docs/README.md", "docs/guide.md"]
        labels = assign_labels(files, config)
        # Should only appear once even though two files matched
        assert labels.count("documentation") == 1

    def test_multiple_labels_per_file(self):
        # A test file in docs should get both 'documentation' and 'tests' labels
        config = LabelConfig(rules=[
            LabelRule(pattern="docs/**", label="documentation", priority=1),
            LabelRule(pattern="**/*.test.*", label="tests", priority=2),
        ])
        files = ["docs/component.test.md"]
        labels = assign_labels(files, config)
        assert "documentation" in labels
        assert "tests" in labels


class TestPriorityOrdering:
    """Test priority ordering when rules conflict."""

    def test_higher_priority_rule_wins_when_exclusive(self):
        # When exclusive=True and multiple rules match, only highest priority applies
        config = LabelConfig(rules=[
            LabelRule(pattern="src/**", label="source", priority=1),
            LabelRule(pattern="src/api/**", label="api", priority=2),
        ], exclusive=True)
        files = ["src/api/routes.py"]
        labels = assign_labels(files, config)
        # priority=2 is higher, so "api" wins over "source"
        assert "api" in labels
        assert "source" not in labels

    def test_non_exclusive_config_applies_all_matching_rules(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="src/**", label="source", priority=1),
            LabelRule(pattern="src/api/**", label="api", priority=2),
        ], exclusive=False)
        files = ["src/api/routes.py"]
        labels = assign_labels(files, config)
        assert "api" in labels
        assert "source" in labels

    def test_labels_ordered_by_priority(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="src/**", label="source", priority=1),
            LabelRule(pattern="src/api/**", label="api", priority=10),
            LabelRule(pattern="**/*.test.*", label="tests", priority=5),
        ])
        files = ["src/api/foo.test.py"]
        labels = assign_labels(files, config)
        # All three match; verify order reflects priority descending
        assert labels.index("api") < labels.index("tests")
        assert labels.index("tests") < labels.index("source")


class TestMockedPRScenarios:
    """Integration tests using realistic mock PR file lists."""

    def test_frontend_pr(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="src/components/**", label="frontend", priority=3),
            LabelRule(pattern="**/*.test.*", label="tests", priority=2),
            LabelRule(pattern="docs/**", label="documentation", priority=1),
        ])
        # Simulated PR: adds a React component + its test
        pr_files = [
            "src/components/Button.tsx",
            "src/components/Button.test.tsx",
        ]
        labels = assign_labels(pr_files, config)
        assert "frontend" in labels
        assert "tests" in labels
        assert "documentation" not in labels

    def test_backend_api_pr(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="src/api/**", label="api", priority=3),
            LabelRule(pattern="**/*.test.*", label="tests", priority=2),
            LabelRule(pattern="docs/**", label="documentation", priority=1),
        ])
        pr_files = [
            "src/api/users.py",
            "src/api/auth.py",
            "src/api/test_users.py",
            "docs/api-reference.md",
        ]
        labels = assign_labels(pr_files, config)
        assert "api" in labels
        assert "documentation" in labels

    def test_empty_file_list_returns_empty_labels(self):
        config = LabelConfig(rules=[
            LabelRule(pattern="docs/**", label="documentation", priority=1),
        ])
        labels = assign_labels([], config)
        assert labels == []

    def test_no_rules_returns_empty_labels(self):
        config = LabelConfig(rules=[])
        labels = assign_labels(["src/main.py"], config)
        assert labels == []


class TestErrorHandling:
    """Test graceful error handling."""

    def test_invalid_glob_pattern_raises_value_error(self):
        with pytest.raises(ValueError, match="Invalid glob pattern"):
            LabelRule(pattern="[invalid", label="bad")

    def test_empty_label_raises_value_error(self):
        with pytest.raises(ValueError, match="Label cannot be empty"):
            LabelRule(pattern="docs/**", label="")

    def test_empty_pattern_raises_value_error(self):
        with pytest.raises(ValueError, match="Pattern cannot be empty"):
            LabelRule(pattern="", label="docs")
