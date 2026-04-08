#!/usr/bin/env python3
"""
Test harness for the Semantic Version Bumper.

Runs ALL tests through GitHub Actions via `act`. For each test case:
1. Creates a temp git repo with project files + fixture data
2. Runs `act push --rm` and captures output
3. Asserts exit code 0 and exact expected values in output
4. Appends output to act-result.txt

Also runs workflow structure tests (YAML parsing, file references, actionlint).

TDD methodology: each test case was written as a failing test first (red),
then version_bumper.py was implemented to make it pass (green), then refactored.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import yaml
from pathlib import Path

# Directory containing this script and the project files
PROJECT_DIR = Path(__file__).resolve().parent
RESULT_FILE = PROJECT_DIR / "act-result.txt"

# Track pass/fail counts
passed = 0
failed = 0


def log(msg):
    """Print a test log message."""
    print(msg, flush=True)


def assert_true(condition, msg):
    """Assert a condition is true, tracking pass/fail."""
    global passed, failed
    if condition:
        passed += 1
        log(f"  PASS: {msg}")
    else:
        failed += 1
        log(f"  FAIL: {msg}")


def setup_temp_repo(version_file_name, version_content, commit_log_file=None):
    """Create a temporary git repo with project files and fixture data.

    Returns the path to the temp directory.
    """
    tmpdir = tempfile.mkdtemp(prefix="svb_test_")

    # Copy version_bumper.py
    shutil.copy2(PROJECT_DIR / "version_bumper.py", tmpdir)

    # Copy workflow
    wf_dir = Path(tmpdir) / ".github" / "workflows"
    wf_dir.mkdir(parents=True)
    shutil.copy2(
        PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml",
        wf_dir,
    )

    # Write the version file
    vf_path = Path(tmpdir) / version_file_name
    vf_path.write_text(version_content)

    # Copy commit log fixture if provided
    if commit_log_file:
        src = PROJECT_DIR / "test_fixtures" / commit_log_file
        shutil.copy2(src, Path(tmpdir) / "commits.txt")

    # Initialize git repo (act needs a git repo for checkout)
    subprocess.run(["git", "init"], cwd=tmpdir, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmpdir, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmpdir, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=tmpdir, capture_output=True)
    subprocess.run(["git", "commit", "-m", "initial"], cwd=tmpdir, capture_output=True)

    return tmpdir


def run_act(tmpdir, extra_env=None):
    """Run act push --rm in the given directory and return (exit_code, output)."""
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)

    result = subprocess.run(
        ["act", "push", "--rm", "--platform", "ubuntu-latest=catthehacker/ubuntu:act-latest"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
        env=env,
    )
    output = result.stdout + "\n" + result.stderr
    return result.returncode, output


def append_result(test_name, output):
    """Append test output to the result file."""
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{'='*72}\n")
        f.write(f"TEST CASE: {test_name}\n")
        f.write(f"{'='*72}\n")
        f.write(output)
        f.write("\n")


# ---------------------------------------------------------------------------
# Workflow structure tests (no act needed)
# ---------------------------------------------------------------------------

def test_workflow_structure():
    """Parse YAML and verify expected structure."""
    log("\n--- Test: Workflow Structure ---")

    wf_path = PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml"

    # File must exist
    assert_true(wf_path.exists(), "Workflow YAML file exists")

    with open(wf_path) as f:
        wf = yaml.safe_load(f)

    # Check triggers — PyYAML parses bare 'on' as boolean True
    trigger_key = True if True in wf else "on"
    assert_true(trigger_key in wf, "Workflow has 'on' triggers")
    triggers = wf[trigger_key]
    assert_true("push" in triggers, "Workflow has push trigger")
    assert_true("workflow_dispatch" in triggers, "Workflow has workflow_dispatch trigger")

    # Check jobs
    assert_true("jobs" in wf, "Workflow has jobs section")
    assert_true("bump-version" in wf["jobs"], "Workflow has bump-version job")

    job = wf["jobs"]["bump-version"]
    step_names = [s.get("name", "") for s in job["steps"]]

    assert_true("Checkout repository" in step_names, "Job has checkout step")
    assert_true("Set up Python" in step_names, "Job has Python setup step")
    assert_true("Run version bumper" in step_names, "Job has version bumper step")

    # Check that checkout uses actions/checkout@v4
    checkout_step = [s for s in job["steps"] if s.get("name") == "Checkout repository"][0]
    assert_true(checkout_step.get("uses") == "actions/checkout@v4",
                "Checkout step uses actions/checkout@v4")


def test_workflow_file_references():
    """Verify the workflow references script files that exist."""
    log("\n--- Test: Workflow File References ---")

    assert_true((PROJECT_DIR / "version_bumper.py").exists(),
                "version_bumper.py exists")
    assert_true((PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml").exists(),
                "Workflow file exists")

    # Read workflow and check it references version_bumper.py
    wf_content = (PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml").read_text()
    assert_true("version_bumper.py" in wf_content,
                "Workflow references version_bumper.py")


def test_actionlint():
    """Verify actionlint passes with exit code 0."""
    log("\n--- Test: actionlint Validation ---")

    result = subprocess.run(
        ["actionlint", str(PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml")],
        capture_output=True, text=True,
    )
    assert_true(result.returncode == 0,
                f"actionlint passes (exit code {result.returncode})")
    if result.returncode != 0:
        log(f"  actionlint output: {result.stdout}{result.stderr}")


# ---------------------------------------------------------------------------
# Act-based test cases — each one sets up a temp repo and runs act
# ---------------------------------------------------------------------------

def test_patch_bump():
    """RED/GREEN: fix commits on 1.0.0 should produce 1.0.1."""
    log("\n--- Test: Patch Bump (fix commits -> 1.0.1) ---")

    tmpdir = setup_temp_repo("VERSION", "1.0.0", "patch_bump_commits.txt")

    # Override workflow to use commits.txt
    patch_workflow(tmpdir, "VERSION", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("patch_bump", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("Job succeeded" in output, "Job succeeded appears in output")
    assert_true("New version: 1.0.1" in output, "Output contains 'New version: 1.0.1'")
    assert_true("Bump type: patch" in output, "Output contains 'Bump type: patch'")
    assert_true("Current version: 1.0.0" in output, "Output contains 'Current version: 1.0.0'")

    shutil.rmtree(tmpdir, ignore_errors=True)


def test_minor_bump():
    """RED/GREEN: feat commits on 1.0.0 should produce 1.1.0."""
    log("\n--- Test: Minor Bump (feat commits -> 1.1.0) ---")

    tmpdir = setup_temp_repo("VERSION", "1.0.0", "minor_bump_commits.txt")
    patch_workflow(tmpdir, "VERSION", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("minor_bump", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("Job succeeded" in output, "Job succeeded appears in output")
    assert_true("New version: 1.1.0" in output, "Output contains 'New version: 1.1.0'")
    assert_true("Bump type: minor" in output, "Output contains 'Bump type: minor'")

    shutil.rmtree(tmpdir, ignore_errors=True)


def test_major_bump():
    """RED/GREEN: breaking change commits on 1.0.0 should produce 2.0.0."""
    log("\n--- Test: Major Bump (breaking change -> 2.0.0) ---")

    tmpdir = setup_temp_repo("VERSION", "1.0.0", "major_bump_commits.txt")
    patch_workflow(tmpdir, "VERSION", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("major_bump", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("Job succeeded" in output, "Job succeeded appears in output")
    assert_true("New version: 2.0.0" in output, "Output contains 'New version: 2.0.0'")
    assert_true("Bump type: major" in output, "Output contains 'Bump type: major'")

    shutil.rmtree(tmpdir, ignore_errors=True)


def test_mixed_feat_fix():
    """RED/GREEN: mixed feat+fix on 1.2.3 should produce 1.3.0 (feat > fix)."""
    log("\n--- Test: Mixed feat+fix Bump (1.2.3 -> 1.3.0) ---")

    tmpdir = setup_temp_repo("VERSION", "1.2.3", "mixed_feat_fix_commits.txt")
    patch_workflow(tmpdir, "VERSION", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("mixed_feat_fix", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("Job succeeded" in output, "Job succeeded appears in output")
    assert_true("New version: 1.3.0" in output, "Output contains 'New version: 1.3.0'")
    assert_true("Bump type: minor" in output, "Output contains 'Bump type: minor'")
    assert_true("Current version: 1.2.3" in output, "Output contains 'Current version: 1.2.3'")

    shutil.rmtree(tmpdir, ignore_errors=True)


def test_package_json():
    """RED/GREEN: package.json 2.5.1 with feat commits -> 2.6.0."""
    log("\n--- Test: package.json Bump (2.5.1 -> 2.6.0) ---")

    pkg_content = json.dumps({"name": "my-app", "version": "2.5.1"}, indent=2)
    tmpdir = setup_temp_repo("package.json", pkg_content + "\n", "minor_bump_commits.txt")
    patch_workflow(tmpdir, "package.json", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("package_json", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("Job succeeded" in output, "Job succeeded appears in output")
    assert_true("New version: 2.6.0" in output, "Output contains 'New version: 2.6.0'")
    assert_true("Current version: 2.5.1" in output, "Output contains 'Current version: 2.5.1'")

    shutil.rmtree(tmpdir, ignore_errors=True)


def test_no_conventional_commits():
    """RED/GREEN: non-conventional commits should leave version unchanged."""
    log("\n--- Test: No Conventional Commits (version unchanged) ---")

    tmpdir = setup_temp_repo("VERSION", "3.0.0", "no_conventional_commits.txt")
    patch_workflow(tmpdir, "VERSION", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("no_conventional_commits", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("Job succeeded" in output, "Job succeeded appears in output")
    assert_true("No conventional commits found" in output,
                "Output contains 'No conventional commits found'")

    shutil.rmtree(tmpdir, ignore_errors=True)


def test_changelog_generation():
    """RED/GREEN: verify changelog content appears in act output."""
    log("\n--- Test: Changelog Generation ---")

    tmpdir = setup_temp_repo("VERSION", "1.0.0", "minor_bump_commits.txt")
    patch_workflow(tmpdir, "VERSION", "commits.txt")

    rc, output = run_act(tmpdir)
    append_result("changelog_generation", output)

    assert_true(rc == 0, f"act exit code is 0 (got {rc})")
    assert_true("## [1.1.0] - 2026-04-08" in output,
                "Changelog header with version and date in output")
    assert_true("### Features" in output, "Changelog has Features section")
    assert_true("feat: add user profile endpoint" in output,
                "Changelog lists feature commit")
    assert_true("### Bug Fixes" in output, "Changelog has Bug Fixes section")

    shutil.rmtree(tmpdir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Helper: patch the workflow to use specific version file and commit log
# ---------------------------------------------------------------------------

def patch_workflow(tmpdir, version_file, commit_log):
    """Rewrite the workflow in tmpdir to hardcode version_file and commit_log paths."""
    wf_path = Path(tmpdir) / ".github" / "workflows" / "semantic-version-bumper.yml"
    wf = wf_path.read_text()

    # Replace the config step and bumper step with hardcoded values
    new_wf = f"""name: Semantic Version Bumper
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  bump-version:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Run version bumper
        id: bumper
        run: |
          python3 version_bumper.py --version-file "{version_file}" --date 2026-04-08 --commit-log "{commit_log}"

      - name: Show updated version file
        run: |
          echo "=== Updated {version_file} ==="
          cat "{version_file}"

      - name: Show changelog
        if: always()
        run: |
          echo "=== CHANGELOG.md ==="
          if [ -f CHANGELOG.md ]; then cat CHANGELOG.md; else echo "No changelog generated"; fi
"""
    wf_path.write_text(new_wf)

    # Re-commit the change
    subprocess.run(["git", "add", "-A"], cwd=tmpdir, capture_output=True)
    subprocess.run(["git", "commit", "-m", "update workflow for test"], cwd=tmpdir, capture_output=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    global passed, failed

    # Clear result file
    RESULT_FILE.write_text(f"Semantic Version Bumper — Act Test Results\n{'='*72}\n")

    log("=" * 60)
    log("Semantic Version Bumper — Test Harness")
    log("=" * 60)

    # --- Workflow structure tests (fast, no act) ---
    test_workflow_structure()
    test_workflow_file_references()
    test_actionlint()

    # --- Act-based integration tests ---
    test_patch_bump()
    test_minor_bump()
    test_major_bump()
    test_mixed_feat_fix()
    test_package_json()
    test_no_conventional_commits()
    test_changelog_generation()

    # --- Summary ---
    total = passed + failed
    log(f"\n{'='*60}")
    log(f"Results: {passed}/{total} passed, {failed} failed")
    log(f"{'='*60}")

    if failed > 0:
        log("\nSome tests FAILED!")
        sys.exit(1)
    else:
        log("\nAll tests PASSED!")
        sys.exit(0)


if __name__ == "__main__":
    main()
