#!/usr/bin/env python3
"""Test harness for Semantic Version Bumper.

All tests execute through the GitHub Actions workflow via `act`.
This harness:
  1. Runs workflow structure tests (YAML parsing, actionlint, file refs)
  2. For each test case: sets up a temp git repo with fixture data,
     runs `act push --rm`, captures output, asserts on exact expected values
  3. Saves all act output to act-result.txt
  4. Asserts every job shows "Job succeeded"

TDD: Test expectations (assertions) are defined first — these are the "RED"
tests that drove the implementation of version_bumper.py.
"""

import os
import shutil
import subprocess
import sys
import tempfile

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(
    SCRIPT_DIR, ".github", "workflows", "semantic-version-bumper.yml"
)
BUMPER_SCRIPT = os.path.join(SCRIPT_DIR, "version_bumper.py")
ACTRC_PATH = os.path.join(SCRIPT_DIR, ".actrc")
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# ============================================================================
# TEST FIXTURES — defined before implementation (TDD red phase)
#
# Each case: name, starting version, list of (commit_msg, dummy_filename),
#            expected new version, expected bump type
# ============================================================================
TEST_CASES = [
    {
        "name": "patch_bump",
        "initial_version": "1.0.0",
        "commits": [
            ("fix: correct off-by-one error in parser", "parser.py"),
            ("fix: handle null input gracefully", "validator.py"),
        ],
        "expected_version": "1.0.1",
        "expected_bump": "patch",
    },
    {
        "name": "minor_bump",
        "initial_version": "1.1.0",
        "commits": [
            ("feat: add CSV export functionality", "exporter.py"),
            ("fix: typo in help text", "help.txt"),
        ],
        "expected_version": "1.2.0",
        "expected_bump": "minor",
    },
    {
        "name": "major_bump",
        "initial_version": "0.5.3",
        "commits": [
            ("feat!: redesign public API", "api.py"),
            ("feat: add new helper method", "helpers.py"),
        ],
        "expected_version": "1.0.0",
        "expected_bump": "major",
    },
]


# ============================================================================
# Helpers
# ============================================================================

def run_cmd(cmd, cwd=None, check=False):
    """Run a shell command and return its CompletedProcess."""
    return subprocess.run(
        cmd, shell=True, capture_output=True, text=True, cwd=cwd, check=check,
    )


def log(msg):
    """Print a status message."""
    print(msg, flush=True)


# ============================================================================
# PHASE 1 — Workflow structure tests (no act needed)
# ============================================================================

def test_workflow_structure():
    """Validate workflow YAML structure, triggers, steps, and file refs."""
    log("=" * 60)
    log("PHASE 1: WORKFLOW STRUCTURE TESTS")
    log("=" * 60)

    errors = []

    # --- Test: workflow file exists ---
    if not os.path.exists(WORKFLOW_PATH):
        errors.append("Workflow file does not exist at expected path")
        return errors

    # --- Test: valid YAML ---
    with open(WORKFLOW_PATH) as f:
        try:
            workflow = yaml.safe_load(f)
        except yaml.YAMLError as exc:
            errors.append(f"Invalid YAML: {exc}")
            return errors

    log("  [PASS] Workflow is valid YAML")

    # --- Test: has push trigger ---
    triggers = workflow.get("on") or workflow.get(True, {})
    trigger_keys = set()
    if isinstance(triggers, dict):
        trigger_keys = set(triggers.keys())
    elif isinstance(triggers, list):
        trigger_keys = set(triggers)
    elif isinstance(triggers, str):
        trigger_keys = {triggers}

    if "push" not in trigger_keys:
        errors.append("Missing 'push' trigger")
    else:
        log("  [PASS] Has 'push' trigger")

    # --- Test: has jobs ---
    jobs = workflow.get("jobs", {})
    if not jobs:
        errors.append("No jobs defined in workflow")
        return errors

    log(f"  [PASS] Has {len(jobs)} job(s)")

    # --- Test: first job has checkout + script steps ---
    first_job = list(jobs.values())[0]
    steps = first_job.get("steps", [])

    has_checkout = any(
        s.get("uses", "").startswith("actions/checkout") for s in steps
    )
    if not has_checkout:
        errors.append("No actions/checkout step found")
    else:
        log("  [PASS] Has actions/checkout step")

    has_script_ref = any("version_bumper.py" in s.get("run", "") for s in steps)
    if not has_script_ref:
        errors.append("No reference to version_bumper.py in run steps")
    else:
        log("  [PASS] Workflow references version_bumper.py")

    # --- Test: fetch-depth 0 for full history ---
    checkout_step = next(
        (s for s in steps if s.get("uses", "").startswith("actions/checkout")),
        None,
    )
    if checkout_step:
        fd = checkout_step.get("with", {}).get("fetch-depth", 1)
        if fd != 0:
            errors.append(f"Checkout fetch-depth is {fd}, expected 0 for full history")
        else:
            log("  [PASS] Checkout uses fetch-depth: 0")

    # --- Test: script file exists ---
    if not os.path.exists(BUMPER_SCRIPT):
        errors.append(f"Script file not found: {BUMPER_SCRIPT}")
    else:
        log("  [PASS] version_bumper.py exists")

    # --- Test: actionlint passes ---
    result = run_cmd(f"actionlint {WORKFLOW_PATH}")
    if result.returncode != 0:
        errors.append(f"actionlint failed:\n{result.stdout.strip()}\n{result.stderr.strip()}")
    else:
        log("  [PASS] actionlint passes")

    return errors


# ============================================================================
# PHASE 2 — Act integration tests
# ============================================================================

def setup_test_repo(test_case, tmp_dir):
    """Create a temp git repo with the version bumper, workflow, and fixtures."""
    # Init repo
    run_cmd("git init -b main", cwd=tmp_dir, check=True)
    run_cmd("git config user.email 'test@test.com'", cwd=tmp_dir, check=True)
    run_cmd("git config user.name 'Test'", cwd=tmp_dir, check=True)

    # Copy script and workflow
    shutil.copy(BUMPER_SCRIPT, os.path.join(tmp_dir, "version_bumper.py"))
    wf_dir = os.path.join(tmp_dir, ".github", "workflows")
    os.makedirs(wf_dir)
    shutil.copy(WORKFLOW_PATH, os.path.join(wf_dir, "semantic-version-bumper.yml"))

    # Copy .actrc
    if os.path.exists(ACTRC_PATH):
        shutil.copy(ACTRC_PATH, os.path.join(tmp_dir, ".actrc"))

    # Create VERSION file
    with open(os.path.join(tmp_dir, "VERSION"), "w") as f:
        f.write(test_case["initial_version"] + "\n")

    # Initial commit (non-conventional so it doesn't affect bump type detection)
    run_cmd("git add -A", cwd=tmp_dir, check=True)
    run_cmd('git commit -m "chore: initial project setup"', cwd=tmp_dir, check=True)

    # Create conventional commits from fixture data
    for msg, filename in test_case["commits"]:
        filepath = os.path.join(tmp_dir, filename)
        with open(filepath, "w") as f:
            f.write(f"# placeholder for: {msg}\n")
        run_cmd("git add -A", cwd=tmp_dir, check=True)
        run_cmd(f'git commit -m "{msg}"', cwd=tmp_dir, check=True)


def run_act_test(test_case, result_fh):
    """Run one test case through act, return (output_text, exit_code)."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        log(f"  Setting up repo in {tmp_dir}")
        setup_test_repo(test_case, tmp_dir)

        log("  Running act push --rm ...")
        result = run_cmd("act push --rm 2>&1", cwd=tmp_dir)
        output = result.stdout + "\n" + result.stderr

        # Write delimited section to result file
        result_fh.write(f"\n{'=' * 60}\n")
        result_fh.write(f"TEST CASE: {test_case['name']}\n")
        result_fh.write(f"Initial: {test_case['initial_version']}  ")
        result_fh.write(f"Expected: {test_case['expected_version']}  ")
        result_fh.write(f"Bump: {test_case['expected_bump']}\n")
        result_fh.write(f"Act exit code: {result.returncode}\n")
        result_fh.write(f"{'=' * 60}\n")
        result_fh.write(output)
        result_fh.write(f"\n{'=' * 60}\n\n")
        result_fh.flush()

        return output, result.returncode


def assert_test_case(test_case, output, exit_code):
    """Assert expected values in act output. Returns list of failure messages."""
    errors = []
    name = test_case["name"]
    exp_ver = test_case["expected_version"]
    exp_bump = test_case["expected_bump"]
    init_ver = test_case["initial_version"]

    # Act must succeed
    if exit_code != 0:
        errors.append(f"[{name}] act exited with code {exit_code}")

    # Job must report success
    if "Job succeeded" not in output:
        errors.append(f"[{name}] 'Job succeeded' not found in output")

    # Exact version output markers
    if f"CURRENT_VERSION={init_ver}" not in output:
        errors.append(f"[{name}] Expected CURRENT_VERSION={init_ver} in output")

    if f"NEW_VERSION={exp_ver}" not in output:
        errors.append(f"[{name}] Expected NEW_VERSION={exp_ver} in output")

    if f"BUMP_TYPE={exp_bump}" not in output:
        errors.append(f"[{name}] Expected BUMP_TYPE={exp_bump} in output")

    # Transition summary
    transition = f"{init_ver} -> {exp_ver} ({exp_bump})"
    if transition not in output:
        errors.append(f"[{name}] Expected transition '{transition}' in output")

    # Changelog was generated
    if "CHANGELOG_ENTRY_START" not in output:
        errors.append(f"[{name}] Changelog entry was not generated")

    # Updated VERSION file shown in output
    if f"=== Updated VERSION ===" not in output:
        errors.append(f"[{name}] 'Show updated version' step output missing")

    return errors


# ============================================================================
# Main
# ============================================================================

def main():
    log("Semantic Version Bumper — Test Harness")
    log("=" * 60)

    all_errors = []

    # Phase 1: workflow structure tests
    struct_errors = test_workflow_structure()
    all_errors.extend(struct_errors)

    if struct_errors:
        log("\nPhase 1 FAILED — fix structure issues before running act:")
        for e in struct_errors:
            log(f"  FAIL: {e}")
        # Still create act-result.txt even if we bail
        with open(RESULT_FILE, "w") as f:
            f.write("Phase 1 structure tests failed. Act tests not run.\n")
            for e in struct_errors:
                f.write(f"  FAIL: {e}\n")
        sys.exit(1)

    # Phase 2: act integration tests
    log("\n" + "=" * 60)
    log("PHASE 2: ACT INTEGRATION TESTS")
    log("=" * 60)

    with open(RESULT_FILE, "w") as result_fh:
        result_fh.write("Semantic Version Bumper — Act Test Results\n")
        result_fh.write(f"{'=' * 60}\n")

        for tc in TEST_CASES:
            log(f"\n--- Test: {tc['name']} ---")
            output, exit_code = run_act_test(tc, result_fh)
            errs = assert_test_case(tc, output, exit_code)

            if errs:
                for e in errs:
                    log(f"  FAIL: {e}")
            else:
                log(f"  PASSED: {tc['name']}")

            all_errors.extend(errs)

    # Summary
    log("\n" + "=" * 60)
    log("SUMMARY")
    log("=" * 60)

    if all_errors:
        log(f"\n{len(all_errors)} failure(s):")
        for e in all_errors:
            log(f"  - {e}")
        sys.exit(1)
    else:
        log("\nAll tests PASSED!")
        sys.exit(0)


if __name__ == "__main__":
    main()
