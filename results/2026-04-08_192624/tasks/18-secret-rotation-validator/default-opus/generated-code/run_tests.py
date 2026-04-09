#!/usr/bin/env python3
"""
Test harness for Secret Rotation Validator.

TDD approach: Each test case defines expected values first, then runs the
validator through `act` and asserts on exact output.

All tests execute through the GitHub Actions workflow via `act push --rm`.
Results are appended to act-result.txt.

Test categories:
  1. Workflow structure tests (YAML parsing, actionlint, file refs)
  2. Functional tests via act (one per fixture)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import yaml

# Paths relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = os.path.join(SCRIPT_DIR, ".github", "workflows", "secret-rotation-validator.yml")
VALIDATOR_PATH = os.path.join(SCRIPT_DIR, "secret_rotation_validator.py")
FIXTURES_DIR = os.path.join(SCRIPT_DIR, "fixtures")
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Track overall pass/fail
passed = 0
failed = 0
errors = []


def log(msg):
    print(msg)


def record_pass(name):
    global passed
    passed += 1
    log(f"  PASS: {name}")


def record_fail(name, reason):
    global failed
    failed += 1
    errors.append(f"{name}: {reason}")
    log(f"  FAIL: {name} -- {reason}")


# ============================================================
# SECTION 1: Workflow Structure Tests
# ============================================================

def test_workflow_yaml_structure():
    """Parse the YAML and check expected structure (triggers, jobs, steps)."""
    log("\n=== Workflow Structure Tests ===")

    with open(WORKFLOW_PATH, "r") as f:
        wf = yaml.safe_load(f)

    # Check triggers
    triggers = wf.get("on", wf.get(True, {}))
    if "push" in triggers:
        record_pass("trigger: push present")
    else:
        record_fail("trigger: push present", "missing push trigger")

    if "pull_request" in triggers:
        record_pass("trigger: pull_request present")
    else:
        record_fail("trigger: pull_request present", "missing pull_request trigger")

    if "schedule" in triggers:
        record_pass("trigger: schedule present")
    else:
        record_fail("trigger: schedule present", "missing schedule trigger")

    if "workflow_dispatch" in triggers:
        record_pass("trigger: workflow_dispatch present")
    else:
        record_fail("trigger: workflow_dispatch present", "missing workflow_dispatch trigger")

    # Check jobs
    jobs = wf.get("jobs", {})
    if "validate-secrets" in jobs:
        record_pass("job: validate-secrets exists")
    else:
        record_fail("job: validate-secrets exists", "missing validate-secrets job")
        return

    job = jobs["validate-secrets"]
    steps = job.get("steps", [])

    # Check for checkout step
    checkout_found = any(
        s.get("uses", "").startswith("actions/checkout@") for s in steps
    )
    if checkout_found:
        record_pass("step: actions/checkout@v4 present")
    else:
        record_fail("step: actions/checkout@v4 present", "missing checkout step")

    # Check for python setup step
    python_found = any(
        s.get("uses", "").startswith("actions/setup-python@") for s in steps
    )
    if python_found:
        record_pass("step: actions/setup-python present")
    else:
        record_fail("step: actions/setup-python present", "missing setup-python step")

    # Check that the script is referenced
    script_ref_found = any(
        "secret_rotation_validator.py" in s.get("run", "") for s in steps
    )
    if script_ref_found:
        record_pass("step: references secret_rotation_validator.py")
    else:
        record_fail("step: references secret_rotation_validator.py", "script not referenced in any run step")


def test_workflow_file_references():
    """Verify the workflow references script files that actually exist."""
    log("\n=== File Reference Tests ===")

    if os.path.isfile(VALIDATOR_PATH):
        record_pass("secret_rotation_validator.py exists")
    else:
        record_fail("secret_rotation_validator.py exists", f"not found at {VALIDATOR_PATH}")

    if os.path.isfile(WORKFLOW_PATH):
        record_pass("workflow YAML exists")
    else:
        record_fail("workflow YAML exists", f"not found at {WORKFLOW_PATH}")


def test_actionlint():
    """Verify actionlint passes with exit code 0."""
    log("\n=== actionlint Validation ===")

    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        record_pass("actionlint passes with exit code 0")
    else:
        record_fail("actionlint passes with exit code 0", f"exit code {result.returncode}: {result.stdout}{result.stderr}")


# ============================================================
# SECTION 2: Functional Tests via act
# ============================================================

def make_workflow_yaml(warning_days=14, reference_date="2026-01-15", allow_fail=False):
    """Generate a workflow YAML string with the given parameters."""
    suffix = " || true" if allow_fail else ""
    return f"""name: Secret Rotation Validator

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  schedule:
    - cron: '0 8 * * 1'
  workflow_dispatch:
    inputs:
      warning_days:
        description: 'Warning window in days'
        required: false
        default: '14'
      output_format:
        description: 'Output format (json or markdown)'
        required: false
        default: 'json'

permissions:
  contents: read

env:
  WARNING_DAYS: '{warning_days}'
  OUTPUT_FORMAT: 'json'
  CONFIG_FILE: 'secrets_config.json'
  REFERENCE_DATE: '{reference_date}'

jobs:
  validate-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Validate secret rotation (JSON)
        run: |
          python3 secret_rotation_validator.py \\
            --config "$CONFIG_FILE" \\
            --warning-days "$WARNING_DAYS" \\
            --format json \\
            --reference-date "$REFERENCE_DATE"{suffix}

      - name: Validate secret rotation (Markdown)
        run: |
          python3 secret_rotation_validator.py \\
            --config "$CONFIG_FILE" \\
            --warning-days "$WARNING_DAYS" \\
            --format markdown \\
            --reference-date "$REFERENCE_DATE"{suffix}
"""


def setup_temp_repo(fixture_name, config_file, warning_days=14, reference_date="2026-01-15", allow_fail=False):
    """
    Create a temporary git repo with the project files and a specific fixture
    as the config file. Returns the temp directory path.
    """
    tmpdir = tempfile.mkdtemp(prefix=f"secret_test_{fixture_name}_")

    # Copy the validator script
    shutil.copy(VALIDATOR_PATH, os.path.join(tmpdir, "secret_rotation_validator.py"))

    # Copy the fixture as secrets_config.json
    fixture_path = os.path.join(FIXTURES_DIR, config_file)
    shutil.copy(fixture_path, os.path.join(tmpdir, "secrets_config.json"))

    # Create the workflow directory with a string template (avoids PyYAML's
    # `on` -> `true` boolean conversion issue)
    wf_dir = os.path.join(tmpdir, ".github", "workflows")
    os.makedirs(wf_dir)

    wf_content = make_workflow_yaml(warning_days, reference_date, allow_fail)
    with open(os.path.join(wf_dir, "secret-rotation-validator.yml"), "w") as f:
        f.write(wf_content)

    # Initialize git repo (act requires it)
    subprocess.run(["git", "init", tmpdir], capture_output=True)
    subprocess.run(["git", "-C", tmpdir, "config", "user.email", "test@test.com"], capture_output=True)
    subprocess.run(["git", "-C", tmpdir, "config", "user.name", "Test"], capture_output=True)
    subprocess.run(["git", "-C", tmpdir, "add", "."], capture_output=True)
    subprocess.run(["git", "-C", tmpdir, "commit", "-m", "init"], capture_output=True)

    return tmpdir


def run_act(tmpdir, expect_fail=False):
    """
    Run act push --rm in the temp repo directory.
    Returns (exit_code, output).
    """
    result = subprocess.run(
        ["act", "push", "--rm"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    output = result.stdout + "\n" + result.stderr
    return result.returncode, output


def append_result(fixture_name, output):
    """Append act output to act-result.txt."""
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"TEST CASE: {fixture_name}\n")
        f.write(f"{'='*60}\n")
        f.write(output)
        f.write(f"\n")


def test_all_ok_fixture():
    """
    Test: all secrets are OK (reference: 2026-01-15, warning: 14 days).
    Expected:
      - DB_PASSWORD: expires 2026-04-10, days=85, status=ok
      - API_KEY: expires 2026-07-04, days=170, status=ok
      - Summary: 0 expired, 0 warning, 2 ok
      - Exit code: 0 (no expired secrets)
    """
    log("\n--- Test: all_ok ---")
    tmpdir = setup_temp_repo("all_ok", "all_ok.json", warning_days=14)
    try:
        exit_code, output = run_act(tmpdir)
        append_result("all_ok", output)

        # act returns 0 when all jobs succeed
        if exit_code == 0:
            record_pass("all_ok: act exit code 0")
        else:
            record_fail("all_ok: act exit code 0", f"got exit code {exit_code}")

        # Check job succeeded
        if "Job succeeded" in output:
            record_pass("all_ok: Job succeeded")
        else:
            record_fail("all_ok: Job succeeded", "not found in output")

        # Check exact expected JSON values
        if '"expired": 0' in output:
            record_pass("all_ok: expired count is 0")
        else:
            record_fail("all_ok: expired count is 0", "not found in output")

        if '"warning": 0' in output:
            record_pass("all_ok: warning count is 0")
        else:
            record_fail("all_ok: warning count is 0", "not found in output")

        if '"ok": 2' in output:
            record_pass("all_ok: ok count is 2")
        else:
            record_fail("all_ok: ok count is 2", "not found in output")

        # Check exact secret classifications
        if '"days_until_expiry": 85' in output:
            record_pass("all_ok: DB_PASSWORD days_until_expiry is 85")
        else:
            record_fail("all_ok: DB_PASSWORD days_until_expiry is 85", "not found")

        if '"days_until_expiry": 170' in output:
            record_pass("all_ok: API_KEY days_until_expiry is 170")
        else:
            record_fail("all_ok: API_KEY days_until_expiry is 170", "not found")

        if '"expires_on": "2026-04-10"' in output:
            record_pass("all_ok: DB_PASSWORD expires_on is 2026-04-10")
        else:
            record_fail("all_ok: DB_PASSWORD expires_on is 2026-04-10", "not found")

        # Markdown output checks
        if "| OK | 2 |" in output:
            record_pass("all_ok: markdown OK count is 2")
        else:
            record_fail("all_ok: markdown OK count is 2", "not found")

        if "| Expired | 0 |" in output:
            record_pass("all_ok: markdown Expired count is 0")
        else:
            record_fail("all_ok: markdown Expired count is 0", "not found")

    finally:
        shutil.rmtree(tmpdir)


def test_mixed_status_fixture():
    """
    Test: mix of expired, warning, ok (reference: 2026-01-15, warning: 14 days).
    Expected:
      - DB_PASSWORD: expires 2025-12-30, days=-16, status=expired
      - API_KEY: expires 2026-01-25, days=10, status=warning
      - TLS_CERT: expires 2026-12-01, days=320, status=ok
      - Summary: 1 expired, 1 warning, 1 ok
      - Exit code: non-zero from the script (expired secrets exist),
        but the workflow step with || true lets job succeed.
    """
    log("\n--- Test: mixed_status ---")

    # For mixed_status we need the workflow to not fail on expired secrets,
    # so we use allow_fail=True (appends || true to run steps)
    tmpdir = setup_temp_repo("mixed_status", "mixed_status.json", warning_days=14, allow_fail=True)
    try:
        exit_code, output = run_act(tmpdir)
        append_result("mixed_status", output)

        if exit_code == 0:
            record_pass("mixed_status: act exit code 0")
        else:
            record_fail("mixed_status: act exit code 0", f"got {exit_code}")

        if "Job succeeded" in output:
            record_pass("mixed_status: Job succeeded")
        else:
            record_fail("mixed_status: Job succeeded", "not found")

        # Exact summary counts
        if '"expired": 1' in output:
            record_pass("mixed_status: expired count is 1")
        else:
            record_fail("mixed_status: expired count is 1", "not found")

        if '"warning": 1' in output:
            record_pass("mixed_status: warning count is 1")
        else:
            record_fail("mixed_status: warning count is 1", "not found")

        if '"ok": 1' in output:
            record_pass("mixed_status: ok count is 1")
        else:
            record_fail("mixed_status: ok count is 1", "not found")

        # Exact secret details
        if '"days_until_expiry": -16' in output:
            record_pass("mixed_status: DB_PASSWORD days=-16")
        else:
            record_fail("mixed_status: DB_PASSWORD days=-16", "not found")

        if '"days_until_expiry": 10' in output:
            record_pass("mixed_status: API_KEY days=10")
        else:
            record_fail("mixed_status: API_KEY days=10", "not found")

        if '"days_until_expiry": 320' in output:
            record_pass("mixed_status: TLS_CERT days=320")
        else:
            record_fail("mixed_status: TLS_CERT days=320", "not found")

        if '"expires_on": "2025-12-30"' in output:
            record_pass("mixed_status: DB_PASSWORD expires_on 2025-12-30")
        else:
            record_fail("mixed_status: DB_PASSWORD expires_on 2025-12-30", "not found")

        # Markdown section checks
        if "## EXPIRED (1)" in output:
            record_pass("mixed_status: markdown EXPIRED section has count 1")
        else:
            record_fail("mixed_status: markdown EXPIRED section has count 1", "not found")

        if "## WARNING (1)" in output:
            record_pass("mixed_status: markdown WARNING section has count 1")
        else:
            record_fail("mixed_status: markdown WARNING section has count 1", "not found")

        if "## OK (1)" in output:
            record_pass("mixed_status: markdown OK section has count 1")
        else:
            record_fail("mixed_status: markdown OK section has count 1", "not found")

    finally:
        shutil.rmtree(tmpdir)


def test_all_expired_fixture():
    """
    Test: all secrets expired (reference: 2026-01-15, warning: 14 days).
    Expected:
      - OLD_DB_SECRET: expires 2025-07-01, days=-198, status=expired
      - OLD_API_TOKEN: expires 2025-09-30, days=-107, status=expired
      - Summary: 2 expired, 0 warning, 0 ok
    """
    log("\n--- Test: all_expired ---")
    tmpdir = setup_temp_repo("all_expired", "all_expired.json", warning_days=14, allow_fail=True)
    try:
        exit_code, output = run_act(tmpdir)
        append_result("all_expired", output)

        if exit_code == 0:
            record_pass("all_expired: act exit code 0")
        else:
            record_fail("all_expired: act exit code 0", f"got {exit_code}")

        if "Job succeeded" in output:
            record_pass("all_expired: Job succeeded")
        else:
            record_fail("all_expired: Job succeeded", "not found")

        if '"expired": 2' in output:
            record_pass("all_expired: expired count is 2")
        else:
            record_fail("all_expired: expired count is 2", "not found")

        if '"warning": 0' in output:
            record_pass("all_expired: warning count is 0")
        else:
            record_fail("all_expired: warning count is 0", "not found")

        if '"ok": 0' in output:
            record_pass("all_expired: ok count is 0")
        else:
            record_fail("all_expired: ok count is 0", "not found")

        if '"days_until_expiry": -198' in output:
            record_pass("all_expired: OLD_DB_SECRET days=-198")
        else:
            record_fail("all_expired: OLD_DB_SECRET days=-198", "not found")

        if '"days_until_expiry": -107' in output:
            record_pass("all_expired: OLD_API_TOKEN days=-107")
        else:
            record_fail("all_expired: OLD_API_TOKEN days=-107", "not found")

        # Check markdown expired table
        if "## EXPIRED (2)" in output:
            record_pass("all_expired: markdown EXPIRED section has count 2")
        else:
            record_fail("all_expired: markdown EXPIRED section has count 2", "not found")

        if "No secrets in this category." in output:
            record_pass("all_expired: markdown shows 'No secrets in this category' for empty groups")
        else:
            record_fail("all_expired: markdown shows empty category message", "not found")

    finally:
        shutil.rmtree(tmpdir)


def test_warning_only_fixture():
    """
    Test: only warning-status secrets (reference: 2026-01-15, warning: 14 days).
    Expected:
      - SESSION_SECRET: expires 2026-01-24, days=9, status=warning
      - Summary: 0 expired, 1 warning, 0 ok
      - Exit code: 0 (no expired, just warnings)
    """
    log("\n--- Test: warning_only ---")
    tmpdir = setup_temp_repo("warning_only", "warning_only.json", warning_days=14)
    try:
        exit_code, output = run_act(tmpdir)
        append_result("warning_only", output)

        if exit_code == 0:
            record_pass("warning_only: act exit code 0")
        else:
            record_fail("warning_only: act exit code 0", f"got {exit_code}")

        if "Job succeeded" in output:
            record_pass("warning_only: Job succeeded")
        else:
            record_fail("warning_only: Job succeeded", "not found")

        if '"expired": 0' in output:
            record_pass("warning_only: expired count is 0")
        else:
            record_fail("warning_only: expired count is 0", "not found")

        if '"warning": 1' in output:
            record_pass("warning_only: warning count is 1")
        else:
            record_fail("warning_only: warning count is 1", "not found")

        if '"ok": 0' in output:
            record_pass("warning_only: ok count is 0")
        else:
            record_fail("warning_only: ok count is 0", "not found")

        if '"days_until_expiry": 9' in output:
            record_pass("warning_only: SESSION_SECRET days=9")
        else:
            record_fail("warning_only: SESSION_SECRET days=9", "not found")

        if '"expires_on": "2026-01-24"' in output:
            record_pass("warning_only: SESSION_SECRET expires_on 2026-01-24")
        else:
            record_fail("warning_only: SESSION_SECRET expires_on 2026-01-24", "not found")

        if "## WARNING (1)" in output:
            record_pass("warning_only: markdown WARNING section has count 1")
        else:
            record_fail("warning_only: markdown WARNING section has count 1", "not found")

    finally:
        shutil.rmtree(tmpdir)


def test_custom_warning_window():
    """
    Test: custom warning window of 30 days (reference: 2026-01-15).
    Expected:
      - WEBHOOK_SECRET: expires 2026-01-19, days=4, status=warning (within 30-day window)
      - ENCRYPTION_KEY: expires 2026-03-02, days=46, status=ok (outside 30-day window)
      - Summary: 0 expired, 1 warning, 1 ok
    """
    log("\n--- Test: custom_warning_window ---")
    tmpdir = setup_temp_repo("custom_warning_window", "custom_warning_window.json", warning_days=30)
    try:
        exit_code, output = run_act(tmpdir)
        append_result("custom_warning_window", output)

        if exit_code == 0:
            record_pass("custom_warning_window: act exit code 0")
        else:
            record_fail("custom_warning_window: act exit code 0", f"got {exit_code}")

        if "Job succeeded" in output:
            record_pass("custom_warning_window: Job succeeded")
        else:
            record_fail("custom_warning_window: Job succeeded", "not found")

        if '"expired": 0' in output:
            record_pass("custom_warning_window: expired count is 0")
        else:
            record_fail("custom_warning_window: expired count is 0", "not found")

        if '"warning": 1' in output:
            record_pass("custom_warning_window: warning count is 1")
        else:
            record_fail("custom_warning_window: warning count is 1", "not found")

        if '"ok": 1' in output:
            record_pass("custom_warning_window: ok count is 1")
        else:
            record_fail("custom_warning_window: ok count is 1", "not found")

        if '"days_until_expiry": 4' in output:
            record_pass("custom_warning_window: WEBHOOK_SECRET days=4")
        else:
            record_fail("custom_warning_window: WEBHOOK_SECRET days=4", "not found")

        if '"days_until_expiry": 46' in output:
            record_pass("custom_warning_window: ENCRYPTION_KEY days=46")
        else:
            record_fail("custom_warning_window: ENCRYPTION_KEY days=46", "not found")

        if '"expires_on": "2026-01-19"' in output:
            record_pass("custom_warning_window: WEBHOOK_SECRET expires_on 2026-01-19")
        else:
            record_fail("custom_warning_window: WEBHOOK_SECRET expires_on 2026-01-19", "not found")

    finally:
        shutil.rmtree(tmpdir)


def main():
    # Clear result file
    with open(RESULT_FILE, "w") as f:
        f.write("Secret Rotation Validator - Act Test Results\n")
        f.write(f"{'='*60}\n")

    # --- Workflow structure tests ---
    test_workflow_yaml_structure()
    test_workflow_file_references()
    test_actionlint()

    # --- Functional tests via act ---
    log("\n=== Functional Tests via act ===")
    test_all_ok_fixture()
    test_mixed_status_fixture()
    test_all_expired_fixture()
    test_warning_only_fixture()
    test_custom_warning_window()

    # --- Summary ---
    log(f"\n{'='*60}")
    log(f"RESULTS: {passed} passed, {failed} failed")
    if errors:
        log("FAILURES:")
        for e in errors:
            log(f"  - {e}")
    log(f"{'='*60}")

    # Append summary to result file
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"SUMMARY: {passed} passed, {failed} failed\n")
        if errors:
            f.write("FAILURES:\n")
            for e in errors:
                f.write(f"  - {e}\n")
        f.write(f"{'='*60}\n")

    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
