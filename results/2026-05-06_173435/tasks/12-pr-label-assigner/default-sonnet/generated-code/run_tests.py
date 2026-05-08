#!/usr/bin/env python3
"""Outer test harness: spins up a temp git repo, runs `act push --rm`,
verifies the output, and writes all results to act-result.txt.

Usage:
    python3 run_tests.py

All test cases are run in a single `act push` invocation to stay within the
3-run budget. The workflow produces "CASE <name>: LABELS: [...]" lines that
this harness parses and asserts against known-good expected values from
test_fixture.json.

Exit code: 0 if all assertions pass, 1 otherwise.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

FAILURES: list[str] = []


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        FAILURES.append(f"ASSERTION FAILED: {message}")
        print(f"  FAIL: {message}")
    else:
        print(f"  PASS: {message}")


# ---------------------------------------------------------------------------
# Load test fixture to know the expected values
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

with open(os.path.join(SCRIPT_DIR, 'test_fixture.json')) as _f:
    FIXTURE = json.load(_f)


def expected_labels(case_name: str) -> list[str]:
    for case in FIXTURE['test_cases']:
        if case['name'] == case_name:
            return sorted(case['expected_labels'])
    raise KeyError(f"Test case '{case_name}' not found in fixture")


# ---------------------------------------------------------------------------
# Set up temp git repo with all project files
# ---------------------------------------------------------------------------

def build_temp_repo() -> str:
    """Copy project files into a fresh git repo and return its path."""
    tmpdir = tempfile.mkdtemp(prefix='pr-label-assigner-')
    files_to_copy = [
        'pr_label_assigner.py',
        'label_config.json',
        'test_fixture.json',
        'run_fixture_tests.py',
        '.github/workflows/pr-label-assigner.yml',
        'tests/__init__.py',
        'tests/test_pr_label_assigner.py',
        'tests/test_workflow_structure.py',
    ]
    for rel_path in files_to_copy:
        src = os.path.join(SCRIPT_DIR, rel_path)
        dst = os.path.join(tmpdir, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)

    # Copy .actrc so act uses the correct container image
    actrc_src = os.path.join(SCRIPT_DIR, '.actrc')
    if os.path.exists(actrc_src):
        shutil.copy2(actrc_src, os.path.join(tmpdir, '.actrc'))

    subprocess.run(['git', 'init', '-b', 'main'], cwd=tmpdir, check=True,
                   capture_output=True)
    subprocess.run(['git', 'config', 'user.email', 'test@test.com'], cwd=tmpdir,
                   check=True, capture_output=True)
    subprocess.run(['git', 'config', 'user.name', 'Test'], cwd=tmpdir,
                   check=True, capture_output=True)
    subprocess.run(['git', 'add', '-A'], cwd=tmpdir, check=True,
                   capture_output=True)
    subprocess.run(['git', 'commit', '-m', 'test: add pr label assigner'],
                   cwd=tmpdir, check=True, capture_output=True)
    return tmpdir


# ---------------------------------------------------------------------------
# Parse act output for CASE lines
# ---------------------------------------------------------------------------

CASE_LINE_RE = re.compile(r'CASE (\w+): LABELS: (\[.*?\])')


def parse_case_labels(output: str) -> dict[str, list[str]]:
    """Extract {case_name: sorted_labels} from act stdout."""
    results: dict[str, list[str]] = {}
    for line in output.splitlines():
        m = CASE_LINE_RE.search(line)
        if m:
            name = m.group(1)
            labels = sorted(json.loads(m.group(2)))
            results[name] = labels
    return results


# ---------------------------------------------------------------------------
# Main: run act and assert results
# ---------------------------------------------------------------------------

def main() -> int:
    act_result_path = os.path.join(SCRIPT_DIR, 'act-result.txt')

    print("=== PR Label Assigner — act test harness ===\n")
    print("Building temp git repo...")
    tmpdir = build_temp_repo()
    print(f"  Temp repo: {tmpdir}\n")

    print("Running `act push --rm` (this may take 30-90 seconds)...")
    result = subprocess.run(
        ['act', 'push', '--rm', '--pull=false'],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined_output = result.stdout + result.stderr

    # Write full output to act-result.txt (required artifact)
    delimiter = "=" * 60
    with open(act_result_path, 'w') as f:
        f.write(f"{delimiter}\n")
        f.write("ACT RUN: pr-label-assigner (all test cases)\n")
        f.write(f"{delimiter}\n")
        f.write("STDOUT:\n")
        f.write(result.stdout)
        f.write("\nSTDERR:\n")
        f.write(result.stderr)
        f.write(f"\nEXIT CODE: {result.returncode}\n")
        f.write(f"{delimiter}\n")

    print(f"\nact output saved to: {act_result_path}\n")
    print("--- act output (last 60 lines) ---")
    tail = combined_output.splitlines()[-60:]
    print('\n'.join(tail))
    print("---\n")

    # --- Assertions ---
    print("=== Assertions ===\n")

    # 1. act exited with code 0
    assert_true(result.returncode == 0,
                f"act exited with code 0 (got {result.returncode})")

    # 2. All jobs succeeded
    assert_true('Job succeeded' in combined_output,
                "'Job succeeded' appears in act output")

    # 3. Parse CASE lines and assert exact expected labels
    case_results = parse_case_labels(combined_output)

    for case in FIXTURE['test_cases']:
        name = case['name']
        exp = sorted(case['expected_labels'])
        got = case_results.get(name)
        assert_true(got is not None,
                    f"CASE '{name}' output line found in act output")
        if got is not None:
            assert_true(got == exp,
                        f"CASE '{name}': labels == {json.dumps(exp)} (got {json.dumps(got)})")

    # 4. All fixture test cases ran
    assert_true(len(case_results) >= len(FIXTURE['test_cases']),
                f"All {len(FIXTURE['test_cases'])} test cases produced output")

    # 5. pytest output shows passing tests
    assert_true('passed' in combined_output,
                "pytest reports tests passed")

    # Cleanup
    shutil.rmtree(tmpdir, ignore_errors=True)

    # Summary
    print(f"\n{'=' * 40}")
    if FAILURES:
        print(f"RESULT: {len(FAILURES)} assertion(s) FAILED:")
        for f in FAILURES:
            print(f"  {f}")
        return 1
    else:
        print("RESULT: All assertions PASSED")
        return 0


if __name__ == '__main__':
    sys.exit(main())
