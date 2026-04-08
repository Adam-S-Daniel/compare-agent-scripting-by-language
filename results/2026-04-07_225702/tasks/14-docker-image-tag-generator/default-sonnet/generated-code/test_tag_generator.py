"""
Docker Image Tag Generator - TDD test suite.

Red/green cycle:
  1. Write a failing test
  2. Write minimum code to pass
  3. Refactor
  Repeat for each piece of functionality.
"""

import pytest
from tag_generator import generate_tags, sanitize_tag


# ─────────────────────────────────────────────
# Cycle 1: tag sanitization
# ─────────────────────────────────────────────

class TestSanitizeTag:
    def test_lowercase(self):
        # Tags must be lowercase
        assert sanitize_tag("MyBranch") == "mybranch"

    def test_replace_slashes(self):
        # Forward-slashes in branch names must become dashes
        assert sanitize_tag("feature/my-thing") == "feature-my-thing"

    def test_replace_special_chars(self):
        # Only alphanumerics and dashes are allowed
        assert sanitize_tag("feat_foo@bar") == "feat-foo-bar"

    def test_collapse_repeated_dashes(self):
        # Multiple consecutive dashes collapse to one
        assert sanitize_tag("a--b") == "a-b"

    def test_strip_leading_trailing_dashes(self):
        assert sanitize_tag("-hello-") == "hello"

    def test_already_clean(self):
        assert sanitize_tag("already-clean") == "already-clean"


# ─────────────────────────────────────────────
# Cycle 2: main-branch context → "latest"
# ─────────────────────────────────────────────

class TestMainBranch:
    def test_main_branch_produces_latest(self):
        ctx = {"branch": "main", "sha": "abc1234", "tags": [], "pr_number": None}
        assert "latest" in generate_tags(ctx)

    def test_master_branch_produces_latest(self):
        ctx = {"branch": "master", "sha": "abc1234", "tags": [], "pr_number": None}
        assert "latest" in generate_tags(ctx)

    def test_main_also_includes_sha_tag(self):
        # main still gets a sha-pinned tag for reproducibility; SHA is truncated to 8 chars
        ctx = {"branch": "main", "sha": "abc1234def5", "tags": [], "pr_number": None}
        tags = generate_tags(ctx)
        assert "main-abc1234d" in tags  # first 8 chars of "abc1234def5"


# ─────────────────────────────────────────────
# Cycle 3: pull-request context → "pr-{number}"
# ─────────────────────────────────────────────

class TestPullRequest:
    def test_pr_tag_generated(self):
        ctx = {"branch": "feature/foo", "sha": "deadbeef", "tags": [], "pr_number": 42}
        assert "pr-42" in generate_tags(ctx)

    def test_no_latest_for_pr(self):
        ctx = {"branch": "feature/foo", "sha": "deadbeef", "tags": [], "pr_number": 42}
        assert "latest" not in generate_tags(ctx)

    def test_pr_also_includes_branch_sha(self):
        ctx = {"branch": "feature/foo", "sha": "deadbeef12", "tags": [], "pr_number": 42}
        tags = generate_tags(ctx)
        assert "feature-foo-deadbeef" in tags


# ─────────────────────────────────────────────
# Cycle 4: semver git tag → "v{semver}"
# ─────────────────────────────────────────────

class TestSemverTag:
    def test_semver_tag_included(self):
        ctx = {"branch": "main", "sha": "cafe1234", "tags": ["v1.2.3"], "pr_number": None}
        assert "v1.2.3" in generate_tags(ctx)

    def test_multiple_semver_tags(self):
        ctx = {"branch": "main", "sha": "cafe1234", "tags": ["v1.2.3", "v1.2"], "pr_number": None}
        tags = generate_tags(ctx)
        assert "v1.2.3" in tags
        assert "v1.2" in tags

    def test_non_semver_git_tag_sanitized(self):
        # A git tag like "release/1.0" should still be sanitized and included
        ctx = {"branch": "main", "sha": "cafe1234", "tags": ["release/1.0"], "pr_number": None}
        assert "release-1.0" in generate_tags(ctx)


# ─────────────────────────────────────────────
# Cycle 5: feature branch → "{branch}-{short-sha}"
# ─────────────────────────────────────────────

class TestFeatureBranch:
    def test_feature_branch_tag(self):
        ctx = {"branch": "feature/my-widget", "sha": "1a2b3c4d5e", "tags": [], "pr_number": None}
        tags = generate_tags(ctx)
        assert "feature-my-widget-1a2b3c4d" in tags

    def test_sha_truncated_to_8_chars(self):
        ctx = {"branch": "dev", "sha": "abcdef1234567890", "tags": [], "pr_number": None}
        tags = generate_tags(ctx)
        assert "dev-abcdef12" in tags

    def test_no_latest_for_feature_branch(self):
        ctx = {"branch": "feature/stuff", "sha": "aabbccdd", "tags": [], "pr_number": None}
        assert "latest" not in generate_tags(ctx)


# ─────────────────────────────────────────────
# Cycle 6: error / edge-case handling
# ─────────────────────────────────────────────

class TestEdgeCases:
    def test_missing_sha_raises(self):
        ctx = {"branch": "main", "sha": "", "tags": [], "pr_number": None}
        with pytest.raises(ValueError, match="sha"):
            generate_tags(ctx)

    def test_missing_branch_raises(self):
        ctx = {"branch": "", "sha": "abc1234", "tags": [], "pr_number": None}
        with pytest.raises(ValueError, match="branch"):
            generate_tags(ctx)

    def test_tags_deduplicated(self):
        # If branch name + sanitized git tag would produce the same string, deduplicate
        ctx = {"branch": "main", "sha": "abc1234", "tags": ["v1.0"], "pr_number": None}
        tags = generate_tags(ctx)
        assert len(tags) == len(set(tags)), "duplicate tags found"

    def test_uppercase_branch_sanitized(self):
        ctx = {"branch": "Feature/MyWidget", "sha": "aabbccdd", "tags": [], "pr_number": None}
        tags = generate_tags(ctx)
        assert all(t == t.lower() for t in tags), "all tags must be lowercase"
