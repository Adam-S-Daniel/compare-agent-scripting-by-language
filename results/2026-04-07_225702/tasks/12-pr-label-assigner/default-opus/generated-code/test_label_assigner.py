"""
TDD tests for PR label assigner.

Approach: Red/Green/Refactor cycle.
- Each test was written FIRST as a failing test, then the minimum implementation added.
- Tests progress from simple single-rule matching to complex multi-rule, priority, and error cases.
"""

import pytest
from label_assigner import assign_labels, LabelRule


# --- Cycle 1: Basic single glob pattern matching ---

class TestBasicGlobMatching:
    """A single rule with a glob pattern should match files and return the label."""

    def test_docs_glob_matches_markdown_file(self):
        rules = [LabelRule(pattern="docs/**", label="documentation")]
        files = ["docs/README.md"]
        assert assign_labels(files, rules) == {"documentation"}

    def test_docs_glob_matches_nested_file(self):
        rules = [LabelRule(pattern="docs/**", label="documentation")]
        files = ["docs/guides/setup.md"]
        assert assign_labels(files, rules) == {"documentation"}

    def test_no_match_returns_empty_set(self):
        rules = [LabelRule(pattern="docs/**", label="documentation")]
        files = ["src/main.py"]
        assert assign_labels(files, rules) == set()


# --- Cycle 2: Extension-based glob patterns ---

class TestExtensionGlobs:
    """Patterns like *.test.* should match test files anywhere in the tree."""

    def test_star_test_star_matches_test_file(self):
        rules = [LabelRule(pattern="*.test.*", label="tests")]
        files = ["src/utils.test.js"]
        assert assign_labels(files, rules) == {"tests"}

    def test_star_test_star_matches_nested_test_file(self):
        rules = [LabelRule(pattern="*.test.*", label="tests")]
        files = ["src/deep/nested/foo.test.ts"]
        assert assign_labels(files, rules) == {"tests"}

    def test_star_test_star_does_not_match_non_test(self):
        rules = [LabelRule(pattern="*.test.*", label="tests")]
        files = ["src/utils.js"]
        assert assign_labels(files, rules) == set()


# --- Cycle 3: Multiple labels per file ---

class TestMultipleLabelsPerFile:
    """A file can match multiple rules and accumulate all their labels."""

    def test_file_matching_two_rules_gets_both_labels(self):
        rules = [
            LabelRule(pattern="src/api/**", label="api"),
            LabelRule(pattern="*.test.*", label="tests"),
        ]
        files = ["src/api/handler.test.js"]
        assert assign_labels(files, rules) == {"api", "tests"}

    def test_multiple_files_accumulate_labels(self):
        rules = [
            LabelRule(pattern="docs/**", label="documentation"),
            LabelRule(pattern="src/api/**", label="api"),
        ]
        files = ["docs/README.md", "src/api/routes.py"]
        assert assign_labels(files, rules) == {"documentation", "api"}


# --- Cycle 4: Priority ordering when rules conflict ---

class TestPriorityOrdering:
    """When multiple rules match the same file, higher-priority rules can suppress lower ones."""

    def test_higher_priority_rule_suppresses_lower(self):
        # priority=1 is highest; the "generic" label at priority=10 should be suppressed
        rules = [
            LabelRule(pattern="src/**", label="generic", priority=10),
            LabelRule(pattern="src/api/**", label="api", priority=1),
        ]
        files = ["src/api/handler.py"]
        # Only the highest-priority matching label is kept for conflicting rules
        assert assign_labels(files, rules) == {"api"}

    def test_non_conflicting_different_priority_rules_both_apply(self):
        # Rules matching DIFFERENT files don't conflict even with different priorities
        rules = [
            LabelRule(pattern="docs/**", label="documentation", priority=5),
            LabelRule(pattern="src/api/**", label="api", priority=1),
        ]
        files = ["docs/README.md", "src/api/handler.py"]
        assert assign_labels(files, rules) == {"documentation", "api"}

    def test_same_priority_rules_both_apply(self):
        # Two rules at the same priority both apply even to the same file
        rules = [
            LabelRule(pattern="src/**", label="source", priority=1),
            LabelRule(pattern="src/api/**", label="api", priority=1),
        ]
        files = ["src/api/handler.py"]
        assert assign_labels(files, rules) == {"source", "api"}


# --- Cycle 5: Edge cases and error handling ---

class TestEdgeCases:
    """Graceful handling of empty inputs, invalid rules, and unusual paths."""

    def test_empty_file_list(self):
        rules = [LabelRule(pattern="docs/**", label="documentation")]
        assert assign_labels([], rules) == set()

    def test_empty_rules_list(self):
        assert assign_labels(["docs/README.md"], []) == set()

    def test_both_empty(self):
        assert assign_labels([], []) == set()

    def test_invalid_pattern_raises_value_error(self):
        with pytest.raises(ValueError, match="Invalid pattern"):
            LabelRule(pattern="", label="oops")

    def test_invalid_label_raises_value_error(self):
        with pytest.raises(ValueError, match="Invalid label"):
            LabelRule(pattern="docs/**", label="")

    def test_invalid_priority_raises_value_error(self):
        with pytest.raises(ValueError, match="Priority must be a positive integer"):
            LabelRule(pattern="docs/**", label="documentation", priority=-1)


# --- Cycle 6: Config loading from dict ---

class TestConfigLoading:
    """Rules can be loaded from a configuration dictionary."""

    def test_load_rules_from_config_dict(self):
        from label_assigner import load_rules

        config = {
            "rules": [
                {"pattern": "docs/**", "label": "documentation"},
                {"pattern": "src/api/**", "label": "api", "priority": 1},
                {"pattern": "*.test.*", "label": "tests"},
            ]
        }
        rules = load_rules(config)
        assert len(rules) == 3
        assert rules[0].label == "documentation"
        assert rules[1].priority == 1
        assert rules[2].label == "tests"

    def test_load_rules_missing_rules_key_raises(self):
        from label_assigner import load_rules

        with pytest.raises(ValueError, match="must contain a 'rules' key"):
            load_rules({"not_rules": []})

    def test_load_rules_missing_pattern_raises(self):
        from label_assigner import load_rules

        with pytest.raises(ValueError, match="must have 'pattern' and 'label'"):
            load_rules({"rules": [{"label": "docs"}]})


# --- Cycle 7: Full integration with mock PR file list ---

class TestIntegration:
    """End-to-end test simulating a real PR with a realistic config."""

    RULES = [
        LabelRule(pattern="docs/**", label="documentation", priority=5),
        LabelRule(pattern="src/api/**", label="api", priority=1),
        LabelRule(pattern="src/**", label="source", priority=10),
        LabelRule(pattern="*.test.*", label="tests", priority=3),
        LabelRule(pattern="*.md", label="markdown", priority=8),
        LabelRule(pattern=".github/**", label="ci", priority=2),
    ]

    MOCK_PR_FILES = [
        "docs/getting-started.md",     # -> documentation (pri 5, beats markdown pri 8)
        "src/api/users.py",            # -> api (pri 1, beats source pri 10)
        "src/api/users.test.py",       # -> api (pri 1) + tests (pri 3), source suppressed
        "src/utils/helpers.py",        # -> source (pri 10, only match)
        ".github/workflows/ci.yml",    # -> ci (pri 2, only match)
        "README.md",                   # -> markdown (pri 8, only match)
    ]

    def test_full_pr_labeling(self):
        labels = assign_labels(self.MOCK_PR_FILES, self.RULES)
        # "tests" is NOT in the set because src/api/users.test.py matches
        # api (pri 1) which beats tests (pri 3) — priority suppression
        assert labels == {"documentation", "api", "source", "ci", "markdown"}

    def test_api_only_pr(self):
        files = ["src/api/routes.py", "src/api/models.py"]
        labels = assign_labels(files, self.RULES)
        # api (pri 1) beats source (pri 10) for these files
        assert labels == {"api"}

    def test_docs_pr(self):
        files = ["docs/api-reference.md", "docs/changelog.md"]
        labels = assign_labels(files, self.RULES)
        # documentation (pri 5) beats markdown (pri 8)
        assert labels == {"documentation"}

    def test_test_file_outside_api_gets_tests_label(self):
        # A test file NOT under src/api/ — tests (pri 3) beats source (pri 10)
        files = ["src/utils/helpers.test.py"]
        labels = assign_labels(files, self.RULES)
        assert labels == {"tests"}
