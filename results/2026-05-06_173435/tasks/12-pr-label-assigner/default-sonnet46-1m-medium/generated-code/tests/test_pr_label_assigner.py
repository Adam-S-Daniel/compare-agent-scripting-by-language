"""Tests for PR Label Assigner — written TDD style before the implementation exists."""

import json
import pytest

# Import under test — will fail until pr_label_assigner.py exists
from pr_label_assigner import assign_labels, match_glob, load_rules, DEFAULT_RULES


# ---------------------------------------------------------------------------
# Unit tests: match_glob
# ---------------------------------------------------------------------------

class TestMatchGlob:
    """match_glob(pattern, path) -> bool"""

    def test_simple_extension_match(self):
        assert match_glob("*.md", "README.md") is True

    def test_simple_extension_no_match(self):
        assert match_glob("*.md", "README.py") is False

    def test_directory_prefix(self):
        assert match_glob("docs/**", "docs/guide/intro.md") is True

    def test_directory_prefix_root_file(self):
        assert match_glob("docs/**", "docs/README.md") is True

    def test_directory_prefix_no_match(self):
        assert match_glob("docs/**", "src/main.py") is False

    def test_nested_glob(self):
        assert match_glob("src/api/**", "src/api/v1/endpoint.py") is True

    def test_nested_glob_no_match(self):
        assert match_glob("src/api/**", "src/utils/helper.py") is False

    def test_wildcard_in_filename(self):
        # *.test.* should match files like app.test.js or utils.test.py
        assert match_glob("*.test.*", "app.test.js") is True
        assert match_glob("*.test.*", "utils.test.py") is True

    def test_wildcard_in_filename_no_match(self):
        assert match_glob("*.test.*", "app.js") is False

    def test_deep_nested_wildcard(self):
        # **/*.test.* should match test files anywhere in the tree
        assert match_glob("**/*.test.*", "src/components/Button.test.tsx") is True

    def test_deep_nested_wildcard_root(self):
        assert match_glob("**/*.test.*", "Button.test.tsx") is True


# ---------------------------------------------------------------------------
# Unit tests: assign_labels — core logic
# ---------------------------------------------------------------------------

class TestAssignLabels:
    """assign_labels(changed_files, rules) -> list[str]"""

    RULES = [
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
        {"pattern": "**/*.md", "label": "documentation", "priority": 2},
        {"pattern": "src/api/**", "label": "api", "priority": 1},
        {"pattern": "*.test.*", "label": "tests", "priority": 2},
        {"pattern": "**/*.test.*", "label": "tests", "priority": 2},
        {"pattern": "src/**", "label": "source", "priority": 3},
    ]

    def test_single_file_single_label(self):
        files = ["docs/intro.md"]
        result = assign_labels(files, self.RULES)
        assert result == ["documentation"]

    def test_single_file_multiple_matching_rules_deduped(self):
        # docs/guide.md matches both docs/** (documentation) AND **/*.md (documentation)
        # Should produce a single "documentation" label
        files = ["docs/guide.md"]
        result = assign_labels(files, self.RULES)
        assert result == ["documentation"]

    def test_multiple_files_multiple_labels(self):
        files = ["docs/intro.md", "src/api/endpoint.py", "src/utils/helper.py"]
        result = assign_labels(files, self.RULES)
        assert "documentation" in result
        assert "api" in result
        assert "source" in result

    def test_test_files_get_tests_label(self):
        files = ["app.test.js"]
        result = assign_labels(files, self.RULES)
        assert "tests" in result

    def test_nested_test_file(self):
        files = ["src/components/Button.test.tsx"]
        result = assign_labels(files, self.RULES)
        assert "tests" in result

    def test_result_is_sorted(self):
        files = ["src/api/endpoint.py", "docs/guide.md", "app.test.js"]
        result = assign_labels(files, self.RULES)
        assert result == sorted(result)

    def test_empty_file_list_returns_empty(self):
        result = assign_labels([], self.RULES)
        assert result == []

    def test_no_matching_rules_returns_empty(self):
        files = ["build/output.bin"]
        result = assign_labels(files, self.RULES)
        assert result == []

    def test_uses_default_rules_when_none_given(self):
        # Must not raise; default rules exist
        result = assign_labels(["docs/readme.md"])
        assert isinstance(result, list)

    def test_raises_on_empty_rules_list(self):
        with pytest.raises(ValueError, match="Rules list cannot be empty"):
            assign_labels(["docs/readme.md"], rules=[])


# ---------------------------------------------------------------------------
# Priority ordering tests
# ---------------------------------------------------------------------------

class TestPriorityOrdering:
    """When multiple rules match, all matching labels are collected (priority
    does NOT filter labels out — it determines evaluation order, so that
    higher-priority rules are checked first).  Two rules for the same label
    on the same file still produce one label in the output."""

    RULES = [
        {"pattern": "src/api/**", "label": "api", "priority": 1},
        {"pattern": "src/**", "label": "source", "priority": 2},
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
    ]

    def test_file_matches_two_different_labels(self):
        # src/api/v1.py matches both api (priority 1) and source (priority 2)
        files = ["src/api/v1.py"]
        result = assign_labels(files, self.RULES)
        assert "api" in result
        assert "source" in result

    def test_high_priority_label_present(self):
        files = ["src/api/v1.py"]
        result = assign_labels(files, self.RULES)
        assert result.index("api") >= 0  # api is present

    def test_no_duplicate_labels_when_two_rules_give_same_label(self):
        rules = [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "**/*.md", "label": "documentation", "priority": 2},
        ]
        files = ["docs/guide.md"]
        result = assign_labels(files, rules)
        assert result.count("documentation") == 1


# ---------------------------------------------------------------------------
# load_rules: reading rule config from JSON
# ---------------------------------------------------------------------------

class TestLoadRules:
    """load_rules(path) -> list[dict]"""

    def test_load_valid_rules_file(self, tmp_path):
        rules_data = [
            {"pattern": "docs/**", "label": "documentation", "priority": 1},
            {"pattern": "src/**", "label": "source", "priority": 2},
        ]
        rules_file = tmp_path / "rules.json"
        rules_file.write_text(json.dumps(rules_data))
        result = load_rules(str(rules_file))
        assert len(result) == 2
        assert result[0]["label"] == "documentation"

    def test_load_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            load_rules(str(tmp_path / "nonexistent.json"))

    def test_load_invalid_json_raises(self, tmp_path):
        bad_file = tmp_path / "bad.json"
        bad_file.write_text("not valid json {{{")
        with pytest.raises(ValueError, match="Invalid JSON"):
            load_rules(str(bad_file))

    def test_load_non_list_raises(self, tmp_path):
        bad_file = tmp_path / "bad.json"
        bad_file.write_text('{"pattern": "docs/**"}')
        with pytest.raises(ValueError, match="must be a JSON array"):
            load_rules(str(bad_file))


# ---------------------------------------------------------------------------
# Integration-style fixture tests — these produce parseable output
# used by the act test harness to validate exact results
# ---------------------------------------------------------------------------

FIXTURE_CASES = [
    {
        "id": "case_docs_only",
        "files": ["docs/intro.md", "docs/api/reference.md"],
        "expected_labels": ["documentation"],
    },
    {
        "id": "case_api_and_source",
        "files": ["src/api/users.py", "src/models/user.py"],
        "expected_labels": ["api", "source"],
    },
    {
        "id": "case_tests_label",
        # app.test.js -> tests; src/components/Button.test.tsx -> source + tests
        "files": ["app.test.js", "src/components/Button.test.tsx"],
        "expected_labels": ["source", "tests"],
    },
    {
        "id": "case_mixed",
        "files": [
            "docs/readme.md",
            "src/api/endpoint.py",
            "src/utils/helper.py",
            "app.test.js",
        ],
        "expected_labels": ["api", "documentation", "source", "tests"],
    },
    {
        "id": "case_no_match",
        "files": ["build/output.bin", "dist/bundle.js.map"],
        "expected_labels": [],
    },
    {
        "id": "case_md_anywhere",
        # CHANGELOG.md -> documentation; src/README.md -> documentation + source
        "files": ["CHANGELOG.md", "src/README.md"],
        "expected_labels": ["documentation", "source"],
    },
]


@pytest.mark.parametrize("case", FIXTURE_CASES, ids=[c["id"] for c in FIXTURE_CASES])
def test_fixture_case(case, capsys):
    """Run each fixture case and print a parseable LABEL_RESULT line for act harness."""
    result = assign_labels(case["files"])
    # Print in a format the act harness can grep for exact values
    labels_str = ",".join(result) if result else "(none)"
    print(f"LABEL_RESULT:{case['id']}:{labels_str}")
    assert result == case["expected_labels"], (
        f"Case {case['id']}: expected {case['expected_labels']}, got {result}"
    )
