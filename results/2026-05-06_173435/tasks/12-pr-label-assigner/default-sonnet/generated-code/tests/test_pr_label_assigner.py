"""
TDD tests for pr_label_assigner.py

Red/green cycle order:
  1. test_empty_file_list_returns_empty_set
  2. test_docs_pattern_assigns_documentation_label
  3. test_api_pattern_assigns_api_label
  4. test_filename_pattern_matches_without_directory
  5. test_multiple_labels_per_file
  6. test_no_match_returns_empty_set
  7. test_multiple_files_union_of_labels
  8. test_priority_ordering
  9. test_double_star_slash_pattern
  10. test_no_rules_returns_empty_set
  11. test_spec_pattern
  12. test_load_config_from_file
  13. test_load_files_from_file
  14. test_load_config_missing_file_raises
  15. test_load_config_invalid_json_raises
"""

import json
import os
import tempfile

import pytest

from pr_label_assigner import assign_labels, load_config, load_files, pattern_matches


# --- pattern_matches tests ---

class TestPatternMatches:
    def test_double_star_matches_nested_path(self):
        """docs/** should match any file under docs/."""
        assert pattern_matches("docs/README.md", "docs/**") is True
        assert pattern_matches("docs/sub/dir/file.txt", "docs/**") is True

    def test_double_star_does_not_match_sibling(self):
        """docs/** should not match files outside docs/."""
        assert pattern_matches("src/README.md", "docs/**") is False

    def test_single_star_matches_filename(self):
        """*.py matches any .py at any directory level (matched against filename)."""
        assert pattern_matches("app.py", "*.py") is True
        assert pattern_matches("src/app.py", "*.py") is True

    def test_single_star_does_not_cross_directory_in_full_path(self):
        """src/* should not match src/api/file.py (single * doesn't cross /)."""
        assert pattern_matches("src/file.py", "src/*") is True
        assert pattern_matches("src/api/file.py", "src/*") is False

    def test_double_star_slash_prefix(self):
        """**/*.py matches Python files at any depth."""
        assert pattern_matches("app.py", "**/*.py") is True
        assert pattern_matches("src/app.py", "**/*.py") is True
        assert pattern_matches("src/api/app.py", "**/*.py") is True

    def test_no_directory_in_pattern_matches_filename_only(self):
        """*.test.* pattern (no /) matches against filename portion only."""
        assert pattern_matches("src/utils.test.js", "*.test.*") is True
        assert pattern_matches("utils.test.js", "*.test.*") is True
        assert pattern_matches("utils.py", "*.test.*") is False

    def test_question_mark_matches_single_char(self):
        """? matches any single character except /."""
        assert pattern_matches("src/a.py", "src/?.py") is True
        assert pattern_matches("src/ab.py", "src/?.py") is False


# --- assign_labels tests ---

class TestAssignLabels:
    # TDD cycle 1: empty input → empty output
    def test_empty_file_list_returns_empty_set(self):
        """No files → no labels."""
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        assert assign_labels([], rules) == set()

    # TDD cycle 2: docs/** pattern
    def test_docs_pattern_assigns_documentation_label(self):
        """Files under docs/ receive the documentation label."""
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        assert assign_labels(["docs/README.md"], rules) == {"documentation"}

    # TDD cycle 3: src/api/** nested pattern
    def test_api_pattern_assigns_api_label(self):
        """Files under src/api/ receive the api label."""
        rules = [{"pattern": "src/api/**", "label": "api", "priority": 1}]
        assert assign_labels(["src/api/users.py"], rules) == {"api"}

    # TDD cycle 4: filename-only pattern (no / in pattern)
    def test_filename_pattern_matches_without_directory(self):
        """*.test.* matches any file whose name contains .test. regardless of path."""
        rules = [{"pattern": "*.test.*", "label": "tests", "priority": 1}]
        result = assign_labels(["src/utils.test.js"], rules)
        assert result == {"tests"}

    # TDD cycle 5: multiple labels per file
    def test_multiple_labels_per_file(self):
        """A file matching multiple rules receives all matching labels."""
        rules = [
            {"pattern": "src/api/**", "label": "api", "priority": 1},
            {"pattern": "src/**", "label": "source", "priority": 2},
        ]
        result = assign_labels(["src/api/users.py"], rules)
        assert result == {"api", "source"}

    # TDD cycle 6: no match
    def test_no_match_returns_empty_set(self):
        """A file matching no rules produces no labels."""
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        assert assign_labels(["Makefile"], rules) == set()

    # TDD cycle 7: multiple files, union of labels
    def test_multiple_files_union_of_labels(self):
        """Labels from all files are unioned together."""
        rules = [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/**", "label": "source", "priority": 2},
        ]
        result = assign_labels(["docs/README.md", "src/main.py"], rules)
        assert result == {"documentation", "source"}

    # TDD cycle 8: priority ordering
    def test_priority_ordering_processes_high_priority_first(self):
        """Rules with lower priority numbers are processed first; all matches collected."""
        rules = [
            {"pattern": "src/**", "label": "source", "priority": 2},
            {"pattern": "src/api/**", "label": "api", "priority": 1},
        ]
        # Even when the source rule is listed first, priority ordering is applied.
        # Both labels are collected (multiple labels per file).
        result = assign_labels(["src/api/users.py"], rules)
        assert result == {"api", "source"}

    def test_duplicate_labels_deduplicated(self):
        """When multiple rules match the same label, it appears only once."""
        rules = [
            {"pattern": "**/*.py", "label": "python", "priority": 1},
            {"pattern": "src/**/*.py", "label": "python", "priority": 2},
        ]
        result = assign_labels(["src/app.py"], rules)
        assert result == {"python"}
        assert len(result) == 1

    # TDD cycle 9: **/*.py pattern at root and nested
    def test_double_star_slash_matches_root_and_nested(self):
        """**/*.py matches Python files at any depth including root."""
        rules = [{"pattern": "**/*.py", "label": "python", "priority": 1}]
        assert assign_labels(["app.py"], rules) == {"python"}
        assert assign_labels(["src/app.py"], rules) == {"python"}
        assert assign_labels(["src/api/app.py"], rules) == {"python"}

    # TDD cycle 10: no rules
    def test_no_rules_returns_empty_set(self):
        """With no rules defined, no labels are produced."""
        assert assign_labels(["docs/README.md"], []) == set()

    # TDD cycle 11: spec pattern
    def test_spec_pattern_assigns_tests_label(self):
        """*.spec.* files receive the tests label."""
        rules = [{"pattern": "*.spec.*", "label": "tests", "priority": 1}]
        result = assign_labels(["src/utils.spec.ts"], rules)
        assert result == {"tests"}

    def test_mixed_pr_assigns_all_relevant_labels(self):
        """A realistic mixed PR with docs, API, and test files gets all expected labels."""
        rules = [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/api/**", "label": "api", "priority": 2},
            {"pattern": "*.test.*", "label": "tests", "priority": 3},
            {"pattern": "*.spec.*", "label": "tests", "priority": 3},
            {"pattern": "**/*.py", "label": "python", "priority": 4},
            {"pattern": "src/**", "label": "source", "priority": 5},
        ]
        files = [
            "docs/README.md",
            "src/api/users.py",
            "src/utils.test.js",
            "src/main.py",
        ]
        result = assign_labels(files, rules)
        assert result == {"documentation", "api", "tests", "python", "source"}

    def test_default_priority_when_missing(self):
        """Rules without a priority field default to priority 0 (highest)."""
        rules = [
            {"pattern": "docs/**", "label": "documentation"},
        ]
        result = assign_labels(["docs/README.md"], rules)
        assert result == {"documentation"}


# --- load_config tests ---

class TestLoadConfig:
    # TDD cycle 12: load config from file
    def test_load_config_from_list_json(self):
        """Config file containing a JSON array of rules is loaded correctly."""
        rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(rules, f)
            f.flush()
            loaded = load_config(f.name)
        os.unlink(f.name)
        assert loaded == rules

    def test_load_config_from_dict_with_rules_key(self):
        """Config file containing {rules: [...]} dict is also accepted."""
        rules = [{"pattern": "src/**", "label": "source", "priority": 1}]
        config = {"rules": rules, "version": "1.0"}
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(config, f)
            f.flush()
            loaded = load_config(f.name)
        os.unlink(f.name)
        assert loaded == rules

    # TDD cycle 14: missing file raises meaningful error
    def test_load_config_missing_file_raises(self):
        """FileNotFoundError is raised with a meaningful message when config is missing."""
        with pytest.raises(FileNotFoundError, match="Config file not found"):
            load_config("/nonexistent/path/config.json")

    # TDD cycle 15: invalid JSON raises meaningful error
    def test_load_config_invalid_json_raises(self):
        """ValueError is raised with a meaningful message when config contains invalid JSON."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write("not valid json {{{")
            f.flush()
            with pytest.raises(ValueError, match="Invalid JSON"):
                load_config(f.name)
        os.unlink(f.name)


# --- load_files tests ---

class TestLoadFiles:
    # TDD cycle 13: load file list from text file
    def test_load_files_from_text_file(self):
        """File list is read from a plain text file, one path per line."""
        paths = ["docs/README.md", "src/main.py", "tests/test_main.py"]
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write("\n".join(paths) + "\n")
            f.flush()
            loaded = load_files(f.name)
        os.unlink(f.name)
        assert loaded == paths

    def test_load_files_skips_blank_lines(self):
        """Blank lines in the file list are ignored."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write("docs/README.md\n\nsrc/main.py\n\n")
            f.flush()
            loaded = load_files(f.name)
        os.unlink(f.name)
        assert loaded == ["docs/README.md", "src/main.py"]

    def test_load_files_missing_file_raises(self):
        """FileNotFoundError is raised when the file list path doesn't exist."""
        with pytest.raises(FileNotFoundError, match="Files list not found"):
            load_files("/nonexistent/files.txt")
