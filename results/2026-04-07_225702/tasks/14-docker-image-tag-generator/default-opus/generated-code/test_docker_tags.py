# Test suite for Docker image tag generator.
# Uses red/green TDD: each test was written before the implementation code.

import pytest
from docker_tags import generate_tags


# --- TDD Cycle 1: main branch produces "latest" ---

def test_main_branch_produces_latest():
    """The main branch should always get the 'latest' tag."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890")
    assert "latest" in tags


def test_master_branch_produces_latest():
    """'master' is treated the same as 'main'."""
    tags = generate_tags(branch="master", commit_sha="abc1234567890")
    assert "latest" in tags


# --- TDD Cycle 2: PR builds produce "pr-{number}" ---

def test_pr_number_produces_pr_tag():
    """A PR build should produce a pr-{number} tag."""
    tags = generate_tags(branch="feature/foo", commit_sha="abc1234567890", pr_number=42)
    assert "pr-42" in tags


def test_pr_on_main_also_gets_latest():
    """A PR targeting main should still get 'latest' if branch is main."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890", pr_number=10)
    assert "latest" in tags
    assert "pr-10" in tags


# --- TDD Cycle 3: Semver git tags produce version tags ---

def test_semver_tag_produces_version_tags():
    """A semver git tag like v1.2.3 should produce v1.2.3, v1.2, and v1."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890", tag="v1.2.3")
    assert "v1.2.3" in tags
    assert "v1.2" in tags
    assert "v1" in tags


def test_semver_tag_without_v_prefix():
    """A tag like '1.2.3' (no v) should still produce version tags."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890", tag="1.2.3")
    assert "v1.2.3" in tags
    assert "v1.2" in tags
    assert "v1" in tags


def test_prerelease_tag():
    """A prerelease tag like v2.0.0-rc.1 should produce only the full tag."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890", tag="v2.0.0-rc.1")
    assert "v2.0.0-rc.1" in tags
    # Prerelease should NOT produce shortened v2.0 / v2 aliases
    assert "v2.0" not in tags
    assert "v2" not in tags


# --- TDD Cycle 4: Feature branch produces {branch}-{short-sha} ---

def test_feature_branch_tag():
    """A non-main branch should produce a branch-sha tag."""
    tags = generate_tags(branch="feature/add-login", commit_sha="deadbeef12345")
    assert "feature-add-login-deadbee" in tags
    # Feature branches should NOT get "latest"
    assert "latest" not in tags


def test_branch_sha_uses_first_7_chars():
    """The short SHA should be exactly 7 characters."""
    tags = generate_tags(branch="develop", commit_sha="abc1234567890")
    assert "develop-abc1234" in tags


# --- TDD Cycle 5: Tag sanitization ---

def test_sanitize_uppercase():
    """Branch names with uppercase should be lowercased."""
    tags = generate_tags(branch="Feature/MyBranch", commit_sha="abc1234567890")
    assert "feature-mybranch-abc1234" in tags


def test_sanitize_special_characters():
    """Special characters in branch names become hyphens."""
    tags = generate_tags(branch="feature/foo@bar!baz", commit_sha="abc1234567890")
    assert "feature-foo-bar-baz-abc1234" in tags


def test_sanitize_collapses_hyphens():
    """Multiple consecutive special chars collapse to a single hyphen."""
    tags = generate_tags(branch="fix//double--slash", commit_sha="abc1234567890")
    assert "fix-double-slash-abc1234" in tags


def test_sanitize_tag_function():
    """Direct test of the sanitize_tag helper."""
    from docker_tags import sanitize_tag
    assert sanitize_tag("Feature/FOO@Bar") == "feature-foo-bar"
    assert sanitize_tag("---leading---") == "leading"
    assert sanitize_tag("dots.are.ok") == "dots.are.ok"


# --- TDD Cycle 6: Error handling and edge cases ---

def test_no_inputs_raises_error():
    """Calling with no git context at all should raise ValueError."""
    with pytest.raises(ValueError, match="(?i)at least one"):
        generate_tags()


def test_empty_strings_raises_error():
    """Empty strings for all inputs should raise ValueError."""
    with pytest.raises(ValueError, match="(?i)at least one"):
        generate_tags(branch="", commit_sha="", tag="")


def test_tag_only_no_branch():
    """A tag without a branch should still produce version tags."""
    tags = generate_tags(tag="v3.0.0")
    assert "v3.0.0" in tags
    assert "latest" not in tags


def test_non_semver_tag():
    """A non-semver git tag should be sanitized and included."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890", tag="nightly-build")
    assert "nightly-build" in tags


def test_deduplication():
    """Tags should be deduplicated."""
    tags = generate_tags(branch="main", commit_sha="abc1234567890")
    assert len(tags) == len(set(tags))


# --- TDD Cycle 7: Combined scenario (integration) ---

def test_full_release_scenario():
    """A tagged release on main with a SHA should produce all relevant tags."""
    tags = generate_tags(
        branch="main",
        commit_sha="deadbeef12345",
        tag="v2.1.0",
    )
    assert "latest" in tags
    assert "v2.1.0" in tags
    assert "v2.1" in tags
    assert "v2" in tags
    # Main branch should NOT get a branch-sha tag
    assert not any(t.startswith("main-") for t in tags)


def test_pr_on_feature_branch():
    """A PR from a feature branch should get both pr-N and branch-sha tags."""
    tags = generate_tags(
        branch="feature/cool-stuff",
        commit_sha="cafe1234567890",
        pr_number=99,
    )
    assert "pr-99" in tags
    assert "feature-cool-stuff-cafe123" in tags
    assert "latest" not in tags
