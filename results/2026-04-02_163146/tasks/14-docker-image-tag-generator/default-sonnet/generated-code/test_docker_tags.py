"""
Docker Image Tag Generator - TDD Tests

Approach:
- Test each tag generation rule in isolation using mock git context
- Red/green cycle: write failing test -> implement minimum code -> refactor
- GitContext is a simple dataclass for testability (no real git calls)
"""

import unittest

# We import from the module we're about to create
from docker_tags import generate_tags, GitContext


class TestMainBranchLatestTag(unittest.TestCase):
    """RED: main branch should produce 'latest' tag"""

    def test_main_branch_produces_latest(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIn("latest", tags)

    def test_master_branch_produces_latest(self):
        ctx = GitContext(branch="master", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIn("latest", tags)


class TestPRBranchTag(unittest.TestCase):
    """RED: PR context should produce 'pr-{number}' tag"""

    def test_pr_produces_pr_number_tag(self):
        ctx = GitContext(branch="feature/my-feature", sha="abc1234def5678", tags=[], pr_number=42)
        tags = generate_tags(ctx)
        self.assertIn("pr-42", tags)

    def test_pr_zero_not_included_when_no_pr(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        # No pr-N tag should appear when pr_number is None
        pr_tags = [t for t in tags if t.startswith("pr-")]
        self.assertEqual(pr_tags, [])


class TestSemverTagGeneration(unittest.TestCase):
    """RED: git semver tags should produce 'v{semver}' tags"""

    def test_semver_tag_produces_v_prefixed_tag(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=["v1.2.3"], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIn("v1.2.3", tags)

    def test_multiple_semver_tags_all_included(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=["v2.0.0", "v2.0.0-rc1"], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIn("v2.0.0", tags)
        self.assertIn("v2.0.0-rc1", tags)

    def test_non_semver_tags_excluded(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=["not-a-version"], pr_number=None)
        tags = generate_tags(ctx)
        # Non-semver tags (not matching v\d+.\d+.\d+) should be excluded
        self.assertNotIn("not-a-version", tags)


class TestFeatureBranchTag(unittest.TestCase):
    """RED: feature branches should produce '{branch}-{short-sha}' tags"""

    def test_feature_branch_produces_branch_sha_tag(self):
        ctx = GitContext(branch="feature/my-feature", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        # Short SHA = first 7 chars
        self.assertIn("feature-my-feature-abc1234", tags)

    def test_sha_truncated_to_7_chars(self):
        ctx = GitContext(branch="dev", sha="deadbeef12345678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIn("dev-deadbee", tags)


class TestTagSanitization(unittest.TestCase):
    """RED: tags must be lowercase and contain only [a-z0-9._-]"""

    def test_branch_name_uppercased_is_lowercased(self):
        ctx = GitContext(branch="Feature/MyFeature", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        # All tags must be lowercase
        for tag in tags:
            self.assertEqual(tag, tag.lower(), f"Tag '{tag}' is not lowercase")

    def test_slashes_replaced_with_hyphens(self):
        ctx = GitContext(branch="feature/my-feature", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        for tag in tags:
            self.assertNotIn("/", tag, f"Tag '{tag}' contains a slash")

    def test_special_chars_removed(self):
        ctx = GitContext(branch="feature/my_feature@v2", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        # Only alphanumeric, dot, hyphen, underscore allowed in Docker tags
        import re
        for tag in tags:
            self.assertTrue(re.match(r'^[a-z0-9._-]+$', tag),
                            f"Tag '{tag}' contains invalid characters")

    def test_leading_hyphens_stripped(self):
        ctx = GitContext(branch="-bad-branch", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        for tag in tags:
            self.assertFalse(tag.startswith("-"), f"Tag '{tag}' starts with a hyphen")


class TestCombinedScenarios(unittest.TestCase):
    """Integration tests combining multiple git context scenarios"""

    def test_main_with_semver_tag_produces_both(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=["v3.1.0"], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIn("latest", tags)
        self.assertIn("v3.1.0", tags)

    def test_pr_on_feature_branch_produces_pr_tag(self):
        ctx = GitContext(branch="feature/cool-feature", sha="abc1234def5678", tags=[], pr_number=7)
        tags = generate_tags(ctx)
        self.assertIn("pr-7", tags)
        # Feature branch tag should also be included
        self.assertIn("feature-cool-feature-abc1234", tags)

    def test_output_is_a_list(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=[], pr_number=None)
        tags = generate_tags(ctx)
        self.assertIsInstance(tags, list)

    def test_no_duplicate_tags(self):
        ctx = GitContext(branch="main", sha="abc1234def5678", tags=["v1.0.0"], pr_number=None)
        tags = generate_tags(ctx)
        self.assertEqual(len(tags), len(set(tags)), "Duplicate tags found")


if __name__ == "__main__":
    unittest.main()
