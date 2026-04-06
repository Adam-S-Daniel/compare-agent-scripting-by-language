#!/usr/bin/env python3
"""
Test suite for Docker Image Tag Generator — structured as TDD cycles.

Each section below represents a red/green/refactor cycle:
  1. Write a failing test (RED)
  2. Implement the minimum code to pass (GREEN)
  3. Refactor if needed

All tests are runnable with:  python -m pytest test_docker_tags.py -v
"""

import subprocess
import sys
import pytest

from docker_tags import generate_tags, sanitize_tag


# =========================================================================
# Cycle 1: main branch → "latest"
# =========================================================================

class TestMainBranchLatest:
    """RED: main branch should produce the 'latest' tag."""

    def test_main_branch_produces_latest(self):
        result = generate_tags(branch="main", commit_sha="abc1234def5678")
        assert "latest" in result

    def test_master_branch_also_produces_latest(self):
        """'master' is an alternative default branch name."""
        result = generate_tags(branch="master", commit_sha="abc1234")
        assert "latest" in result

    def test_main_branch_does_not_produce_branch_sha_tag(self):
        """main should only get 'latest', not a branch-sha tag."""
        result = generate_tags(branch="main", commit_sha="abc1234")
        assert result == ["latest"]


# =========================================================================
# Cycle 2: PR number → "pr-{number}"
# =========================================================================

class TestPRTags:
    """RED: a PR number should produce 'pr-{number}'."""

    def test_pr_number_produces_pr_tag(self):
        result = generate_tags(branch="feature/foo", commit_sha="abc1234", pr_number=42)
        assert "pr-42" in result

    def test_pr_tag_format(self):
        result = generate_tags(branch="fix/bar", commit_sha="1234567", pr_number=1)
        assert "pr-1" in result

    def test_pr_with_main_branch(self):
        """PR from main should include both pr-N and latest."""
        result = generate_tags(branch="main", commit_sha="abc1234", pr_number=99)
        assert "pr-99" in result
        assert "latest" in result


# =========================================================================
# Cycle 3: semver git tag → "v{semver}"
# =========================================================================

class TestSemverTags:
    """RED: a semver git tag should produce 'v{major}.{minor}.{patch}'."""

    def test_semver_tag_with_v_prefix(self):
        result = generate_tags(tag="v1.2.3", branch="main", commit_sha="abc1234")
        assert "v1.2.3" in result

    def test_semver_tag_without_v_prefix(self):
        """Tags like '1.2.3' (no v) should still get normalized to v1.2.3."""
        result = generate_tags(tag="1.2.3", branch="main", commit_sha="abc1234")
        assert "v1.2.3" in result

    def test_semver_prerelease(self):
        result = generate_tags(tag="v2.0.0-beta.1", branch="main", commit_sha="abc1234")
        assert "v2.0.0-beta.1" in result

    def test_semver_with_build_metadata(self):
        result = generate_tags(tag="v1.0.0+build.42", branch="main", commit_sha="abc")
        assert "v1.0.0-build.42" in result  # '+' sanitized to '-'


# =========================================================================
# Cycle 4: feature branch → "{branch}-{short_sha}"
# =========================================================================

class TestFeatureBranchTags:
    """RED: feature branches should produce '{branch}-{7-char-sha}'."""

    def test_simple_feature_branch(self):
        result = generate_tags(branch="feature/cool-thing", commit_sha="abc1234def5678")
        assert "feature-cool-thing-abc1234" in result

    def test_short_sha_is_7_chars(self):
        result = generate_tags(branch="dev", commit_sha="abcdef1234567890")
        tag = [t for t in result if t.startswith("dev-")][0]
        # The sha portion should be 7 characters
        sha_part = tag.split("-", 1)[1]
        assert len(sha_part) == 7

    def test_branch_without_sha_uses_branch_only(self):
        """If no commit SHA is provided, use just the sanitized branch name."""
        result = generate_tags(branch="develop")
        assert "develop" in result

    def test_nested_branch_slashes_become_hyphens(self):
        result = generate_tags(branch="feat/ui/button", commit_sha="1234567")
        assert "feat-ui-button-1234567" in result


# =========================================================================
# Cycle 5: tag sanitization
# =========================================================================

class TestSanitization:
    """RED: tags must be lowercased, special chars replaced, hyphens cleaned."""

    def test_uppercase_is_lowered(self):
        assert sanitize_tag("MyTag") == "mytag"

    def test_slashes_become_hyphens(self):
        assert sanitize_tag("feature/thing") == "feature-thing"

    def test_underscores_become_hyphens(self):
        assert sanitize_tag("my_branch") == "my-branch"

    def test_consecutive_hyphens_collapsed(self):
        assert sanitize_tag("a--b---c") == "a-b-c"

    def test_leading_trailing_hyphens_stripped(self):
        assert sanitize_tag("-hello-") == "hello"

    def test_special_chars_replaced(self):
        assert sanitize_tag("feat@2!x") == "feat-2-x"

    def test_dots_preserved(self):
        """Dots are valid in Docker tags and should be kept."""
        assert sanitize_tag("v1.2.3") == "v1.2.3"

    def test_empty_string_raises(self):
        with pytest.raises(ValueError, match="cannot be empty"):
            sanitize_tag("")

    def test_all_special_chars_raises(self):
        with pytest.raises(ValueError, match="empty after sanitization"):
            sanitize_tag("@#$%")


# =========================================================================
# Cycle 6: error handling
# =========================================================================

class TestErrorHandling:
    """RED: missing or invalid inputs should raise meaningful errors."""

    def test_no_context_raises(self):
        """Calling with no branch, tag, or PR should raise ValueError."""
        with pytest.raises(ValueError, match="Cannot generate tags"):
            generate_tags()

    def test_negative_pr_number_raises(self):
        with pytest.raises(ValueError, match="positive integer"):
            generate_tags(branch="main", pr_number=-1)

    def test_zero_pr_number_raises(self):
        with pytest.raises(ValueError, match="positive integer"):
            generate_tags(branch="main", pr_number=0)


# =========================================================================
# Cycle 7: combined contexts — multiple tags generated at once
# =========================================================================

class TestCombinedContexts:
    """RED: multiple inputs should produce multiple tags in priority order."""

    def test_tag_and_main_and_pr(self):
        """All three contexts present — should get semver, pr, and latest."""
        result = generate_tags(
            branch="main",
            commit_sha="abc1234",
            tag="v3.1.0",
            pr_number=55,
        )
        assert "v3.1.0" in result
        assert "pr-55" in result
        assert "latest" in result

    def test_tag_order_is_semver_pr_latest(self):
        """Tags should appear in a deterministic order: tag, pr, branch."""
        result = generate_tags(
            branch="main", commit_sha="abc1234", tag="v1.0.0", pr_number=10
        )
        assert result.index("v1.0.0") < result.index("pr-10")
        assert result.index("pr-10") < result.index("latest")

    def test_feature_branch_with_pr(self):
        result = generate_tags(
            branch="feature/login", commit_sha="deadbeef123", pr_number=7
        )
        assert "pr-7" in result
        assert "feature-login-deadbee" in result


# =========================================================================
# Cycle 8: CLI interface
# =========================================================================

class TestCLI:
    """RED: the CLI should accept flags and output tags."""

    def test_cli_main_branch(self):
        result = subprocess.run(
            [sys.executable, "docker_tags.py", "--branch", "main", "--sha", "abc1234"],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        assert "latest" in result.stdout

    def test_cli_json_output(self):
        result = subprocess.run(
            [sys.executable, "docker_tags.py", "--branch", "main", "--sha", "abc", "--json"],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        import json
        tags = json.loads(result.stdout)
        assert "latest" in tags

    def test_cli_no_args_errors(self):
        result = subprocess.run(
            [sys.executable, "docker_tags.py"],
            capture_output=True, text=True,
        )
        assert result.returncode != 0
        assert "Error" in result.stderr

    def test_cli_full_context(self):
        result = subprocess.run(
            [
                sys.executable, "docker_tags.py",
                "--branch", "feature/signup",
                "--sha", "deadbeef1234567",
                "--tag", "v2.0.0",
                "--pr", "42",
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        lines = result.stdout.strip().split("\n")
        assert "v2.0.0" in lines
        assert "pr-42" in lines
        assert "feature-signup-deadbee" in lines
