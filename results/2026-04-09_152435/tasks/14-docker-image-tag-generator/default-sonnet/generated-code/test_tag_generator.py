"""
Tests for Docker image tag generator.

TDD approach: tests written FIRST (red), then tag_generator.py implemented (green).

Test cases designed upfront to cover all conventions:
- main/master branch -> latest + branch-sha
- PR -> pr-{number} only
- Semver git tag -> v{semver} + latest
- Feature branch -> sanitized-branch-sha
- Tag sanitization: lowercase, special chars -> dashes
"""
import pytest
import subprocess
import os
import yaml

# These imports will fail until tag_generator.py is implemented (RED phase)
from tag_generator import generate_tags, sanitize_tag, get_short_sha


# --- Fixtures: designed upfront for all test cases ---
FIXTURES = [
    {
        "id": "main_branch",
        "branch": "main",
        "sha": "abc1234def5678",
        "tags": [],
        "pr_number": "",
        "expected": ["latest", "main-abc1234"],
    },
    {
        "id": "master_branch",
        "branch": "master",
        "sha": "abc1234def5678",
        "tags": [],
        "pr_number": "",
        "expected": ["latest", "master-abc1234"],
    },
    {
        "id": "pr",
        "branch": "feature/test",
        "sha": "def5678abc1234",
        "tags": [],
        "pr_number": "42",
        "expected": ["pr-42"],
    },
    {
        "id": "semver_tag",
        "branch": "refs/tags/v1.2.3",
        "sha": "abc1234def5678",
        "tags": ["v1.2.3"],
        "pr_number": "",
        "expected": ["v1.2.3", "latest"],
    },
    {
        "id": "feature_branch",
        "branch": "feature/my-new-feature",
        "sha": "abc1234def5678",
        "tags": [],
        "pr_number": "",
        "expected": ["feature-my-new-feature-abc1234"],
    },
    {
        "id": "branch_special_chars",
        "branch": "feat/My Feature/JIRA-123",
        "sha": "abc1234def5678",
        "tags": [],
        "pr_number": "",
        "expected": ["feat-my-feature-jira-123-abc1234"],
    },
    {
        "id": "refs_heads_main",
        "branch": "refs/heads/main",
        "sha": "abc1234def5678",
        "tags": [],
        "pr_number": "",
        "expected": ["latest", "main-abc1234"],
    },
    {
        "id": "refs_heads_feature",
        "branch": "refs/heads/feature/foo",
        "sha": "abc1234def5678",
        "tags": [],
        "pr_number": "",
        "expected": ["feature-foo-abc1234"],
    },
]


# --- Unit tests for sanitize_tag ---

class TestSanitizeTag:
    def test_lowercase(self):
        """Tags must be lowercase for Docker compatibility."""
        assert sanitize_tag("MyTag") == "mytag"

    def test_slashes_become_dashes(self):
        """Forward slashes in branch names must become dashes."""
        assert sanitize_tag("feature/my-feature") == "feature-my-feature"

    def test_spaces_become_dashes(self):
        """Spaces are not valid in Docker tags."""
        assert sanitize_tag("my feature") == "my-feature"

    def test_collapse_consecutive_dashes(self):
        """Multiple dashes should be collapsed to one."""
        assert sanitize_tag("my--feature") == "my-feature"

    def test_strip_leading_trailing_dashes(self):
        """Leading/trailing dashes are not valid."""
        assert sanitize_tag("-my-tag-") == "my-tag"

    def test_dots_preserved(self):
        """Dots are valid in Docker tags (e.g., v1.2.3)."""
        assert sanitize_tag("v1.2.3") == "v1.2.3"

    def test_mixed_special_chars(self):
        """Multiple special chars all become dashes."""
        assert sanitize_tag("feat/My Feature/JIRA-123") == "feat-my-feature-jira-123"

    def test_underscores_preserved(self):
        """Underscores are valid in Docker tags."""
        assert sanitize_tag("my_tag") == "my_tag"


# --- Unit tests for get_short_sha ---

class TestGetShortSha:
    def test_returns_7_chars(self):
        """Short SHA is first 7 chars of commit SHA."""
        assert get_short_sha("abc1234def5678") == "abc1234"

    def test_short_sha_already_short(self):
        """If SHA is exactly 7 chars, return as-is."""
        assert get_short_sha("abc1234") == "abc1234"

    def test_empty_sha(self):
        """Empty SHA returns empty string."""
        assert get_short_sha("") == ""


# --- Unit tests for generate_tags ---

class TestGenerateTags:
    def test_main_branch_has_latest(self):
        """Main branch always gets the 'latest' tag."""
        tags = generate_tags("main", "abc1234def5678", [], "")
        assert "latest" in tags

    def test_main_branch_has_branch_sha(self):
        """Main branch gets branch-sha tag for traceability."""
        tags = generate_tags("main", "abc1234def5678", [], "")
        assert "main-abc1234" in tags

    def test_master_branch_has_latest(self):
        """'master' is treated the same as 'main'."""
        tags = generate_tags("master", "abc1234def5678", [], "")
        assert "latest" in tags

    def test_master_branch_has_branch_sha(self):
        tags = generate_tags("master", "abc1234def5678", [], "")
        assert "master-abc1234" in tags

    def test_pr_gets_pr_tag(self):
        """PRs get pr-{number} tag."""
        tags = generate_tags("feature/test", "def5678abc1234", [], "42")
        assert "pr-42" in tags

    def test_pr_no_latest(self):
        """PRs must NOT get 'latest' tag - only goes to main."""
        tags = generate_tags("feature/test", "def5678abc1234", [], "42")
        assert "latest" not in tags

    def test_pr_only_pr_tag(self):
        """PRs should only produce the pr-{number} tag."""
        tags = generate_tags("feature/test", "def5678abc1234", [], "42")
        assert tags == ["pr-42"]

    def test_semver_tag_included(self):
        """Semver git tags get v{semver} Docker tag."""
        tags = generate_tags("refs/tags/v1.2.3", "abc1234def5678", ["v1.2.3"], "")
        assert "v1.2.3" in tags

    def test_semver_tag_also_gets_latest(self):
        """Semver releases also get 'latest' tag."""
        tags = generate_tags("refs/tags/v1.2.3", "abc1234def5678", ["v1.2.3"], "")
        assert "latest" in tags

    def test_feature_branch_gets_branch_sha(self):
        """Feature branches get sanitized-branch-shortsha tag."""
        tags = generate_tags("feature/my-new-feature", "abc1234def5678", [], "")
        assert "feature-my-new-feature-abc1234" in tags

    def test_feature_branch_no_latest(self):
        """Feature branches must NOT get 'latest'."""
        tags = generate_tags("feature/my-new-feature", "abc1234def5678", [], "")
        assert "latest" not in tags

    def test_branch_special_chars_sanitized(self):
        """Branch names with uppercase and spaces get sanitized."""
        tags = generate_tags("feat/My Feature/JIRA-123", "abc1234def5678", [], "")
        assert "feat-my-feature-jira-123-abc1234" in tags

    def test_refs_heads_prefix_stripped(self):
        """refs/heads/ prefix is stripped before processing."""
        tags = generate_tags("refs/heads/main", "abc1234def5678", [], "")
        assert "latest" in tags
        assert "main-abc1234" in tags

    def test_refs_heads_feature_stripped(self):
        """refs/heads/ prefix stripped for feature branches too."""
        tags = generate_tags("refs/heads/feature/foo", "abc1234def5678", [], "")
        assert "feature-foo-abc1234" in tags

    def test_all_tags_are_lowercase(self):
        """All generated tags must be lowercase."""
        tags = generate_tags("feat/My Feature/JIRA-123", "ABC1234DEF5678", [], "")
        for tag in tags:
            assert tag == tag.lower(), f"Tag '{tag}' is not lowercase"

    def test_all_tags_valid_docker_format(self):
        """All tags should only contain valid Docker tag characters."""
        import re
        tags = generate_tags("feat/My Feature/JIRA-123", "abc1234def5678", [], "")
        pattern = re.compile(r'^[a-z0-9][a-z0-9._-]*$')
        for tag in tags:
            assert pattern.match(tag), f"Tag '{tag}' is not valid Docker format"


# --- Parametrized fixture tests ---

@pytest.mark.parametrize("fixture", FIXTURES, ids=[f["id"] for f in FIXTURES])
def test_fixture_cases(fixture):
    """Parametrized test for all fixture cases."""
    tags = generate_tags(
        fixture["branch"],
        fixture["sha"],
        fixture["tags"],
        fixture["pr_number"],
    )
    for expected_tag in fixture["expected"]:
        assert expected_tag in tags, (
            f"Fixture '{fixture['id']}': expected tag '{expected_tag}' "
            f"not found in {tags}"
        )


# --- Workflow structure tests ---

WORKFLOW_PATH = ".github/workflows/docker-image-tag-generator.yml"


class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        """Workflow file must exist at the expected path."""
        assert os.path.exists(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_valid_yaml(self):
        """Workflow must be valid YAML."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        assert data is not None

    def test_workflow_has_on_triggers(self):
        """Workflow must have trigger events.

        Note: PyYAML parses the 'on:' key as True (Python bool) because
        'on' is a YAML 1.1 boolean. We check for both forms.
        """
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        # PyYAML parses 'on' as Python True; check both for compatibility
        assert ("on" in data or True in data), "Workflow missing 'on' triggers"

    def test_workflow_has_push_trigger(self):
        """Workflow must trigger on push."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        # PyYAML parses 'on' as Python True
        triggers = data.get("on", data.get(True, {})) or {}
        assert "push" in triggers, "Workflow missing 'push' trigger"

    def test_workflow_has_jobs(self):
        """Workflow must have at least one job."""
        with open(WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        assert "jobs" in data
        assert len(data["jobs"]) > 0

    def test_workflow_references_tag_generator(self):
        """Workflow must reference tag_generator.py."""
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        assert "tag_generator.py" in content, \
            "Workflow does not reference tag_generator.py"

    def test_tag_generator_script_exists(self):
        """The script referenced in workflow must exist."""
        assert os.path.exists("tag_generator.py"), "tag_generator.py not found"

    def test_actionlint_passes(self):
        """Workflow must pass actionlint validation."""
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )
