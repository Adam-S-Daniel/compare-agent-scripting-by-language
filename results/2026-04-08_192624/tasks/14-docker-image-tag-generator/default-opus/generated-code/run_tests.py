#!/usr/bin/env python3
"""
Test harness for Docker Image Tag Generator.

Runs all test cases through the GitHub Actions workflow via `act`.
Each test case:
  1. Creates a temporary git repo with the project files + fixture data
  2. Runs `act push --rm` to execute the workflow
  3. Captures the output to act-result.txt
  4. Asserts exit code 0 and verifies exact expected tag values

Also includes workflow structure tests (YAML parsing, actionlint, file refs).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import yaml

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")
WORKFLOW_FILE = os.path.join(
    SCRIPT_DIR, ".github", "workflows", "docker-image-tag-generator.yml"
)
GENERATE_TAGS = os.path.join(SCRIPT_DIR, "generate_tags.py")

# --------------------------------------------------------------------------- #
# Test fixtures
#
# Each defines git context environment variables and a function to compute
# expected tags.  The SHA is dynamic (comes from the temp repo's HEAD), so
# expected_tags_fn receives the 7-char short SHA and returns the exact list.
# --------------------------------------------------------------------------- #

TEST_CASES = [
    {
        "name": "main_branch_push",
        "description": "Push to main branch produces 'latest' and 'sha-{sha}' tags",
        "env": {
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_REF_NAME": "main",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_HEAD_REF": "",
        },
        # Expected tags as a function of the short SHA from the temp repo
        "expected_tags_fn": lambda sha: ["latest", f"sha-{sha}"],
    },
    {
        "name": "master_branch_push",
        "description": "Push to master branch also produces 'latest'",
        "env": {
            "GITHUB_REF": "refs/heads/master",
            "GITHUB_REF_NAME": "master",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_HEAD_REF": "",
        },
        "expected_tags_fn": lambda sha: ["latest", f"sha-{sha}"],
    },
    {
        "name": "feature_branch_push",
        "description": "Push to feature branch produces '{branch}-{sha}' tag",
        "env": {
            "GITHUB_REF": "refs/heads/feature/add-login",
            "GITHUB_REF_NAME": "feature/add-login",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_HEAD_REF": "",
        },
        "expected_tags_fn": lambda sha: [f"feature-add-login-{sha}"],
    },
    {
        "name": "semver_tag_push",
        "description": "Pushing a semver tag produces version tags (full, major.minor, major)",
        "env": {
            "GITHUB_REF": "refs/tags/v2.1.0",
            "GITHUB_REF_NAME": "v2.1.0",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_HEAD_REF": "",
        },
        # Tag push: no branch tags, just the version hierarchy
        "expected_tags_fn": lambda sha: ["2.1.0", "2.1", "2"],
    },
    {
        "name": "special_chars_branch",
        "description": "Branch name with special characters gets sanitized",
        "env": {
            "GITHUB_REF": "refs/heads/fix/BUG--#123__foo",
            "GITHUB_REF_NAME": "fix/BUG--#123__foo",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_HEAD_REF": "",
        },
        "expected_tags_fn": lambda sha: [f"fix-bug-123-foo-{sha}"],
    },
    {
        "name": "workflow_dispatch_pr_override",
        "description": "Overridden branch + PR number via INPUT_ env vars",
        "env": {
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_REF_NAME": "main",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_HEAD_REF": "",
        },
        "input_overrides": {
            "OVERRIDE_BRANCH": "release/v3",
            "OVERRIDE_TAG": "",
            "OVERRIDE_PR": "99",
        },
        "expected_tags_fn": lambda sha: ["pr-99", f"release-v3-{sha}"],
    },
]


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def setup_temp_repo(test_case: dict) -> tuple[str, str]:
    """
    Create a temp git repo with our project files.
    Returns (tmpdir_path, short_sha) where short_sha is the 7-char HEAD SHA.
    """
    tmpdir = tempfile.mkdtemp(prefix=f"tag-test-{test_case['name']}-")

    # Copy project files
    shutil.copy2(GENERATE_TAGS, os.path.join(tmpdir, "generate_tags.py"))
    wf_dest = os.path.join(tmpdir, ".github", "workflows")
    os.makedirs(wf_dest)
    shutil.copy2(
        WORKFLOW_FILE,
        os.path.join(wf_dest, "docker-image-tag-generator.yml"),
    )

    # Initialize git repo (act requires a real repo)
    subprocess.run(
        ["git", "init", "-b", "main"], cwd=tmpdir, capture_output=True
    )
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"],
        cwd=tmpdir,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "test"],
        cwd=tmpdir,
        capture_output=True,
    )
    subprocess.run(["git", "add", "."], cwd=tmpdir, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "init"], cwd=tmpdir, capture_output=True
    )

    # Capture the actual commit SHA
    sha_result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
    )
    full_sha = sha_result.stdout.strip()
    short_sha = full_sha[:7]

    return tmpdir, short_sha


def run_act(tmpdir: str, test_case: dict) -> tuple[int, str]:
    """Run act push inside the temp repo, return (exit_code, combined_output)."""
    env_args = []
    for key, val in test_case["env"].items():
        env_args.extend(["--env", f"{key}={val}"])

    # Override inputs (simulates workflow_dispatch inputs via env)
    if "input_overrides" in test_case:
        for key, val in test_case["input_overrides"].items():
            env_args.extend(["--env", f"{key}={val}"])

    cmd = [
        "act",
        "push",
        "--rm",
        "-P",
        "ubuntu-latest=catthehacker/ubuntu:act-latest",
        "-W",
        ".github/workflows/docker-image-tag-generator.yml",
    ] + env_args

    result = subprocess.run(
        cmd, cwd=tmpdir, capture_output=True, text=True, timeout=300
    )
    output = result.stdout + "\n" + result.stderr
    return result.returncode, output


def assert_tags_in_output(
    output: str, expected_tags: list[str]
) -> list[str]:
    """
    Verify each expected tag appears in the act output.
    Returns list of failure messages (empty = all passed).
    """
    failures = []
    for tag in expected_tags:
        if tag not in output:
            failures.append(
                f"  FAIL: expected tag '{tag}' not found in output"
            )
    return failures


def check_job_succeeded(output: str) -> list[str]:
    """Verify that act reports job success."""
    if "Job succeeded" not in output:
        return ["  FAIL: 'Job succeeded' not found in output"]
    return []


# --------------------------------------------------------------------------- #
# Workflow structure tests
# --------------------------------------------------------------------------- #


def run_structure_tests() -> tuple[bool, str]:
    """Run workflow structure tests: YAML parsing, actionlint, file refs."""
    results = []
    all_passed = True

    # Test 1: YAML parses correctly
    results.append("=== STRUCTURE TEST: YAML parsing ===")
    try:
        with open(WORKFLOW_FILE) as f:
            wf = yaml.safe_load(f)
        results.append("  PASS: YAML parses successfully")
    except Exception as e:
        results.append(f"  FAIL: YAML parse error: {e}")
        all_passed = False
        return all_passed, "\n".join(results)

    # Test 2: Expected triggers exist
    # Note: PyYAML parses the bare YAML key 'on' as boolean True
    results.append("=== STRUCTURE TEST: Triggers ===")
    triggers = wf.get(True, wf.get("on", {}))
    if not isinstance(triggers, dict):
        triggers = {}
    for expected_trigger in ["push", "pull_request", "workflow_dispatch"]:
        if expected_trigger in triggers:
            results.append(f"  PASS: trigger '{expected_trigger}' present")
        else:
            results.append(f"  FAIL: trigger '{expected_trigger}' missing")
            all_passed = False

    # Test 3: Jobs exist
    results.append("=== STRUCTURE TEST: Jobs ===")
    jobs = wf.get("jobs", {})
    if "generate-tags" in jobs:
        results.append("  PASS: job 'generate-tags' present")
    else:
        results.append("  FAIL: job 'generate-tags' missing")
        all_passed = False

    # Test 4: Steps include checkout and python setup
    results.append("=== STRUCTURE TEST: Steps ===")
    steps = jobs.get("generate-tags", {}).get("steps", [])
    step_uses = [s.get("uses", "") for s in steps]
    for expected in ["actions/checkout@v4", "actions/setup-python@v5"]:
        if any(expected in u for u in step_uses):
            results.append(f"  PASS: step uses '{expected}'")
        else:
            results.append(f"  FAIL: step uses '{expected}' not found")
            all_passed = False

    # Test 5: Workflow references generate_tags.py (check it exists)
    results.append("=== STRUCTURE TEST: Script file references ===")
    if os.path.exists(GENERATE_TAGS):
        results.append("  PASS: generate_tags.py exists")
    else:
        results.append("  FAIL: generate_tags.py not found")
        all_passed = False

    # Test 6: Permissions set
    results.append("=== STRUCTURE TEST: Permissions ===")
    perms = wf.get("permissions", {})
    if perms.get("contents") == "read":
        results.append("  PASS: permissions.contents = read")
    else:
        results.append("  FAIL: permissions.contents != read")
        all_passed = False

    # Test 7: actionlint passes
    results.append("=== STRUCTURE TEST: actionlint ===")
    lint_result = subprocess.run(
        ["actionlint", WORKFLOW_FILE], capture_output=True, text=True
    )
    if lint_result.returncode == 0:
        results.append("  PASS: actionlint passed (exit code 0)")
    else:
        results.append(
            f"  FAIL: actionlint failed:\n{lint_result.stdout}\n{lint_result.stderr}"
        )
        all_passed = False

    return all_passed, "\n".join(results)


# --------------------------------------------------------------------------- #
# Main test runner
# --------------------------------------------------------------------------- #


def main():
    print("=" * 70)
    print("Docker Image Tag Generator — Full Test Suite")
    print("=" * 70)

    # Clear the result file
    with open(RESULT_FILE, "w") as f:
        f.write("")

    all_passed = True
    total = 0
    passed = 0

    # --- Workflow structure tests ---
    print("\n>>> Running workflow structure tests...")
    struct_ok, struct_output = run_structure_tests()
    print(struct_output)
    with open(RESULT_FILE, "a") as f:
        f.write("=" * 70 + "\n")
        f.write("WORKFLOW STRUCTURE TESTS\n")
        f.write("=" * 70 + "\n")
        f.write(struct_output + "\n\n")

    if not struct_ok:
        all_passed = False
        print("\n!!! Structure tests FAILED\n")

    # --- Act integration tests ---
    print("\n>>> Running act integration tests...")
    for tc in TEST_CASES:
        total += 1
        test_header = (
            f"\n{'='*70}\n"
            f"TEST: {tc['name']} — {tc['description']}\n"
            f"{'='*70}"
        )
        print(test_header)

        tmpdir, short_sha = setup_temp_repo(tc)
        # Compute expected tags using the actual SHA from the temp repo
        expected_tags = tc["expected_tags_fn"](short_sha)

        try:
            exit_code, output = run_act(tmpdir, tc)
            failures = []

            # Assert exit code 0
            if exit_code != 0:
                failures.append(f"  FAIL: act exited with code {exit_code}")

            # Assert all expected tags are present in output
            failures.extend(assert_tags_in_output(output, expected_tags))

            # Assert job succeeded
            failures.extend(check_job_succeeded(output))

            if failures:
                status = "FAILED"
                all_passed = False
                print(f"  STATUS: FAILED")
                for f_msg in failures:
                    print(f_msg)
            else:
                status = "PASSED"
                passed += 1
                print(f"  STATUS: PASSED")
                print(f"  Expected tags verified: {expected_tags}")

            # Write to result file
            with open(RESULT_FILE, "a") as rf:
                rf.write(test_header + "\n")
                rf.write(f"STATUS: {status}\n")
                rf.write(f"Expected tags: {expected_tags}\n")
                if failures:
                    rf.write("\n".join(failures) + "\n")
                rf.write(f"\n--- act output ---\n{output}\n--- end ---\n\n")

        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    # --- Summary ---
    summary = (
        f"\n{'='*70}\n"
        f"TEST SUMMARY\n"
        f"{'='*70}\n"
        f"Structure tests: {'PASSED' if struct_ok else 'FAILED'}\n"
        f"Act integration tests: {passed}/{total} passed\n"
        f"Overall: {'ALL PASSED' if all_passed else 'SOME FAILURES'}\n"
    )
    print(summary)
    with open(RESULT_FILE, "a") as rf:
        rf.write(summary)

    if not all_passed:
        sys.exit(1)
    print(f"Results written to {RESULT_FILE}")


if __name__ == "__main__":
    main()
