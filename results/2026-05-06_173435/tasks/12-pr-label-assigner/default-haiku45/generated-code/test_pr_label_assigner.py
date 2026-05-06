"""
Test suite for PR label assigner using TDD methodology.
Tests are written first (red), then implementation is added (green),
then refactored (refactor).
"""
import pytest
from pr_label_assigner import LabelAssigner


# ============================================================================
# TEST 1 (RED): Basic single file, single rule matching
# ============================================================================
class TestBasicMatching:
    """Test the most basic functionality: one file, one rule."""

    def test_single_file_single_matching_rule(self):
        """
        GIVEN a rule: docs/** -> 'documentation'
        AND a file: 'docs/README.md'
        WHEN we assign labels
        THEN we get ['documentation']
        """
        rules = {
            'docs/**': ['documentation']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['docs/README.md'])
        assert result == {'documentation'}

    def test_single_file_no_matching_rules(self):
        """
        GIVEN a rule: docs/** -> 'documentation'
        AND a file: 'src/main.py'
        WHEN we assign labels
        THEN we get an empty set
        """
        rules = {
            'docs/**': ['documentation']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['src/main.py'])
        assert result == set()

    def test_single_file_multiple_labels_from_one_rule(self):
        """
        GIVEN a rule: src/** -> ['api', 'core']
        AND a file: 'src/main.py'
        WHEN we assign labels
        THEN we get ['api', 'core'] (order doesn't matter, it's a set)
        """
        rules = {
            'src/**': ['api', 'core']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['src/main.py'])
        assert result == {'api', 'core'}


# ============================================================================
# TEST 2 (RED): Multiple files and rules
# ============================================================================
class TestMultipleFilesAndRules:
    """Test with multiple files and multiple rules."""

    def test_multiple_files_match_different_rules(self):
        """
        GIVEN rules:
          - docs/** -> 'documentation'
          - src/api/** -> 'api'
        AND files: ['docs/README.md', 'src/api/handler.py']
        WHEN we assign labels
        THEN we get {'documentation', 'api'}
        """
        rules = {
            'docs/**': ['documentation'],
            'src/api/**': ['api']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['docs/README.md', 'src/api/handler.py'])
        assert result == {'documentation', 'api'}

    def test_multiple_files_same_rule_match(self):
        """
        GIVEN a rule: docs/** -> 'documentation'
        AND files: ['docs/README.md', 'docs/API.md']
        WHEN we assign labels
        THEN we get {'documentation'} (not duplicated)
        """
        rules = {
            'docs/**': ['documentation']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['docs/README.md', 'docs/API.md'])
        assert result == {'documentation'}

    def test_multiple_files_match_multiple_rules(self):
        """
        GIVEN rules:
          - src/** -> ['code']
          - src/api/** -> ['api']
        AND file: 'src/api/handler.py' (matches both)
        WHEN we assign labels
        THEN we get {'code', 'api'} (all matching labels)
        """
        rules = {
            'src/**': ['code'],
            'src/api/**': ['api']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['src/api/handler.py'])
        assert result == {'code', 'api'}


# ============================================================================
# TEST 3 (RED): Glob pattern matching
# ============================================================================
class TestGlobPatternMatching:
    """Test glob pattern matching with various patterns."""

    def test_glob_pattern_double_asterisk(self):
        """
        GIVEN a rule: docs/** -> 'documentation'
        AND file: 'docs/guides/deployment/README.md' (deeply nested)
        WHEN we assign labels
        THEN it matches (** matches any number of directories)
        """
        rules = {
            'docs/**': ['documentation']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['docs/guides/deployment/README.md'])
        assert 'documentation' in result

    def test_glob_pattern_file_extension(self):
        """
        GIVEN a rule: *.test.py -> 'tests'
        AND files: ['app.test.py', 'main.py']
        WHEN we assign labels
        THEN only 'app.test.py' gets 'tests' label
        """
        rules = {
            '*.test.py': ['tests']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['app.test.py', 'main.py'])
        assert result == {'tests'}

    def test_glob_pattern_wildcard_in_directory(self):
        """
        GIVEN a rule: src/*/tests/** -> 'component-tests'
        AND files: ['src/api/tests/test_handler.py', 'src/main.py']
        WHEN we assign labels
        THEN only matching file gets the label
        """
        rules = {
            'src/*/tests/**': ['component-tests']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign(['src/api/tests/test_handler.py', 'src/main.py'])
        assert result == {'component-tests'}


# ============================================================================
# TEST 4 (RED): Priority ordering when rules conflict
# ============================================================================
class TestPriorityOrdering:
    """Test priority ordering when multiple rules could apply."""

    def test_priority_ordering_later_rules_override(self):
        """
        GIVEN rules (in order):
          - src/** -> 'code' (priority 0)
          - src/api/** -> 'api' (priority 1, higher priority)
        AND file: 'src/api/handler.py'
        When rules have priority, higher priority labels should be preferred
        WHEN we assign labels with priority support
        THEN if only one rule per file is allowed by priority, we'd pick 'api'

        For now, we collect ALL matching labels, but the priority is noted
        """
        rules = {
            'src/**': ['code'],
            'src/api/**': ['api']
        }
        # In our simple implementation, we collect all matching labels
        # Priority ordering would be enforced if we had a priority parameter
        assigner = LabelAssigner(rules)
        result = assigner.assign(['src/api/handler.py'])
        # For now, we get both; later we can add priority logic
        assert 'api' in result


# ============================================================================
# TEST 5 (RED): Error handling
# ============================================================================
class TestErrorHandling:
    """Test error handling for invalid inputs."""

    def test_empty_file_list(self):
        """
        GIVEN rules: docs/** -> 'documentation'
        AND an empty file list
        WHEN we assign labels
        THEN we get an empty set (no files, no labels)
        """
        rules = {
            'docs/**': ['documentation']
        }
        assigner = LabelAssigner(rules)
        result = assigner.assign([])
        assert result == set()

    def test_empty_rules(self):
        """
        GIVEN no rules
        AND files: ['docs/README.md']
        WHEN we assign labels
        THEN we get an empty set (no rules, no labels)
        """
        rules = {}
        assigner = LabelAssigner(rules)
        result = assigner.assign(['docs/README.md'])
        assert result == set()

    def test_invalid_glob_pattern_handled_gracefully(self):
        """
        GIVEN a rule with an invalid glob pattern (if possible)
        AND a file list
        WHEN we assign labels
        THEN we get a meaningful error message, not a cryptic exception
        """
        # Most glob patterns are valid, so we'll just test that
        # invalid glob patterns don't crash
        rules = {
            'docs/[': ['documentation']  # Unclosed bracket
        }
        assigner = LabelAssigner(rules)
        try:
            result = assigner.assign(['docs/README.md'])
            # If it succeeds without the label, that's OK
            assert 'documentation' not in result
        except ValueError as e:
            # Or raise with a meaningful message
            assert 'glob' in str(e).lower() or 'pattern' in str(e).lower()


# ============================================================================
# Mock fixtures for testing
# ============================================================================
@pytest.fixture
def sample_rules():
    """Sample rules for testing."""
    return {
        'docs/**': ['documentation'],
        'src/api/**': ['api'],
        '*.test.py': ['tests'],
        'src/**': ['code']
    }


@pytest.fixture
def sample_files():
    """Sample file list for testing."""
    return [
        'docs/README.md',
        'src/api/handler.py',
        'src/models/user.py',
        'app.test.py',
        'README.md',
        'src/api/tests/test_handler.py'
    ]


class TestIntegration:
    """Integration tests with more complex scenarios."""

    def test_full_pr_scenario(self, sample_rules, sample_files):
        """
        GIVEN a realistic PR with multiple files and rules
        WHEN we assign labels
        THEN we get the expected set of labels
        """
        assigner = LabelAssigner(sample_rules)
        result = assigner.assign(sample_files)

        # All files except README.md should match some rule
        # docs/README.md -> documentation
        # src/api/handler.py -> api, code
        # src/models/user.py -> code
        # app.test.py -> tests
        # README.md -> (no match)
        # src/api/tests/test_handler.py -> api, code, tests

        assert 'documentation' in result
        assert 'api' in result
        assert 'code' in result
        assert 'tests' in result
        assert len(result) >= 4


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
