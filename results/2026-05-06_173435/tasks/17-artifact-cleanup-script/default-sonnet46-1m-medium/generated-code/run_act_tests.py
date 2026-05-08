"""
Test harness: runs the GitHub Actions workflow via `act push --rm` and asserts
on exact expected values in the output.  Saves all act output to act-result.txt.

Also validates workflow structure (YAML parse, step references, actionlint).

Usage:
  python3 run_act_tests.py
"""

import subprocess
import sys
import os
import re
import yaml

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(WORKSPACE, "act-result.txt")
WORKFLOW_PATH = os.path.join(WORKSPACE, ".github", "workflows", "artifact-cleanup-script.yml")

# ---------------------------------------------------------------------------
# Workflow structure tests (instant, no Docker needed)
# ---------------------------------------------------------------------------

def test_workflow_structure():
    """Parse the YAML and verify expected triggers, jobs, and steps."""
    print("=== Workflow structure tests ===")

    with open(WORKFLOW_PATH) as f:
        wf = yaml.safe_load(f)

    # YAML 1.1 parses the bare word `on` as the Python boolean True; access accordingly.
    triggers = wf.get("on") or wf.get(True) or {}
    assert "push" in triggers, "workflow must trigger on push"
    assert "pull_request" in triggers, "workflow must trigger on pull_request"
    assert "schedule" in triggers, "workflow must have a schedule trigger"
    assert "workflow_dispatch" in triggers, "workflow must support manual dispatch"
    print("  PASS: triggers (push, pull_request, schedule, workflow_dispatch)")

    # Permissions
    assert wf.get("permissions", {}).get("contents") == "read", \
        "workflow must declare contents: read permission"
    print("  PASS: permissions")

    # Job exists
    assert "test" in wf["jobs"], "workflow must have a 'test' job"
    job = wf["jobs"]["test"]
    assert job["runs-on"] == "ubuntu-latest", "job must run on ubuntu-latest"
    print("  PASS: job 'test' on ubuntu-latest")

    # Required steps
    step_names = [s.get("name", "") for s in job["steps"]]
    uses_list  = [s.get("uses", "")  for s in job["steps"]]

    assert any("actions/checkout" in u for u in uses_list), \
        "workflow must use actions/checkout"
    print("  PASS: actions/checkout present")

    assert any("pytest" in s.get("run", "") for s in job["steps"]), \
        "workflow must have a step that runs pytest"
    print("  PASS: pytest step present")

    # Script file referenced in workflow must exist
    for step in job["steps"]:
        run_cmd = step.get("run", "")
        if "artifact_cleanup.py" in run_cmd:
            script_path = os.path.join(WORKSPACE, "artifact_cleanup.py")
            assert os.path.exists(script_path), \
                f"artifact_cleanup.py referenced in workflow but not found at {script_path}"
            print("  PASS: artifact_cleanup.py exists")
            break

    print("All workflow structure tests PASSED.\n")


def test_actionlint():
    """Assert that actionlint exits 0 on the workflow file."""
    print("=== actionlint validation ===")
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"FAIL: actionlint errors:\n{result.stdout}{result.stderr}")
        sys.exit(1)
    print("  PASS: actionlint exit code 0\n")


# ---------------------------------------------------------------------------
# act integration test
# ---------------------------------------------------------------------------

# Exact expected RESULT lines printed by pytest (see tests/test_artifact_cleanup.py).
EXPECTED_RESULTS = [
    "RESULT:test_max_age_policy:deleted=3,retained=1,space_reclaimed=225.0",
    "RESULT:test_keep_latest_n_policy:deleted=2,retained=2,space_reclaimed=150.0",
    "RESULT:test_max_total_size_policy:deleted=3,retained=1,space_reclaimed=225.0",
    "RESULT:test_combined_policies:deleted=3,retained=1,space_reclaimed=225.0",
    "RESULT:test_dry_run_mode:deleted=3,retained=1,dry_run=True",
    "RESULT:test_empty_artifact_list:deleted=0,retained=0,space_reclaimed=0",
    "RESULT:test_no_policy:deleted=0,retained=4,space_reclaimed=0",
    "RESULT:test_total_size_within_limit:deleted=0,retained=4,space_reclaimed=0",
]


def run_act() -> tuple[int, str]:
    """Run `act push --rm` and return (exit_code, combined_output)."""
    print("=== Running act push --rm (this takes ~30-90s) ===")
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        capture_output=True,
        text=True,
        cwd=WORKSPACE,
    )
    combined = result.stdout + "\n" + result.stderr
    return result.returncode, combined


def save_act_output(output: str, header: str = ""):
    with open(ACT_RESULT_FILE, "a") as f:
        if header:
            f.write(f"\n{'='*60}\n{header}\n{'='*60}\n")
        f.write(output)
        f.write("\n")


def test_act_run():
    """Run act, save output, assert on exact expected values."""
    print("=== act integration test ===")

    exit_code, output = run_act()
    save_act_output(output, header="act push --rm")

    # 1. Exit code must be 0
    if exit_code != 0:
        print(f"FAIL: act exited with code {exit_code}")
        print("--- act output (last 60 lines) ---")
        print("\n".join(output.splitlines()[-60:]))
        sys.exit(1)
    print(f"  PASS: act exit code 0")

    # 2. Every job must show "Job succeeded"
    if "Job succeeded" not in output:
        print("FAIL: 'Job succeeded' not found in act output")
        sys.exit(1)
    print("  PASS: 'Job succeeded' found in output")

    # 3. All expected RESULT lines must appear exactly
    failures = []
    for expected in EXPECTED_RESULTS:
        if expected not in output:
            failures.append(f"  MISSING: {expected}")
        else:
            print(f"  PASS: {expected}")

    if failures:
        print("\nFAILED — missing expected result lines:")
        for f in failures:
            print(f)
        sys.exit(1)

    # 4. pytest summary must show 8 passed
    if "8 passed" not in output:
        print("FAIL: expected '8 passed' in pytest summary")
        sys.exit(1)
    print("  PASS: '8 passed' in pytest output")

    print("\nAll act integration tests PASSED.\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Clear result file before the run
    open(ACT_RESULT_FILE, "w").close()

    test_workflow_structure()
    test_actionlint()
    test_act_run()

    print("=== ALL TESTS PASSED ===")
