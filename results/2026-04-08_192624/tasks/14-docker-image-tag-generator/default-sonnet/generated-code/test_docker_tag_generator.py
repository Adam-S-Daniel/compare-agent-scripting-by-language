#!/usr/bin/env python3
"""
test_docker_tag_generator.py - TDD tests for Docker Image Tag Generator

Following red/green/refactor TDD methodology:
  RED:     Write a failing test for each piece of functionality first.
  GREEN:   Write minimum code to make the test pass.
  REFACTOR: Clean up without changing behavior.

These tests were written BEFORE the implementation in docker_tag_generator.py.
Running them without the implementation would produce NameError/ImportError (red).
The implementation was then added to make them pass (green).
"""

import pytest
from docker_tag_generator import generate_tags, sanitize_tag, is_semver_tag


# ============================================================================
# TDD CYCLE 1: Tag Sanitization
# RED: Written before sanitize_tag() was implemented — would fail with NameError.
# GREEN: Implemented sanitize_tag() with lowercase + regex substitution.
# ============================================================================

class TestSanitizeTag:
    """Tests for Docker tag component sanitization."""

    def test_converts_to_lowercase(self):
        # Docker tags must be lowercase only
        assert sanitize_tag("MyBranch") == "mybranch"

    def test_replaces_slashes_with_hyphens(self):
        # Branch names like 'feature/foo' need slashes replaced
        assert sanitize_tag("feature/my-branch") == "feature-my-branch"

    def test_replaces_underscores_with_hyphens(self):
        # Underscores are replaced in our strict format
        assert sanitize_tag("my_feature") == "my-feature"

    def test_collapses_consecutive_special_chars(self):
        # Multiple invalid chars in a row → single hyphen
        assert sanitize_tag("feature//my--branch") == "feature-my-branch"

    def test_strips_leading_hyphens(self):
        # Leading slashes/hyphens removed
        assert sanitize_tag("/feature/") == "feature"

    def test_strips_trailing_hyphens(self):
        # Trailing invalid chars removed
        assert sanitize_tag("feature-") == "feature"

    def test_mixed_case_and_special_chars(self):
        # Real-world branch name: uppercase + underscores + slashes
        assert sanitize_tag("Feature/My_Branch_123") == "feature-my-branch-123"

    def test_already_valid_tag_unchanged(self):
        # Valid tags should pass through unchanged
        assert sanitize_tag("feature-my-branch") == "feature-my-branch"

    def test_numbers_preserved(self):
        # Numbers are valid in tags
        assert sanitize_tag("release-123") == "release-123"

    def test_dots_replaced(self):
        # Dots in branch names (e.g. fix/bug.123) → hyphens
        assert sanitize_tag("fix/bug.123") == "fix-bug-123"


# ============================================================================
# TDD CYCLE 2: Semver Tag Detection
# RED: Written before is_semver_tag() was implemented.
# GREEN: Implemented with regex ^v\d+\.\d+\.\d+$
# ============================================================================

class TestIsSemverTag:
    """Tests for semantic version tag detection."""

    def test_valid_semver_with_v_prefix(self):
        assert is_semver_tag("v1.2.3") is True

    def test_valid_semver_double_digits(self):
        assert is_semver_tag("v10.20.30") is True

    def test_valid_semver_zero_versions(self):
        assert is_semver_tag("v0.0.1") is True

    def test_invalid_missing_v_prefix(self):
        # Must have 'v' prefix
        assert is_semver_tag("1.2.3") is False

    def test_invalid_missing_patch(self):
        # Must have all three version components
        assert is_semver_tag("v1.2") is False

    def test_invalid_non_numeric(self):
        # Version numbers must be numeric
        assert is_semver_tag("vX.Y.Z") is False

    def test_invalid_feature_branch(self):
        # Branch names are not semver tags
        assert is_semver_tag("feature/v1.2.3") is False

    def test_invalid_random_string(self):
        assert is_semver_tag("latest") is False

    def test_invalid_empty_string(self):
        assert is_semver_tag("") is False


# ============================================================================
# TDD CYCLE 3: Main Branch Tags
# RED: Written before main-branch logic in generate_tags() was added.
# GREEN: Added 'if branch in ("main", "master"): tags.add("latest")'
# ============================================================================

class TestMainBranchTags:
    """Tests for main/master branch tagging behavior."""

    def test_main_branch_gets_latest(self):
        # Main branch always produces 'latest' tag
        tags = generate_tags(branch="main", commit_sha="abc1234def5678")
        assert "latest" in tags

    def test_master_branch_gets_latest(self):
        # Legacy 'master' branch also gets 'latest'
        tags = generate_tags(branch="master", commit_sha="abc1234def5678")
        assert "latest" in tags

    def test_main_branch_only_gets_latest(self):
        # Main branch should produce ONLY 'latest' (not a branch-sha combo)
        tags = generate_tags(branch="main", commit_sha="abc1234def5678")
        assert tags == ["latest"]

    def test_main_branch_with_semver_tag_gets_both(self):
        # When main is also tagged vX.Y.Z, get version AND latest
        tags = generate_tags(
            branch="main",
            commit_sha="abc1234def5678",
            git_tags=["v1.2.3"],
        )
        assert sorted(tags) == ["latest", "v1.2.3"]


# ============================================================================
# TDD CYCLE 4: Pull Request Tags
# RED: Written before PR handling in generate_tags() was added.
# GREEN: Added 'if pr_number: return sorted({"pr-" + str(pr_number)})'
# ============================================================================

class TestPullRequestTags:
    """Tests for pull request tagging behavior."""

    def test_pr_gets_pr_number_tag(self):
        # PR builds should be tagged with pr-{number}
        tags = generate_tags(
            branch="feature/foo",
            commit_sha="abc1234def5678",
            pr_number="42",
        )
        assert "pr-42" in tags

    def test_pr_only_gets_pr_tag(self):
        # PR builds get ONLY the pr tag, not branch-sha
        tags = generate_tags(
            branch="feature/foo",
            commit_sha="abc1234def5678",
            pr_number="42",
        )
        assert tags == ["pr-42"]

    def test_different_pr_numbers_work(self):
        # Ensure various PR numbers produce correct tags
        for pr_num in ["1", "99", "1234"]:
            tags = generate_tags(branch="main", commit_sha="abc1234", pr_number=pr_num)
            assert f"pr-{pr_num}" in tags


# ============================================================================
# TDD CYCLE 5: Feature Branch Tags
# RED: Written before feature-branch logic was added.
# GREEN: Added sanitize_tag(branch) + short SHA concatenation.
# ============================================================================

class TestFeatureBranchTags:
    """Tests for feature branch tagging behavior."""

    def test_feature_branch_gets_branch_sha_tag(self):
        # Feature branches get {sanitized-branch}-{short-sha}
        tags = generate_tags(
            branch="feature/my-feature",
            commit_sha="abc1234def5678",
        )
        assert "feature-my-feature-abc1234" in tags

    def test_short_sha_is_first_7_chars(self):
        # Short SHA uses first 7 characters of the full SHA
        tags = generate_tags(branch="feature/foo", commit_sha="abc1234def5678")
        # short_sha = "abc1234"
        assert any("abc1234" in tag for tag in tags)

    def test_branch_name_sanitized_in_tag(self):
        # Branch name sanitized: lowercase, no special chars
        tags = generate_tags(branch="Feature/My_Branch", commit_sha="abc1234def5678")
        assert "feature-my-branch-abc1234" in tags

    def test_branch_with_dots_sanitized(self):
        # Dots in branch names become hyphens
        tags = generate_tags(branch="fix/bug.123", commit_sha="abc1234def5678")
        assert "fix-bug-123-abc1234" in tags


# ============================================================================
# TDD CYCLE 6: Semver Git Tags
# RED: Written before git_tags processing loop was added.
# GREEN: Added loop over git_tags checking is_semver_tag().
# ============================================================================

class TestSemverGitTags:
    """Tests for git semver tag handling."""

    def test_semver_tag_produces_version_tag(self):
        # Commit tagged vX.Y.Z → that version appears in output
        tags = generate_tags(
            branch="main",
            commit_sha="abc1234def5678",
            git_tags=["v1.2.3"],
        )
        assert "v1.2.3" in tags

    def test_semver_tag_also_produces_latest(self):
        # Semver releases get 'latest' as well
        tags = generate_tags(
            branch="main",
            commit_sha="abc1234def5678",
            git_tags=["v1.2.3"],
        )
        assert "latest" in tags

    def test_non_semver_git_tag_ignored(self):
        # Tags that don't match vX.Y.Z are ignored
        tags = generate_tags(
            branch="feature/foo",
            commit_sha="abc1234def5678",
            git_tags=["release-candidate", "nightly"],
        )
        assert "release-candidate" not in tags
        assert "nightly" not in tags

    def test_no_duplicate_tags(self):
        # Tags must be deduplicated
        tags = generate_tags(
            branch="main",
            commit_sha="abc1234def5678",
            git_tags=["v1.2.3"],
        )
        assert len(tags) == len(set(tags))

    def test_output_is_sorted(self):
        # Output should be sorted for determinism
        tags = generate_tags(
            branch="main",
            commit_sha="abc1234def5678",
            git_tags=["v1.2.3"],
        )
        assert tags == sorted(tags)
