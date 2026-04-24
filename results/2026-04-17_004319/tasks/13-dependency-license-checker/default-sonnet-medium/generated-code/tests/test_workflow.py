"""
Workflow Structure and Act Integration Tests

This module:
  1. Validates the workflow YAML structure (triggers, jobs, steps)
  2. Verifies that referenced files exist on disk
  3. Runs actionlint to confirm the YAML passes static analysis
  4. Runs the full workflow via act for each test case:
       - approved_only:   all MIT → 2 approved, 0 denied, 0 unknown, PASSED
       - mixed_licenses:  MIT + GPL-3.0 + unknown → 1/1/1, FAILED
     Both cases assert exact expected values from the act output.

Output from every act run is appended to act-result.txt.
"""
import json
import shutil
import subprocess
import tempfile
import pytest
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.parent
WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "dependency-license-checker.yml"
ACT_RESULT_FILE = PROJECT_DIR / "act-result.txt"

# ============================================================
# 1. Workflow structure tests
# ============================================================

def test_workflow_file_exists():
    """Workflow YAML exists at the expected path."""
    assert WORKFLOW_PATH.exists(), f"Workflow not found: {WORKFLOW_PATH}"


def test_workflow_has_required_triggers():
    """Workflow declares push and pull_request triggers.

    PyYAML parses the bare 'on:' key as Python True (YAML boolean),
    so we look up both 'on' and True to be safe.
    """
    import yaml
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    # yaml.safe_load maps the 'on:' key to Python True
    triggers = wf.get("on", wf.get(True, {})) or {}
    assert "push" in triggers, f"Missing 'push' trigger; got: {triggers}"
    assert "pull_request" in triggers, f"Missing 'pull_request' trigger; got: {triggers}"


def test_workflow_has_license_check_job():
    """Workflow defines at least one job."""
    import yaml
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    assert "jobs" in wf and wf["jobs"], "No jobs found in workflow"


def test_workflow_job_runs_on_ubuntu():
    """The license-check job targets ubuntu-latest."""
    import yaml
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    jobs = wf.get("jobs", {})
    job = next(iter(jobs.values()))
    assert "ubuntu" in job.get("runs-on", ""), "Job should run on ubuntu-latest"


def test_workflow_includes_checkout_step():
    """Workflow has an actions/checkout step."""
    import yaml
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    jobs = wf.get("jobs", {})
    job = next(iter(jobs.values()))
    uses_values = [
        s.get("uses", "") for s in job.get("steps", []) if isinstance(s, dict)
    ]
    assert any("actions/checkout" in u for u in uses_values), (
        f"No actions/checkout step found; uses: {uses_values}"
    )


def test_workflow_references_license_checker_script():
    """Workflow YAML mentions license_checker.py."""
    content = WORKFLOW_PATH.read_text()
    assert "license_checker.py" in content, "Workflow does not reference license_checker.py"


def test_workflow_referenced_script_exists():
    """license_checker.py referenced in the workflow actually exists."""
    assert (PROJECT_DIR / "license_checker.py").exists(), "license_checker.py not found"


def test_workflow_referenced_fixtures_exist():
    """Fixture files mentioned in the workflow exist on disk."""
    for fixture in [
        "fixtures/package.json",
        "fixtures/license_config.json",
        "fixtures/mock_licenses.json",
    ]:
        assert (PROJECT_DIR / fixture).exists(), f"Fixture not found: {fixture}"


def test_workflow_has_permissions_block():
    """Workflow declares a permissions block (security best practice)."""
    import yaml
    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)
    assert "permissions" in wf, "Workflow should declare a permissions block"


# ============================================================
# 2. actionlint validation
# ============================================================

def test_actionlint_passes():
    """Workflow passes actionlint with exit code 0."""
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )


# ============================================================
# 3. Act integration test cases
# Each case sets up a temporary git repo, swaps in specific fixtures,
# runs `act push --rm`, and asserts on exact expected strings.
# All output is appended to act-result.txt.
# ============================================================

# Fixture content for each test case
# act "approved_only": react + lodash, both MIT → 2 approved, 0 denied, 0 unknown, PASSED
# act "mixed_licenses": react (MIT) + gpl-lib (GPL-3.0) + mystery-pkg (not in DB)
#                       → 1 approved, 1 denied, 1 unknown, FAILED

ACT_TEST_CASES = {
    "approved_only": {
        "package.json": json.dumps(
            {
                "name": "approved-project",
                "version": "1.0.0",
                "dependencies": {
                    "react": "18.2.0",
                    "lodash": "4.17.21",
                },
            },
            indent=2,
        ),
        "license_config.json": json.dumps(
            {"allow": ["MIT"], "deny": ["GPL-3.0", "AGPL-3.0"]}, indent=2
        ),
        "mock_licenses.json": json.dumps(
            {"react": "MIT", "lodash": "MIT"}, indent=2
        ),
        "expected": [
            "2 approved",
            "0 denied",
            "0 unknown",
            "COMPLIANCE CHECK PASSED",
        ],
    },
    "mixed_licenses": {
        "package.json": json.dumps(
            {
                "name": "mixed-project",
                "version": "1.0.0",
                "dependencies": {
                    "react": "18.2.0",
                    "gpl-lib": "1.0.0",
                    "mystery-pkg": "2.0.0",
                },
            },
            indent=2,
        ),
        "license_config.json": json.dumps(
            {"allow": ["MIT"], "deny": ["GPL-3.0"]}, indent=2
        ),
        "mock_licenses.json": json.dumps(
            {
                "react": "MIT",
                "gpl-lib": "GPL-3.0",
                # mystery-pkg intentionally absent → unknown
            },
            indent=2,
        ),
        "expected": [
            "1 approved",
            "1 denied",
            "1 unknown",
            "COMPLIANCE CHECK FAILED",
        ],
    },
}


def _setup_act_repo(tmp_path: Path, fixtures: dict) -> None:
    """Populate tmp_path as a git repo with project files and test fixtures."""
    # Copy the main script
    shutil.copy2(PROJECT_DIR / "license_checker.py", tmp_path / "license_checker.py")

    # Copy .github/workflows
    wf_dst = tmp_path / ".github" / "workflows"
    wf_dst.mkdir(parents=True)
    shutil.copy2(WORKFLOW_PATH, wf_dst / "dependency-license-checker.yml")

    # Copy tests directory (workflow runs pytest tests/test_unit.py)
    tests_dst = tmp_path / "tests"
    tests_dst.mkdir()
    shutil.copy2(
        PROJECT_DIR / "tests" / "test_unit.py",
        tests_dst / "test_unit.py",
    )

    # Write the test-case-specific fixtures
    fixtures_dst = tmp_path / "fixtures"
    fixtures_dst.mkdir()
    for filename, content in fixtures.items():
        if filename != "expected":
            (fixtures_dst / filename).write_text(content)

    # Copy .actrc so act uses the custom image
    actrc = PROJECT_DIR / ".actrc"
    if actrc.exists():
        shutil.copy2(actrc, tmp_path / ".actrc")

    # Initialize git and commit everything
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "ci@example.com"],
        ["git", "config", "user.name", "CI"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "ci: add license checker"],
    ]:
        subprocess.run(cmd, cwd=tmp_path, check=True, capture_output=True)


def _append_act_result(case_name: str, result: subprocess.CompletedProcess) -> None:
    """Append act output to act-result.txt, clearly delimited."""
    output = result.stdout + result.stderr
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'='*70}\n")
        f.write(f"TEST CASE: {case_name}\n")
        f.write(f"EXIT CODE: {result.returncode}\n")
        f.write(f"{'='*70}\n")
        f.write(output)
        f.write("\n")


@pytest.mark.parametrize("case_name", list(ACT_TEST_CASES.keys()))
def test_act_case(case_name, tmp_path):
    """Run one test case through the GitHub Actions workflow via act."""
    case = ACT_TEST_CASES[case_name]

    # Initialise act-result.txt once (first test)
    if not ACT_RESULT_FILE.exists():
        ACT_RESULT_FILE.write_text(
            "act-result.txt — Dependency License Checker\n"
        )

    _setup_act_repo(tmp_path, case)

    act_result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        timeout=300,
    )

    _append_act_result(case_name, act_result)

    output = act_result.stdout + act_result.stderr

    # Assert act exited successfully
    assert act_result.returncode == 0, (
        f"act failed for '{case_name}' (exit {act_result.returncode}):\n"
        f"{output[-3000:]}"
    )

    # Assert every expected string appears in the output (exact values)
    for expected in case["expected"]:
        assert expected in output, (
            f"Expected exact string '{expected}' not found in act output "
            f"for test case '{case_name}'.\nOutput tail:\n{output[-2000:]}"
        )

    # Assert the job reported success
    assert "Job succeeded" in output, (
        f"'Job succeeded' not found for '{case_name}'.\n"
        f"Output tail:\n{output[-2000:]}"
    )
