"""Test harness: runs the PR Label Assigner workflow via `act` and validates output.

Workflow structure tests run immediately (no Docker needed).
The act integration test runs the full pipeline and saves output to act-result.txt.

Usage:
    python3 run_tests.py
"""

import re
import subprocess
import sys
import yaml
from pathlib import Path

WORKSPACE = Path(__file__).parent
WORKFLOW_PATH = WORKSPACE / ".github" / "workflows" / "pr-label-assigner.yml"
ACT_RESULT_FILE = WORKSPACE / "act-result.txt"

# Exact expected LABELS: lines from the workflow fixture step
EXPECTED_FIXTURE_OUTPUTS = {
    "docs only":     "LABELS: documentation",
    "api and source": "LABELS: api,source",
    "tests label":   "LABELS: source,tests",
    "mixed":         "LABELS: api,documentation,source,tests",
    "no match":      "LABELS: (none)",
    "md anywhere":   "LABELS: documentation,source",
}

# Exact LABEL_RESULT: lines emitted by the parametrized pytest fixture tests
EXPECTED_PYTEST_LABEL_RESULTS = {
    "case_docs_only":        "LABEL_RESULT:case_docs_only:documentation",
    "case_api_and_source":   "LABEL_RESULT:case_api_and_source:api,source",
    "case_tests_label":      "LABEL_RESULT:case_tests_label:source,tests",
    "case_mixed":            "LABEL_RESULT:case_mixed:api,documentation,source,tests",
    "case_no_match":         "LABEL_RESULT:case_no_match:(none)",
    "case_md_anywhere":      "LABEL_RESULT:case_md_anywhere:documentation,source",
}


# ---------------------------------------------------------------------------
# Workflow structure tests (fast, no Docker)
# ---------------------------------------------------------------------------

def test_workflow_structure() -> list[str]:
    errors = []

    # 1. Workflow file exists
    if not WORKFLOW_PATH.exists():
        errors.append(f"Workflow file missing: {WORKFLOW_PATH}")
        return errors

    # 2. Valid YAML
    try:
        wf = yaml.safe_load(WORKFLOW_PATH.read_text())
    except yaml.YAMLError as exc:
        errors.append(f"Workflow is not valid YAML: {exc}")
        return errors

    # 3. Has required triggers — pyyaml parses the bare `on:` key as boolean True
    on = wf.get(True, wf.get("on", {})) or {}
    for trigger in ("push", "pull_request", "workflow_dispatch"):
        if trigger not in on:
            errors.append(f"Missing trigger: {trigger}")

    # 4. Has a 'test' job
    jobs = wf.get("jobs", {})
    if "test" not in jobs:
        errors.append("Missing job: 'test'")
    else:
        steps = jobs["test"].get("steps", [])
        step_names = [s.get("uses", "") + " " + s.get("name", "") for s in steps]

        # 5. Uses actions/checkout@v4
        if not any("actions/checkout@v4" in s for s in step_names):
            errors.append("Missing step: actions/checkout@v4")

        # 6. Sets up Python
        if not any("setup-python" in s for s in step_names):
            errors.append("Missing step: actions/setup-python")

        # 7. References pr_label_assigner.py
        run_scripts = [s.get("run", "") for s in steps]
        all_run = "\n".join(run_scripts)
        if "pr_label_assigner.py" not in all_run:
            errors.append("Workflow does not reference pr_label_assigner.py")

    # 8. Script file exists
    if not (WORKSPACE / "pr_label_assigner.py").exists():
        errors.append("pr_label_assigner.py does not exist")

    # 9. Tests directory exists
    if not (WORKSPACE / "tests").exists():
        errors.append("tests/ directory does not exist")

    return errors


def test_actionlint() -> tuple[bool, str]:
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True, text=True
    )
    return result.returncode == 0, result.stdout + result.stderr


# ---------------------------------------------------------------------------
# Act integration test
# ---------------------------------------------------------------------------

def run_act() -> tuple[int, str]:
    """Run act push --rm and return (exit_code, combined_output)."""
    # --pull=false: use the locally built act-ubuntu-pwsh:latest image as-is
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        capture_output=True,
        text=True,
        cwd=WORKSPACE,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def parse_and_assert_act_output(output: str) -> list[str]:
    """Assert exact expected values appear in the act output.  Returns list of failures."""
    failures = []

    # Job succeeded check
    if "Job succeeded" not in output:
        failures.append("Act output does not contain 'Job succeeded'")

    # Check exact LABELS: lines from fixture step
    for fixture_name, expected_line in EXPECTED_FIXTURE_OUTPUTS.items():
        if expected_line not in output:
            failures.append(f"Missing fixture output [{fixture_name}]: expected '{expected_line}'")

    # Check exact LABEL_RESULT: lines from pytest parametrized tests
    for case_id, expected_line in EXPECTED_PYTEST_LABEL_RESULTS.items():
        if expected_line not in output:
            failures.append(f"Missing pytest output [{case_id}]: expected '{expected_line}'")

    # All 34 pytest tests passed
    passed_match = re.search(r"(\d+) passed", output)
    if passed_match:
        passed_count = int(passed_match.group(1))
        if passed_count < 34:
            failures.append(f"Expected at least 34 tests passed, got {passed_count}")
    else:
        failures.append("Could not find pytest pass count in act output")

    return failures


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    print("=" * 60)
    print("PR Label Assigner — Test Harness")
    print("=" * 60)

    all_passed = True

    # --- Workflow structure tests ---
    print("\n[1] Workflow structure tests")
    struct_errors = test_workflow_structure()
    if struct_errors:
        for e in struct_errors:
            print(f"  FAIL: {e}")
        all_passed = False
    else:
        print("  PASS: all structure checks OK")

    # --- actionlint ---
    print("\n[2] actionlint validation")
    ok, lint_output = test_actionlint()
    if ok:
        print("  PASS: actionlint clean")
    else:
        print(f"  FAIL: actionlint reported errors:\n{lint_output}")
        all_passed = False

    # --- Act integration test ---
    print("\n[3] Act integration test (act push --rm)")
    print("  Running act… (this may take 30-90 seconds)")
    exit_code, act_output = run_act()

    # Save full act output
    delimiter = "=" * 60 + "\n"
    ACT_RESULT_FILE.write_text(
        delimiter + "ACT RUN: pr-label-assigner push\n" + delimiter + act_output
    )
    print(f"  Act output saved to: {ACT_RESULT_FILE}")

    if exit_code != 0:
        print(f"  FAIL: act exited with code {exit_code}")
        all_passed = False
    else:
        print("  PASS: act exited with code 0")

    act_failures = parse_and_assert_act_output(act_output)
    if act_failures:
        for f in act_failures:
            print(f"  FAIL: {f}")
        all_passed = False
    else:
        print("  PASS: all act output assertions satisfied")

    print("\n" + "=" * 60)
    if all_passed:
        print("ALL TESTS PASSED")
        return 0
    else:
        print("SOME TESTS FAILED — see above")
        return 1


if __name__ == "__main__":
    sys.exit(main())
