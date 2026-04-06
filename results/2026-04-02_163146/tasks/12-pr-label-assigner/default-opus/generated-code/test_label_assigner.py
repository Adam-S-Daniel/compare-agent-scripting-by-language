"""
TDD tests for PR Label Assigner.

Uses Python's built-in unittest module (no external dependencies).
Each test class corresponds to a TDD cycle, written in red/green/refactor order.

Run with: python3 -m pytest test_label_assigner.py -v
   or:    python3 -m unittest test_label_assigner -v
"""

import unittest
from label_assigner import assign_labels, Rule, load_rules_from_config


# =============================================================================
# TDD Cycle 1: Basic single-rule glob matching
# RED:   assignLabels doesn't exist yet -> ImportError
# GREEN: Implement Rule dataclass and assignLabels with fnmatch
# =============================================================================
class TestBasicGlobMatching(unittest.TestCase):
    """A single rule with a glob pattern should match the right files."""

    def test_directory_glob_matches_nested_file(self):
        """docs/** should match docs/README.md"""
        rules = [Rule(pattern="docs/**", label="documentation")]
        labels = assign_labels(["docs/README.md"], rules)
        self.assertEqual(labels, {"documentation"})

    def test_no_match_returns_empty_set(self):
        """docs/** should NOT match src/main.py"""
        rules = [Rule(pattern="docs/**", label="documentation")]
        labels = assign_labels(["src/main.py"], rules)
        self.assertEqual(labels, set())

    def test_deep_nested_directory_match(self):
        """docs/** should match deeply nested paths like docs/api/v2/guide.md"""
        rules = [Rule(pattern="docs/**", label="documentation")]
        labels = assign_labels(["docs/api/v2/guide.md"], rules)
        self.assertEqual(labels, {"documentation"})


# =============================================================================
# TDD Cycle 2: Extension-based glob patterns (e.g., *.test.*)
# RED:   *.test.* pattern doesn't match test files
# GREEN: Ensure fnmatch handles extension wildcards correctly
# =============================================================================
class TestExtensionGlobPatterns(unittest.TestCase):
    """Glob patterns with wildcards in the filename should work."""

    def test_star_dot_test_dot_star_matches_test_files(self):
        """*.test.* should match files like utils.test.js"""
        rules = [Rule(pattern="*.test.*", label="tests")]
        labels = assign_labels(["utils.test.js"], rules)
        self.assertEqual(labels, {"tests"})

    def test_star_dot_test_dot_star_matches_nested_test_files(self):
        """*.test.* should match files like src/components/button.test.tsx"""
        rules = [Rule(pattern="*.test.*", label="tests")]
        labels = assign_labels(["src/components/button.test.tsx"], rules)
        self.assertEqual(labels, {"tests"})

    def test_star_dot_test_dot_star_does_not_match_non_test(self):
        """*.test.* should NOT match regular files like main.js"""
        rules = [Rule(pattern="*.test.*", label="tests")]
        labels = assign_labels(["main.js"], rules)
        self.assertEqual(labels, set())


# =============================================================================
# TDD Cycle 3: Multiple labels per file (a file can match multiple rules)
# RED:   Only first matching label is returned
# GREEN: Collect ALL matching labels into the set
# =============================================================================
class TestMultipleLabelsPerFile(unittest.TestCase):
    """A single file can match multiple rules, producing multiple labels."""

    def test_file_matching_two_rules_gets_both_labels(self):
        """docs/api/spec.test.md should match both docs/** and *.test.*"""
        rules = [
            Rule(pattern="docs/**", label="documentation"),
            Rule(pattern="*.test.*", label="tests"),
        ]
        labels = assign_labels(["docs/api/spec.test.md"], rules)
        self.assertEqual(labels, {"documentation", "tests"})

    def test_multiple_files_accumulate_labels(self):
        """Multiple files should accumulate labels from all matching rules."""
        rules = [
            Rule(pattern="docs/**", label="documentation"),
            Rule(pattern="src/api/**", label="api"),
            Rule(pattern="*.test.*", label="tests"),
        ]
        files = ["docs/guide.md", "src/api/handler.py", "utils.test.js"]
        labels = assign_labels(files, rules)
        self.assertEqual(labels, {"documentation", "api", "tests"})


# =============================================================================
# TDD Cycle 4: Priority ordering — when rules conflict, highest-priority wins
# RED:   No priority support; all matching labels are returned
# GREEN: Add priority field to Rule; when multiple rules match the SAME file,
#        only the highest-priority label for that file is kept
# =============================================================================
class TestPriorityOrdering(unittest.TestCase):
    """When rules conflict on the same file, priority determines which wins."""

    def test_higher_priority_rule_wins_over_lower(self):
        """src/api/handler.py matches both src/** and src/api/**;
        the higher-priority (lower number) rule should win."""
        rules = [
            Rule(pattern="src/**", label="source", priority=10),
            Rule(pattern="src/api/**", label="api", priority=1),
        ]
        labels = assign_labels(["src/api/handler.py"], rules)
        self.assertEqual(labels, {"api"})

    def test_non_conflicting_rules_both_apply(self):
        """Rules that match different files shouldn't conflict."""
        rules = [
            Rule(pattern="src/**", label="source", priority=10),
            Rule(pattern="docs/**", label="documentation", priority=5),
        ]
        labels = assign_labels(["src/main.py", "docs/README.md"], rules)
        self.assertEqual(labels, {"source", "documentation"})

    def test_same_priority_keeps_all_labels(self):
        """When conflicting rules have equal priority, keep all labels."""
        rules = [
            Rule(pattern="src/**", label="source", priority=5),
            Rule(pattern="src/api/**", label="api", priority=5),
        ]
        labels = assign_labels(["src/api/handler.py"], rules)
        self.assertEqual(labels, {"source", "api"})

    def test_priority_only_affects_same_file(self):
        """Priority conflict resolution is per-file, not global.
        File A may get label X (high priority), file B gets label Y (low priority)."""
        rules = [
            Rule(pattern="src/api/**", label="api", priority=1),
            Rule(pattern="src/**", label="source", priority=10),
        ]
        files = ["src/api/handler.py", "src/utils.py"]
        labels = assign_labels(files, rules)
        # handler.py -> api wins (priority 1 < 10)
        # utils.py -> only source matches
        self.assertEqual(labels, {"api", "source"})

    def test_default_priority_is_zero(self):
        """Rules without explicit priority default to 0 (highest)."""
        rule = Rule(pattern="src/**", label="source")
        self.assertEqual(rule.priority, 0)


# =============================================================================
# TDD Cycle 5: Configurable rules from dict/JSON-like structure
# RED:   No way to load rules from configuration
# GREEN: Implement load_rules_from_config
# =============================================================================
class TestConfigLoading(unittest.TestCase):
    """Rules can be loaded from a list-of-dicts configuration format."""

    def test_load_basic_config(self):
        config = [
            {"pattern": "docs/**", "label": "documentation"},
            {"pattern": "src/api/**", "label": "api"},
        ]
        rules = load_rules_from_config(config)
        self.assertEqual(len(rules), 2)
        self.assertEqual(rules[0].pattern, "docs/**")
        self.assertEqual(rules[0].label, "documentation")
        self.assertEqual(rules[0].priority, 0)

    def test_load_config_with_priority(self):
        config = [
            {"pattern": "src/**", "label": "source", "priority": 10},
            {"pattern": "src/api/**", "label": "api", "priority": 1},
        ]
        rules = load_rules_from_config(config)
        self.assertEqual(rules[0].priority, 10)
        self.assertEqual(rules[1].priority, 1)

    def test_invalid_config_missing_pattern_raises(self):
        config = [{"label": "documentation"}]
        with self.assertRaises(ValueError) as ctx:
            load_rules_from_config(config)
        self.assertIn("pattern", str(ctx.exception))

    def test_invalid_config_missing_label_raises(self):
        config = [{"pattern": "docs/**"}]
        with self.assertRaises(ValueError) as ctx:
            load_rules_from_config(config)
        self.assertIn("label", str(ctx.exception))

    def test_empty_config_returns_empty_list(self):
        rules = load_rules_from_config([])
        self.assertEqual(rules, [])


# =============================================================================
# TDD Cycle 6: Edge cases and error handling
# RED:   Empty inputs, invalid types, etc. not handled
# GREEN: Add validation and graceful error handling
# =============================================================================
class TestEdgeCases(unittest.TestCase):
    """Edge cases: empty inputs, special characters, invalid data."""

    def test_empty_file_list(self):
        rules = [Rule(pattern="docs/**", label="documentation")]
        labels = assign_labels([], rules)
        self.assertEqual(labels, set())

    def test_empty_rules_list(self):
        labels = assign_labels(["docs/README.md"], [])
        self.assertEqual(labels, set())

    def test_both_empty(self):
        labels = assign_labels([], [])
        self.assertEqual(labels, set())

    def test_invalid_file_type_raises(self):
        """Passing non-string file paths should raise a clear error."""
        rules = [Rule(pattern="docs/**", label="documentation")]
        with self.assertRaises(TypeError) as ctx:
            assign_labels([123], rules)
        self.assertIn("string", str(ctx.exception).lower())

    def test_exact_filename_match(self):
        """Pattern without wildcards should match exactly."""
        rules = [Rule(pattern="Makefile", label="build")]
        labels = assign_labels(["Makefile"], rules)
        self.assertEqual(labels, {"build"})

    def test_exact_filename_no_partial_match(self):
        """Exact pattern should not partially match other files."""
        rules = [Rule(pattern="Makefile", label="build")]
        labels = assign_labels(["src/Makefile", "Makefile.bak"], rules)
        self.assertEqual(labels, set())

    def test_question_mark_glob(self):
        """? should match a single character."""
        rules = [Rule(pattern="src/?.py", label="short-names")]
        labels = assign_labels(["src/a.py", "src/ab.py"], rules)
        self.assertEqual(labels, {"short-names"})

    def test_bracket_glob(self):
        """[abc] should match character sets."""
        rules = [Rule(pattern="config.[jt]s", label="config")]
        labels = assign_labels(["config.js", "config.ts", "config.py"], rules)
        self.assertEqual(labels, {"config"})


# =============================================================================
# TDD Cycle 7: Integration test with realistic PR mock data
# RED:   No integration-level test
# GREEN: Combine all features into a realistic scenario
# =============================================================================
class TestIntegrationWithMockPR(unittest.TestCase):
    """End-to-end test with a realistic mock PR file list."""

    def test_realistic_pr_labels(self):
        """Simulate a PR that touches docs, API code, tests, and CI config."""
        config = [
            {"pattern": "docs/**", "label": "documentation", "priority": 5},
            {"pattern": "src/api/**", "label": "api", "priority": 1},
            {"pattern": "src/**", "label": "source", "priority": 10},
            {"pattern": "*.test.*", "label": "tests", "priority": 5},
            {"pattern": ".github/**", "label": "ci/cd", "priority": 3},
            {"pattern": "*.md", "label": "documentation", "priority": 8},
        ]
        rules = load_rules_from_config(config)

        # Mock PR changed files — each file is chosen so that the expected label
        # is unambiguous given the priority rules above.
        changed_files = [
            "docs/api-guide.md",           # docs/** (pri 5) + *.md (pri 8) -> documentation (pri 5 wins, same label)
            "src/api/handlers/user.py",    # src/api/** (pri 1) + src/** (pri 10) -> api (pri 1 wins)
            "src/utils/helpers.py",        # src/** (pri 10) only -> source
            "tests/unit/auth.test.js",     # *.test.* (pri 5) only -> tests
            ".github/workflows/ci.yml",    # .github/** (pri 3) -> ci/cd
            "README.md",                   # *.md (pri 8) -> documentation
        ]

        labels = assign_labels(changed_files, rules)

        # Expected: documentation, api, tests, source, ci/cd
        self.assertIn("documentation", labels)
        self.assertIn("api", labels)
        self.assertIn("source", labels)
        self.assertIn("ci/cd", labels)
        self.assertIn("tests", labels)

    def test_small_docs_only_pr(self):
        """A PR that only changes documentation files."""
        config = [
            {"pattern": "docs/**", "label": "documentation"},
            {"pattern": "src/**", "label": "source"},
            {"pattern": "*.test.*", "label": "tests"},
        ]
        rules = load_rules_from_config(config)
        changed_files = ["docs/README.md", "docs/contributing.md"]
        labels = assign_labels(changed_files, rules)
        self.assertEqual(labels, {"documentation"})


if __name__ == "__main__":
    unittest.main()
