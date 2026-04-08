# PR Label Assigner - TDD Test Suite
# Approach: Red/Green/Refactor cycle for each feature

import pytest

# Import will fail until we create the module — this is our first RED state
from label_assigner import LabelAssigner, LabelRule


class TestBasicLabelAssignment:
    """RED: Test that a single exact-match rule assigns the correct label."""

    def test_exact_path_match_assigns_label(self):
        """A file path matching a rule exactly should receive that rule's label."""
        rules = [LabelRule(pattern="README.md", label="documentation", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["README.md"])
        assert labels == {"documentation"}

    def test_no_match_returns_empty_set(self):
        """A file path that matches no rules should produce no labels."""
        rules = [LabelRule(pattern="README.md", label="documentation", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["src/main.py"])
        assert labels == set()


class TestGlobPatterns:
    """RED: Test glob pattern matching (e.g., docs/**, *.test.*)."""

    def test_double_star_glob_matches_nested_paths(self):
        """docs/** should match any file under docs/ at any depth."""
        rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["docs/guide/intro.md"])
        assert "documentation" in labels

    def test_double_star_glob_matches_direct_child(self):
        """docs/** should also match a direct child like docs/README.md."""
        rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["docs/README.md"])
        assert "documentation" in labels

    def test_wildcard_extension_glob(self):
        """src/api/** should match files under src/api/."""
        rules = [LabelRule(pattern="src/api/**", label="api", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["src/api/routes.py"])
        assert "api" in labels

    def test_star_in_filename_glob(self):
        """*.test.* should match files like foo.test.js and bar.test.py."""
        rules = [LabelRule(pattern="*.test.*", label="tests", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["foo.test.js"])
        assert "tests" in labels

    def test_star_in_filename_with_path(self):
        """**/*.test.* should match test files nested at any depth."""
        rules = [LabelRule(pattern="**/*.test.*", label="tests", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["src/components/Button.test.tsx"])
        assert "tests" in labels

    def test_non_matching_glob_returns_empty(self):
        """A file outside the glob pattern should not be labeled."""
        rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["src/main.py"])
        assert labels == set()


class TestMultipleLabelsPerFile:
    """RED: Test that one file can receive multiple labels from multiple matching rules."""

    def test_file_matching_two_rules_gets_both_labels(self):
        """A file matching both docs/** and **/*.md should get both labels."""
        rules = [
            LabelRule(pattern="docs/**", label="documentation", priority=1),
            LabelRule(pattern="**/*.md", label="markdown", priority=2),
        ]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["docs/guide.md"])
        assert "documentation" in labels
        assert "markdown" in labels

    def test_multiple_files_accumulate_labels(self):
        """Labels from all files in the PR should be merged into one set."""
        rules = [
            LabelRule(pattern="docs/**", label="documentation", priority=1),
            LabelRule(pattern="src/api/**", label="api", priority=2),
        ]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["docs/intro.md", "src/api/users.py"])
        assert "documentation" in labels
        assert "api" in labels

    def test_duplicate_label_from_multiple_files_appears_once(self):
        """If two files both match docs/**, the 'documentation' label appears only once."""
        rules = [LabelRule(pattern="docs/**", label="documentation", priority=1)]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["docs/intro.md", "docs/guide.md"])
        assert labels == {"documentation"}


class TestPriorityOrdering:
    """RED: Test priority-based conflict resolution.

    Priority ordering determines which label 'wins' when a file matches multiple
    rules that assign the SAME label slot or when we want only the highest-priority
    label from conflicting rules. Here we implement priority as an ordering hint —
    lower priority number = higher priority. The label set always accumulates all
    matching labels, but priority is used to resolve explicit conflicts (exclusive
    label groups) if configured.

    For simplicity: priority controls rule ordering in output metadata, and
    the LabelAssigner exposes `assign_with_priority` that returns labels sorted
    by their highest matching rule priority.
    """

    def test_higher_priority_rule_listed_first(self):
        """assign_with_priority returns labels ordered by rule priority (lower = higher priority)."""
        rules = [
            LabelRule(pattern="src/**", label="backend", priority=3),
            LabelRule(pattern="**/*.test.*", label="tests", priority=1),
        ]
        assigner = LabelAssigner(rules)
        # src/auth.test.py matches both rules
        ordered = assigner.assign_with_priority(["src/auth.test.py"])
        assert ordered[0] == "tests"   # priority 1 comes first
        assert ordered[1] == "backend"  # priority 3 comes second

    def test_exclusive_labels_resolved_by_priority(self):
        """When rules are marked exclusive, only the highest-priority label wins."""
        rules = [
            LabelRule(pattern="src/**", label="backend", priority=3, exclusive_group="area"),
            LabelRule(pattern="src/api/**", label="api", priority=1, exclusive_group="area"),
        ]
        assigner = LabelAssigner(rules)
        # src/api/routes.py matches both, but they're in the same exclusive group
        labels = assigner.assign(["src/api/routes.py"])
        # Only the highest-priority (lowest number) label should be kept
        assert "api" in labels
        assert "backend" not in labels

    def test_non_exclusive_rules_accumulate_normally(self):
        """Rules without exclusive_group still accumulate all matching labels."""
        rules = [
            LabelRule(pattern="src/**", label="backend", priority=3),
            LabelRule(pattern="src/api/**", label="api", priority=1),
        ]
        assigner = LabelAssigner(rules)
        labels = assigner.assign(["src/api/routes.py"])
        assert "api" in labels
        assert "backend" in labels


class TestMockFileList:
    """RED: Integration tests using realistic mock PR file lists."""

    # Mock PR scenarios as fixtures
    FULL_STACK_PR_FILES = [
        "src/api/endpoints.py",
        "src/api/models.py",
        "src/frontend/components/Button.tsx",
        "src/frontend/components/Button.test.tsx",
        "docs/api-reference.md",
        "README.md",
    ]

    HOTFIX_PR_FILES = [
        "src/auth/login.py",
        "src/auth/login.test.py",
        "CHANGELOG.md",
    ]

    CONFIG_RULES = [
        LabelRule(pattern="docs/**", label="documentation", priority=1),
        LabelRule(pattern="**/*.md", label="documentation", priority=1),
        LabelRule(pattern="src/api/**", label="api", priority=2),
        LabelRule(pattern="src/frontend/**", label="frontend", priority=2),
        LabelRule(pattern="**/*.test.*", label="tests", priority=3),
        LabelRule(pattern="src/auth/**", label="security", priority=1),
    ]

    def test_full_stack_pr_gets_multiple_labels(self):
        """A PR touching docs, api, frontend, and tests gets all relevant labels."""
        assigner = LabelAssigner(self.CONFIG_RULES)
        labels = assigner.assign(self.FULL_STACK_PR_FILES)
        assert "documentation" in labels
        assert "api" in labels
        assert "frontend" in labels
        assert "tests" in labels

    def test_hotfix_pr_gets_security_and_tests(self):
        """A hotfix to auth code touching tests gets 'security' and 'tests'."""
        assigner = LabelAssigner(self.CONFIG_RULES)
        labels = assigner.assign(self.HOTFIX_PR_FILES)
        assert "security" in labels
        assert "tests" in labels

    def test_empty_file_list_returns_empty_labels(self):
        """An empty PR file list yields no labels."""
        assigner = LabelAssigner(self.CONFIG_RULES)
        labels = assigner.assign([])
        assert labels == set()


class TestErrorHandling:
    """RED: Test graceful error handling for invalid inputs."""

    def test_invalid_pattern_raises_value_error(self):
        """A LabelRule with an empty pattern should raise ValueError."""
        with pytest.raises(ValueError, match="pattern cannot be empty"):
            LabelRule(pattern="", label="test", priority=1)

    def test_invalid_label_raises_value_error(self):
        """A LabelRule with an empty label should raise ValueError."""
        with pytest.raises(ValueError, match="label cannot be empty"):
            LabelRule(pattern="src/**", label="", priority=1)

    def test_invalid_priority_raises_value_error(self):
        """A LabelRule with a non-positive priority should raise ValueError."""
        with pytest.raises(ValueError, match="priority must be a positive integer"):
            LabelRule(pattern="src/**", label="backend", priority=0)

    def test_none_file_list_raises_type_error(self):
        """Passing None as the file list should raise TypeError."""
        assigner = LabelAssigner([])
        with pytest.raises(TypeError, match="file_paths must be a list"):
            assigner.assign(None)  # type: ignore
