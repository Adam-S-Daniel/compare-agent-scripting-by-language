# TDD: These tests are written FIRST (red phase).
# They fail until label_assigner.py is implemented (green phase).

import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from label_assigner import assign_labels, load_rules, match_file


class TestMatchFile:
    """Unit tests for glob pattern matching against file paths."""

    def test_docs_glob_matches_direct_child(self):
        # First test: docs/** matches a file directly under docs/
        assert match_file("docs/README.md", "docs/**") is True

    def test_docs_glob_matches_nested(self):
        assert match_file("docs/sub/guide.md", "docs/**") is True

    def test_docs_glob_no_match_different_dir(self):
        assert match_file("src/main.py", "docs/**") is False

    def test_api_glob_matches(self):
        assert match_file("src/api/users.py", "src/api/**") is True

    def test_test_file_pattern_simple(self):
        # *.test.* matches files with .test. anywhere in the basename or path
        assert match_file("utils.test.py", "*.test.*") is True

    def test_test_file_in_subdirectory(self):
        # fnmatch * matches / so *.test.* also matches src/utils.test.js
        assert match_file("src/utils.test.js", "*.test.*") is True

    def test_exact_filename_match(self):
        assert match_file("Makefile", "Makefile") is True

    def test_extension_only_pattern(self):
        assert match_file("config.yaml", "*.yaml") is True

    def test_no_match_returns_false(self):
        assert match_file("config/settings.json", "docs/**") is False


class TestLoadRules:
    """Unit tests for loading and priority-sorting rules."""

    def test_rules_sorted_ascending_by_priority(self):
        rules = [
            {"pattern": "docs/**", "label": "documentation", "priority": 2},
            {"pattern": "src/**", "label": "backend", "priority": 1},
        ]
        sorted_rules = load_rules(rules)
        assert sorted_rules[0]["label"] == "backend"
        assert sorted_rules[1]["label"] == "documentation"

    def test_rules_without_priority_sorted_last(self):
        # Rules without explicit priority get a fallback high number
        rules = [
            {"pattern": "docs/**", "label": "documentation"},
            {"pattern": "src/**", "label": "backend", "priority": 1},
        ]
        sorted_rules = load_rules(rules)
        assert sorted_rules[0]["label"] == "backend"

    def test_empty_rules_returns_empty(self):
        assert load_rules([]) == []


class TestAssignLabels:
    """Integration tests for the full label assignment pipeline."""

    def test_single_file_single_matching_rule(self):
        files = ["docs/README.md"]
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        assert assign_labels(files, rules) == ["documentation"]

    def test_single_file_multiple_matching_rules(self):
        # A file under src/api/ matches both src/api/** and src/**
        files = ["src/api/users.py"]
        rules = [
            {"pattern": "src/api/**", "label": "api", "priority": 1},
            {"pattern": "src/**", "label": "backend", "priority": 2},
        ]
        result = assign_labels(files, rules)
        assert "api" in result
        assert "backend" in result

    def test_multiple_files_produce_union_of_labels(self):
        files = ["docs/guide.md", "src/api/endpoint.py"]
        rules = [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
        ]
        result = assign_labels(files, rules)
        assert "documentation" in result
        assert "api" in result

    def test_no_matching_rule_returns_empty(self):
        files = ["config/settings.yaml"]
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        assert assign_labels(files, rules) == []

    def test_labels_deduplicated_across_files(self):
        # Two docs files should still produce only one "documentation" label
        files = ["docs/intro.md", "docs/guide.md"]
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        result = assign_labels(files, rules)
        assert result.count("documentation") == 1

    def test_priority_ordering_in_output(self):
        # Higher-priority rule (lower number) label appears first
        files = ["src/api/utils.test.js"]
        rules = [
            {"pattern": "src/api/**", "label": "api", "priority": 1},
            {"pattern": "*.test.*", "label": "tests", "priority": 2},
        ]
        result = assign_labels(files, rules)
        assert result.index("api") < result.index("tests")

    def test_empty_files_list(self):
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        assert assign_labels([], rules) == []

    def test_empty_rules_list(self):
        assert assign_labels(["docs/README.md"], []) == []

    def test_test_file_detection(self):
        files = ["src/components/Button.test.tsx"]
        rules = [{"pattern": "*.test.*", "label": "tests", "priority": 1}]
        assert assign_labels(files, rules) == ["tests"]

    def test_three_files_three_labels(self):
        # Full integration: docs + api + test file -> three distinct labels
        files = ["docs/README.md", "src/api/users.py", "src/utils.test.py"]
        rules = [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
            {"pattern": "*.test.*", "label": "tests", "priority": 3},
            {"pattern": "src/**", "label": "backend", "priority": 4},
        ]
        result = assign_labels(files, rules)
        assert result == ["documentation", "api", "tests", "backend"]
