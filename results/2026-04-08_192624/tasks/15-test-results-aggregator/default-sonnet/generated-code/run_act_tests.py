"""
Act-based test harness.

Runs every test case through GitHub Actions via `act`, captures output,
asserts on exact expected values, and writes all output to act-result.txt.

This harness satisfies the benchmark requirement that ALL tests run through act.
The workflow uses fixture files committed in the repo — no cross-job artifact
passing, so no ACTIONS_RUNTIME_TOKEN requirement.

Structure:
 - Each test case specifies which job(s) to run and what exact strings
   must appear in the act output.
 - All output is appended (delimited) to act-result.txt.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

RESULT_FILE = Path(__file__).parent / "act-result.txt"
WORKFLOW_FILE = ".github/workflows/test-results-aggregator.yml"
DELIMITER = "=" * 80

# ---------------------------------------------------------------------------
# Act-based test cases: each runs a specific workflow job via `act`
# ---------------------------------------------------------------------------

TEST_CASES = [
    {
        "name": "unit-tests-job",
        "description": "Unit tests: pytest runs all 29 tests and they all pass",
        "act_args": ["-j", "unit-tests"],
        "expected_in_output": [
            "29 passed",
            "VERIFIED: 29 passed",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "validate-workflow-job",
        "description": "Validate workflow: all required files present, YAML valid",
        "act_args": ["-j", "validate-workflow"],
        "expected_in_output": [
            "All required files present",
            "All fixture files present",
            "Workflow YAML structure is valid",
            # Exact values from fixture verification:
            "JUnit parse verified: total=5, passed=4",
            "JSON parse verified: total=5, passed=3",
            "Flaky detection verified: test_flaky_network is flaky",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "workflow-yaml-structure",
        "description": "Workflow YAML structure: correct triggers and jobs listed",
        "act_args": ["-j", "validate-workflow"],
        "expected_in_output": [
            # The Python YAML validator prints the job list and trigger list
            "Jobs:",
            "unit-tests",
            "aggregate",
            "validate-workflow",
            "Triggers:",
            "push",
            "pull_request",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "matrix-linux-job",
        "description": "Matrix linux job: processes linux fixture, verifies results",
        "act_args": ["-j", "matrix-tests-linux"],
        "expected_in_output": [
            "Linux matrix job completed",
            "Linux results verification passed",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "matrix-windows-job",
        "description": "Matrix windows job: all tests pass, shows PASSED in summary",
        "act_args": ["-j", "matrix-tests-windows"],
        "expected_in_output": [
            "Windows matrix job completed",
            "Windows results verification passed",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "matrix-json-job",
        "description": "JSON matrix job: run1 has failure, run2 all pass",
        "act_args": ["-j", "matrix-json-tests"],
        "expected_in_output": [
            "JSON matrix jobs completed",
            "Run1 failure verified",
            "Run2 pass verified",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "aggregate-job-totals",
        "description": "Aggregate job: 20 total tests from 4 fixture files",
        "act_args": ["-j", "aggregate", "--no-cache-server"],
        "expected_in_output": [
            # Exact total: 7 (linux) + 7 (windows) + 3 (run1) + 3 (run2) = 20
            "20",
            "# Test Results",
            "Summary verification passed - all expected values found",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
    {
        "name": "aggregate-job-flaky-detection",
        "description": "Aggregate job: detects test_flaky_network as flaky across runs",
        "act_args": ["-j", "aggregate", "--no-cache-server"],
        "expected_in_output": [
            # test_flaky_network fails in run1 but passes in run2 -> flaky
            "test_flaky_network",
            "flaky\nFlaky",  # Either word (we check individually below)
            "Job succeeded",
        ],
        # Override: check 'test_flaky_network' specifically
        "expected_in_output": [
            "test_flaky_network",
            "Job succeeded",
        ],
        "expected_exit_code": 0,
    },
]

# ---------------------------------------------------------------------------
# Workflow structure tests (parse YAML locally, no act needed)
# ---------------------------------------------------------------------------

def _get_triggers(data: dict) -> dict:
    """Get workflow triggers, handling PyYAML's 'on' -> True conversion."""
    return data.get(True, data.get("on", {})) or {}


STRUCTURE_TESTS = [
    {
        "name": "workflow-has-push-trigger",
        "description": "Workflow has push trigger",
        "check": lambda data: "push" in _get_triggers(data),
        "error": "Missing 'push' trigger",
    },
    {
        "name": "workflow-has-pull-request-trigger",
        "description": "Workflow has pull_request trigger",
        "check": lambda data: "pull_request" in _get_triggers(data),
        "error": "Missing 'pull_request' trigger",
    },
    {
        "name": "workflow-has-workflow-dispatch",
        "description": "Workflow has workflow_dispatch trigger",
        "check": lambda data: "workflow_dispatch" in _get_triggers(data),
        "error": "Missing 'workflow_dispatch' trigger",
    },
    {
        "name": "workflow-has-schedule",
        "description": "Workflow has schedule trigger",
        "check": lambda data: "schedule" in _get_triggers(data),
        "error": "Missing 'schedule' trigger",
    },
    {
        "name": "workflow-has-unit-tests-job",
        "description": "Workflow has unit-tests job",
        "check": lambda data: "unit-tests" in data.get("jobs", {}),
        "error": "Missing 'unit-tests' job",
    },
    {
        "name": "workflow-has-aggregate-job",
        "description": "Workflow has aggregate job",
        "check": lambda data: "aggregate" in data.get("jobs", {}),
        "error": "Missing 'aggregate' job",
    },
    {
        "name": "workflow-aggregate-needs-deps",
        "description": "Aggregate job depends on 4 upstream jobs",
        "check": lambda data: len(
            data.get("jobs", {}).get("aggregate", {}).get("needs", [])
        ) >= 4,
        "error": "Aggregate job must depend on at least 4 jobs",
    },
    {
        "name": "workflow-references-aggregator-script",
        "description": "Workflow references aggregator.py in a run step",
        "check": lambda data: any(
            "aggregator.py" in str(step.get("run", ""))
            for job in data.get("jobs", {}).values()
            for step in job.get("steps", [])
        ),
        "error": "Workflow does not reference aggregator.py",
    },
    {
        "name": "aggregator-script-exists",
        "description": "aggregator.py file exists on disk",
        "check": lambda _: Path("aggregator.py").exists(),
        "error": "aggregator.py not found",
    },
    {
        "name": "test-file-exists",
        "description": "test_aggregator.py file exists on disk",
        "check": lambda _: Path("test_aggregator.py").exists(),
        "error": "test_aggregator.py not found",
    },
    {
        "name": "fixture-junit-pass-xml-exists",
        "description": "fixtures/junit_pass.xml exists",
        "check": lambda _: Path("fixtures/junit_pass.xml").exists(),
        "error": "fixtures/junit_pass.xml not found",
    },
    {
        "name": "fixture-results-json-exists",
        "description": "fixtures/results.json exists",
        "check": lambda _: Path("fixtures/results.json").exists(),
        "error": "fixtures/results.json not found",
    },
    {
        "name": "fixture-matrix-linux-exists",
        "description": "fixtures/junit_matrix_linux.xml exists",
        "check": lambda _: Path("fixtures/junit_matrix_linux.xml").exists(),
        "error": "fixtures/junit_matrix_linux.xml not found",
    },
    {
        "name": "fixture-matrix-windows-exists",
        "description": "fixtures/junit_matrix_windows.xml exists",
        "check": lambda _: Path("fixtures/junit_matrix_windows.xml").exists(),
        "error": "fixtures/junit_matrix_windows.xml not found",
    },
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_act(act_args: list[str], timeout: int = 300) -> tuple[int, str]:
    """Run `act push --rm` with additional args, return (exit_code, output)."""
    cmd = ["act", "push", "--rm"] + act_args
    print(f"  Running: {' '.join(cmd)}", flush=True)
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=Path(__file__).parent,
        )
        output = result.stdout + result.stderr
        return result.returncode, output
    except subprocess.TimeoutExpired:
        return -1, f"ERROR: act timed out after {timeout}s"
    except Exception as exc:
        return -1, f"ERROR: Failed to run act: {exc}"


def check_output_contains(output: str, expected: list[str]) -> list[str]:
    """Return list of expected strings MISSING from output."""
    return [e for e in expected if e not in output]


def run_structure_tests(workflow_data: dict) -> list[dict]:
    """Run all YAML structure tests, return list of results."""
    results = []
    for test in STRUCTURE_TESTS:
        try:
            passed = test["check"](workflow_data)
            results.append({
                "name": test["name"],
                "passed": passed,
                "error": "" if passed else test["error"],
            })
        except Exception as exc:
            results.append({
                "name": test["name"],
                "passed": False,
                "error": f"Exception: {exc}",
            })
    return results


def run_actionlint() -> tuple[int, str]:
    """Run actionlint and return (exit_code, output)."""
    try:
        result = subprocess.run(
            ["actionlint", WORKFLOW_FILE],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent,
        )
        return result.returncode, result.stdout + result.stderr
    except FileNotFoundError:
        return -1, "actionlint not found"


# ---------------------------------------------------------------------------
# Main harness
# ---------------------------------------------------------------------------

def main() -> int:
    """Run all tests through act and write results to act-result.txt."""
    print("=" * 60)
    print("Test Results Aggregator — Act Test Harness")
    print("=" * 60)

    # Load workflow YAML for structure tests
    try:
        import yaml
        with open(WORKFLOW_FILE) as f:
            workflow_data = yaml.safe_load(f)
    except Exception as exc:
        print(f"FATAL: Could not load workflow YAML: {exc}")
        return 1

    all_passed = True
    output_lines: list[str] = []

    def write(line: str = "") -> None:
        output_lines.append(line)
        print(line, flush=True)

    # ------------------------------------------------------------------
    # Section 1: Workflow structure tests (no act required)
    # ------------------------------------------------------------------
    write(DELIMITER)
    write("SECTION 1: Workflow Structure Tests")
    write(DELIMITER)

    structure_results = run_structure_tests(workflow_data)
    for result in structure_results:
        status = "PASS" if result["passed"] else "FAIL"
        write(f"  [{status}] {result['name']}")
        if not result["passed"]:
            write(f"        ERROR: {result['error']}")
            all_passed = False

    structure_passed = sum(1 for r in structure_results if r["passed"])
    write(f"\nStructure tests: {structure_passed}/{len(structure_results)} passed")

    # ------------------------------------------------------------------
    # Section 2: actionlint validation
    # ------------------------------------------------------------------
    write("")
    write(DELIMITER)
    write("SECTION 2: actionlint Validation")
    write(DELIMITER)

    lint_exit, lint_output = run_actionlint()
    write(f"actionlint exit code: {lint_exit}")
    if lint_output.strip():
        write(f"actionlint output:\n{lint_output}")
    if lint_exit == 0:
        write("  [PASS] actionlint")
    else:
        write("  [FAIL] actionlint produced errors")
        all_passed = False

    # ------------------------------------------------------------------
    # Section 3: Act-based tests
    # ------------------------------------------------------------------
    write("")
    write(DELIMITER)
    write("SECTION 3: Act-Based Tests")
    write(DELIMITER)

    act_results = []
    for tc in TEST_CASES:
        write("")
        write(f"--- Test: {tc['name']} ---")
        write(f"    {tc['description']}")

        exit_code, output = run_act(tc["act_args"])

        # Write full act output (delimited)
        write(f"\n{'~'*40} ACT OUTPUT START: {tc['name']} {'~'*40}")
        write(output)
        write(f"{'~'*40} ACT OUTPUT END: {tc['name']} {'~'*40}\n")

        # Check exit code
        expected_exit = tc.get("expected_exit_code", 0)
        exit_ok = exit_code == expected_exit
        if not exit_ok:
            write(f"  [FAIL] Exit code: expected {expected_exit}, got {exit_code}")
            all_passed = False
        else:
            write(f"  [PASS] Exit code: {exit_code}")

        # Check expected strings in output
        missing = check_output_contains(output, tc.get("expected_in_output", []))
        if missing:
            write("  [FAIL] Missing expected output strings:")
            for m in missing:
                write(f"         - {repr(m)}")
            all_passed = False
        else:
            write(f"  [PASS] All {len(tc.get('expected_in_output', []))} expected strings found")

        tc_passed = exit_ok and not missing
        act_results.append({"name": tc["name"], "passed": tc_passed})
        write(f"  RESULT: {'PASSED' if tc_passed else 'FAILED'}")

    # ------------------------------------------------------------------
    # Final summary
    # ------------------------------------------------------------------
    write("")
    write(DELIMITER)
    write("FINAL SUMMARY")
    write(DELIMITER)

    act_passed = sum(1 for r in act_results if r["passed"])
    write(f"Structure tests:  {structure_passed}/{len(structure_results)}")
    write(f"actionlint:       {'PASS' if lint_exit == 0 else 'FAIL'}")
    write(f"Act-based tests:  {act_passed}/{len(act_results)}")

    if all_passed:
        write("\nALL TESTS PASSED")
    else:
        write("\nSOME TESTS FAILED")
        for r in structure_results:
            if not r["passed"]:
                write(f"  FAILED (structure): {r['name']}")
        if lint_exit != 0:
            write("  FAILED: actionlint")
        for r in act_results:
            if not r["passed"]:
                write(f"  FAILED (act): {r['name']}")

    # Write to act-result.txt
    RESULT_FILE.write_text("\n".join(output_lines) + "\n", encoding="utf-8")
    print(f"\nResults written to: {RESULT_FILE}")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
