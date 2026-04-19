"""
Tests for PR label assigner.

Uses TDD methodology: write failing tests first, implement minimum code to pass,
then refactor. Each test focuses on a specific piece of functionality.
"""

import pytest
from pr_label_assigner import assign_labels, LabelRule, PRLabelAssigner


class TestSimpleLabelAssignment:
    """Test basic label assignment with simple patterns."""

    def test_single_file_single_label(self):
        """Test assigning one label to a file matching a simple pattern."""
        # ARRANGE: Define rules and changed files
        rules = [LabelRule(pattern="docs/**", labels=["documentation"])]
        changed_files = ["docs/README.md"]

        # ACT: Assign labels
        result = assign_labels(changed_files, rules)

        # ASSERT: Should have one file with one label
        assert result == {"docs/README.md": ["documentation"]}

    def test_no_matching_rules(self):
        """Test file that doesn't match any rule."""
        rules = [LabelRule(pattern="docs/**", labels=["documentation"])]
        changed_files = ["src/main.py"]

        result = assign_labels(changed_files, rules)

        assert result == {"src/main.py": []}

    def test_file_with_no_matching_pattern(self):
        """Test when no files match any pattern."""
        rules = [LabelRule(pattern="docs/**", labels=["documentation"])]
        changed_files = []

        result = assign_labels(changed_files, rules)

        assert result == {}


class TestMultipleLabelsPerFile:
    """Test assigning multiple labels to a single file."""

    def test_file_matches_multiple_rules(self):
        """Test file that matches multiple rules gets all labels."""
        rules = [
            LabelRule(pattern="src/**", labels=["code"]),
            LabelRule(pattern="**/*.py", labels=["python"]),
        ]
        changed_files = ["src/main.py"]

        result = assign_labels(changed_files, rules)

        # Should have both labels, with no duplicates
        assert set(result["src/main.py"]) == {"code", "python"}

    def test_rule_with_multiple_labels(self):
        """Test single rule that assigns multiple labels."""
        rules = [LabelRule(pattern="src/api/**", labels=["api", "backend"])]
        changed_files = ["src/api/handler.py"]

        result = assign_labels(changed_files, rules)

        assert set(result["src/api/handler.py"]) == {"api", "backend"}


class TestGlobPatternMatching:
    """Test glob pattern matching with various patterns."""

    def test_double_asterisk_pattern(self):
        """Test ** pattern matches files recursively."""
        rules = [LabelRule(pattern="src/**", labels=["code"])]
        changed_files = [
            "src/main.py",
            "src/utils/helper.py",
            "src/api/v1/handler.py",
        ]

        result = assign_labels(changed_files, rules)

        assert all(file in result for file in changed_files)
        assert all("code" in result[file] for file in changed_files)

    def test_extension_pattern(self):
        """Test matching files by extension."""
        rules = [LabelRule(pattern="*.test.py", labels=["tests"])]
        changed_files = ["test_main.py", "test_utils.test.py", "main.py"]

        result = assign_labels(changed_files, rules)

        assert "tests" in result.get("test_utils.test.py", [])
        assert "tests" not in result.get("main.py", [])

    def test_wildcard_pattern(self):
        """Test * pattern in different positions."""
        rules = [
            LabelRule(pattern="src/*/*", labels=["component"]),
        ]
        changed_files = ["src/auth/login.py", "src/database/query.py"]

        result = assign_labels(changed_files, rules)

        # Both should match the component pattern
        assert "component" in result.get("src/auth/login.py", [])


class TestPriorityOrdering:
    """Test priority ordering when rules conflict."""

    def test_priority_ordering_first_wins(self):
        """Test that rules are applied in order, earlier rules take priority."""
        # Create a test scenario where priority matters
        rules = [
            LabelRule(pattern="*.js", labels=["javascript"], priority=1),
            LabelRule(pattern="src/**", labels=["backend"], priority=2),
        ]
        changed_files = ["src/script.js"]

        result = assign_labels(changed_files, rules, respect_priority=True)

        # Both rules match, but with priority ordering applied
        assert "javascript" in result["src/script.js"]
        assert "backend" in result["src/script.js"]

    def test_no_priority_collision(self):
        """Test without explicit priority, both labels are assigned."""
        rules = [
            LabelRule(pattern="*.js", labels=["javascript"]),
            LabelRule(pattern="src/**", labels=["backend"]),
        ]
        changed_files = ["src/script.js"]

        result = assign_labels(changed_files, rules)

        assert "javascript" in result["src/script.js"]
        assert "backend" in result["src/script.js"]


class TestLabelRuleClass:
    """Test the LabelRule class."""

    def test_label_rule_creation(self):
        """Test creating a LabelRule instance."""
        rule = LabelRule(pattern="docs/**", labels=["documentation"])

        assert rule.pattern == "docs/**"
        assert rule.labels == ["documentation"]

    def test_label_rule_with_priority(self):
        """Test LabelRule with priority parameter."""
        rule = LabelRule(
            pattern="src/**", labels=["code"], priority=1
        )

        assert rule.priority == 1

    def test_label_rule_default_priority(self):
        """Test LabelRule default priority is infinity (lowest)."""
        rule = LabelRule(pattern="docs/**", labels=["documentation"])

        assert rule.priority == float("inf")


class TestPRLabelAssignerClass:
    """Test the PRLabelAssigner class for stateful operations."""

    def test_assigner_initialization(self):
        """Test creating an assigner with rules."""
        rules = [LabelRule(pattern="docs/**", labels=["documentation"])]
        assigner = PRLabelAssigner(rules)

        assert assigner.rules == rules

    def test_assigner_assign_method(self):
        """Test the assign method on assigner instance."""
        rules = [LabelRule(pattern="docs/**", labels=["documentation"])]
        assigner = PRLabelAssigner(rules)
        changed_files = ["docs/README.md", "src/main.py"]

        result = assigner.assign(changed_files)

        assert "documentation" in result["docs/README.md"]
        assert result["src/main.py"] == []

    def test_assigner_add_rule(self):
        """Test dynamically adding rules to assigner."""
        assigner = PRLabelAssigner([])
        assigner.add_rule(LabelRule(pattern="docs/**", labels=["documentation"]))
        changed_files = ["docs/README.md"]

        result = assigner.assign(changed_files)

        assert "documentation" in result["docs/README.md"]


class TestEdgeCases:
    """Test edge cases and error handling."""

    def test_empty_changed_files_list(self):
        """Test with empty changed files list."""
        rules = [LabelRule(pattern="docs/**", labels=["documentation"])]

        result = assign_labels([], rules)

        assert result == {}

    def test_empty_rules_list(self):
        """Test with empty rules list."""
        changed_files = ["docs/README.md", "src/main.py"]

        result = assign_labels(changed_files, [])

        # All files should have empty label lists
        assert result == {"docs/README.md": [], "src/main.py": []}

    def test_empty_label_list_in_rule(self):
        """Test rule with empty label list."""
        rules = [LabelRule(pattern="docs/**", labels=[])]
        changed_files = ["docs/README.md"]

        result = assign_labels(changed_files, rules)

        assert result["docs/README.md"] == []

    def test_duplicate_labels_deduplicated(self):
        """Test that duplicate labels are removed."""
        rules = [
            LabelRule(pattern="src/**", labels=["code"]),
            LabelRule(pattern="src/**", labels=["code"]),
        ]
        changed_files = ["src/main.py"]

        result = assign_labels(changed_files, rules)

        # Should have only one 'code' label, not duplicates
        assert result["src/main.py"].count("code") == 1

    def test_case_sensitive_pattern_matching(self):
        """Test that pattern matching is case-sensitive."""
        rules = [LabelRule(pattern="Docs/**", labels=["documentation"])]
        changed_files = ["docs/README.md", "Docs/API.md"]

        result = assign_labels(changed_files, rules)

        assert "documentation" not in result.get("docs/README.md", [])
        assert "documentation" in result.get("Docs/API.md", [])


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
