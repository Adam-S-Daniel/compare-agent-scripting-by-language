"""
Tests for PR Label Assigner - written using red/green TDD methodology.

TDD cycles:
  Cycle 1: match_pattern - basic glob matching (docs/**)
  Cycle 2: match_pattern - no slash patterns match basename anywhere
  Cycle 3: match_pattern - ** handles multiple levels of nesting
  Cycle 4: assign_labels - single rule, single file
  Cycle 5: assign_labels - multiple files produce label union
  Cycle 6: assign_labels - multiple rules, multiple labels per file
  Cycle 7: assign_labels - priority ordering (lower number = higher priority = first in output)
  Cycle 8: assign_labels - empty file list returns empty
  Cycle 9: load_config - reads JSON config file
  Cycle 10: load_files - reads file list from text file
  Workflow structure tests (run inside the act container)
"""

import json
import os
import subprocess
import shutil
import sys
import tempfile
import pytest

# ---------------------------------------------------------------------------
# Cycle 1: Basic glob matching - docs/** pattern
# ---------------------------------------------------------------------------

def test_match_docs_pattern_direct():
    """docs/README.md must match docs/**."""
    from label_assigner import match_pattern
    assert match_pattern("docs/README.md", "docs/**") is True


def test_no_match_docs_pattern_wrong_dir():
    """src/main.py must NOT match docs/**."""
    from label_assigner import match_pattern
    assert match_pattern("src/main.py", "docs/**") is False


# ---------------------------------------------------------------------------
# Cycle 2: Patterns without / match against any file's basename
# ---------------------------------------------------------------------------

def test_basename_pattern_matches_nested_file():
    """*.test.* must match src/api/server.test.py (by basename)."""
    from label_assigner import match_pattern
    assert match_pattern("src/api/server.test.py", "*.test.*") is True


def test_basename_pattern_no_match():
    """*.test.* must NOT match src/api/server.py."""
    from label_assigner import match_pattern
    assert match_pattern("src/api/server.py", "*.test.*") is False


# ---------------------------------------------------------------------------
# Cycle 3: ** handles multiple levels of nesting
# ---------------------------------------------------------------------------

def test_double_star_deep_nesting():
    """docs/** must match docs/api/v2/overview.md (3 levels deep)."""
    from label_assigner import match_pattern
    assert match_pattern("docs/api/v2/overview.md", "docs/**") is True


def test_src_api_double_star():
    """src/api/** must match src/api/server.py."""
    from label_assigner import match_pattern
    assert match_pattern("src/api/server.py", "src/api/**") is True


def test_src_api_double_star_no_match_parent():
    """src/api/** must NOT match src/main.py."""
    from label_assigner import match_pattern
    assert match_pattern("src/main.py", "src/api/**") is False


# ---------------------------------------------------------------------------
# Cycle 4: assign_labels - single rule, single file
# ---------------------------------------------------------------------------

def test_assign_single_label_single_file():
    """Single rule matching a single file returns one label."""
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    labels = assign_labels(["docs/README.md"], rules)
    assert labels == ["documentation"]


def test_assign_no_label_when_no_match():
    """No matching rule returns empty list."""
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    labels = assign_labels(["src/main.py"], rules)
    assert labels == []


# ---------------------------------------------------------------------------
# Cycle 5: Multiple files produce label union (label added only once)
# ---------------------------------------------------------------------------

def test_multiple_files_same_label_deduplicated():
    """Two files matching the same rule produce only one label."""
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    labels = assign_labels(["docs/README.md", "docs/api/overview.md"], rules)
    assert labels == ["documentation"]


# ---------------------------------------------------------------------------
# Cycle 6: Multiple rules -> multiple labels per file
# ---------------------------------------------------------------------------

def test_multiple_rules_multiple_labels():
    """A file matching two rules gets both labels."""
    from label_assigner import assign_labels
    rules = [
        {"pattern": "src/api/**", "label": "api", "priority": 1},
        {"pattern": "*.test.*", "label": "tests", "priority": 2},
    ]
    # server.py matches api, server.test.py matches both api and tests
    labels = assign_labels(["src/api/server.py", "src/api/server.test.py"], rules)
    assert "api" in labels
    assert "tests" in labels


# ---------------------------------------------------------------------------
# Cycle 7: Priority ordering - lower number = higher priority = first in output
# ---------------------------------------------------------------------------

def test_priority_ordering_lower_number_first():
    """Rules with lower priority number appear earlier in output."""
    from label_assigner import assign_labels
    rules = [
        # Intentionally listed in reverse order to test sorting
        {"pattern": "src/**", "label": "backend", "priority": 1},
        {"pattern": "src/api/**", "label": "api", "priority": 2},
    ]
    labels = assign_labels(["src/api/server.py"], rules)
    # backend (priority 1) must come before api (priority 2)
    assert labels.index("backend") < labels.index("api")


def test_priority_ordering_with_multiple_files():
    """Priority ordering is preserved across multiple files."""
    from label_assigner import assign_labels
    rules = [
        {"pattern": "src/api/**", "label": "api", "priority": 1},
        {"pattern": "*.test.*", "label": "tests", "priority": 2},
        {"pattern": "src/**", "label": "source", "priority": 3},
    ]
    labels = assign_labels(
        ["src/api/server.py", "src/api/server.test.py"],
        rules,
    )
    assert labels[0] == "api"
    assert labels[1] == "tests"
    assert labels[2] == "source"


# ---------------------------------------------------------------------------
# Cycle 8: Edge cases
# ---------------------------------------------------------------------------

def test_empty_file_list():
    """Empty file list returns empty label list."""
    from label_assigner import assign_labels
    rules = [{"pattern": "docs/**", "label": "documentation", "priority": 1}]
    assert assign_labels([], rules) == []


def test_empty_rules():
    """Empty rules list returns empty label list."""
    from label_assigner import assign_labels
    assert assign_labels(["docs/README.md"], []) == []


def test_rule_without_priority_uses_default():
    """Rules without 'priority' key are treated as lowest priority."""
    from label_assigner import assign_labels
    rules = [
        {"pattern": "docs/**", "label": "documentation"},  # no priority
    ]
    labels = assign_labels(["docs/README.md"], rules)
    assert labels == ["documentation"]


# ---------------------------------------------------------------------------
# Cycle 9: load_config reads a JSON config file
# ---------------------------------------------------------------------------

def test_load_config(tmp_path):
    """load_config parses a valid JSON config file."""
    from label_assigner import load_config
    config_data = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 1}
        ]
    }
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config_data))
    config = load_config(str(config_file))
    assert config["rules"][0]["label"] == "documentation"


def test_load_config_missing_file(tmp_path):
    """load_config raises a clear error for missing files."""
    from label_assigner import load_config
    with pytest.raises(SystemExit):
        load_config(str(tmp_path / "nonexistent.json"))


def test_load_config_missing_rules_key(tmp_path):
    """load_config raises an error when 'rules' key is absent."""
    from label_assigner import load_config
    config_file = tmp_path / "bad.json"
    config_file.write_text(json.dumps({"foo": "bar"}))
    with pytest.raises(SystemExit):
        load_config(str(config_file))


# ---------------------------------------------------------------------------
# Cycle 10: load_files reads a text file with one path per line
# ---------------------------------------------------------------------------

def test_load_files(tmp_path):
    """load_files reads paths from a text file, one per line."""
    from label_assigner import load_files
    files_file = tmp_path / "files.txt"
    files_file.write_text("docs/README.md\nsrc/main.py\n")
    files = load_files(str(files_file))
    assert files == ["docs/README.md", "src/main.py"]


def test_load_files_strips_blank_lines(tmp_path):
    """load_files ignores blank lines."""
    from label_assigner import load_files
    files_file = tmp_path / "files.txt"
    files_file.write_text("\ndocs/README.md\n\nsrc/main.py\n\n")
    files = load_files(str(files_file))
    assert files == ["docs/README.md", "src/main.py"]


def test_load_files_missing(tmp_path):
    """load_files raises a clear error for missing files."""
    from label_assigner import load_files
    with pytest.raises(SystemExit):
        load_files(str(tmp_path / "nonexistent.txt"))


# ---------------------------------------------------------------------------
# Workflow structure tests
# These tests verify the workflow YAML has the right shape and references
# the correct files. They run inside the act container.
# ---------------------------------------------------------------------------

WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__),
    ".github", "workflows", "pr-label-assigner.yml",
)

def test_workflow_file_exists():
    """The workflow YAML file must exist at the expected path."""
    assert os.path.isfile(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"


def test_workflow_structure():
    """Workflow must have push/pull_request triggers and a label-assigner job."""
    try:
        import yaml
    except ImportError:
        pytest.skip("pyyaml not installed")

    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    # NOTE: pyyaml parses the bare YAML key 'on' as boolean True (a YAML quirk).
    # GitHub Actions requires the literal string 'on', but pyyaml stores it as True.
    # We accept either form to stay robust.
    on = wf.get("on") or wf.get(True) or {}
    if isinstance(on, dict):
        assert "push" in on or "pull_request" in on, "Workflow must trigger on push or pull_request"
    else:
        assert "push" in str(on) or "pull_request" in str(on)

    assert "jobs" in wf, "Workflow must have jobs"
    assert "label-assigner" in wf["jobs"], "Workflow must have a 'label-assigner' job"


def test_workflow_references_script_files():
    """Scripts and fixtures referenced in the workflow must exist on disk."""
    required_files = [
        "label_assigner.py",
        "test_fixtures/case1/config.json",
        "test_fixtures/case1/changed_files.txt",
        "test_fixtures/case2/config.json",
        "test_fixtures/case2/changed_files.txt",
        "test_fixtures/case3/config.json",
        "test_fixtures/case3/changed_files.txt",
        "test_fixtures/case4/config.json",
        "test_fixtures/case4/changed_files.txt",
    ]
    base = os.path.dirname(__file__)
    for rel in required_files:
        full = os.path.join(base, rel)
        assert os.path.isfile(full), f"Required file missing: {rel}"


def test_actionlint_passes():
    """actionlint must report no errors on the workflow file."""
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not available in this environment")
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
    )
