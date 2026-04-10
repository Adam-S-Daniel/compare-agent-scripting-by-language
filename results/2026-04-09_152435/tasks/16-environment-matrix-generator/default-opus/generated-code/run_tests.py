#!/usr/bin/env python3
"""
Test harness for the Environment Matrix Generator.

Runs all tests through GitHub Actions via act, then verifies exact expected
values from the captured output. Also performs structural workflow tests
that don't require act.

TDD approach: expected values defined first, implementation verified against them.

Saves all output to act-result.txt as a required artifact.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW_PATH = ".github/workflows/environment-matrix-generator.yml"
ACT_RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Files to copy into each temp git repo for act
PROJECT_FILES = [
    "matrix_generator.py",
    ".github/workflows/environment-matrix-generator.yml",
    ".actrc",
    "fixtures/basic_matrix.json",
    "fixtures/with_include.json",
    "fixtures/with_exclude.json",
    "fixtures/full_config.json",
    "fixtures/oversized.json",
    "fixtures/error_invalid.json",
]

# ---------------------------------------------------------------------------
# Expected results for each fixture (TDD: these are the "red" assertions)
# ---------------------------------------------------------------------------
EXPECTED = {
    # Fixture 1: simple 2x2 cartesian product
    "basic_matrix": {
        "status": "success",
        "total_combinations": 4,
        "fail_fast": True,
        "has_max_parallel": False,
        "computed_combinations": [
            {"os": "ubuntu-latest", "python-version": "3.10"},
            {"os": "ubuntu-latest", "python-version": "3.11"},
            {"os": "windows-latest", "python-version": "3.10"},
            {"os": "windows-latest", "python-version": "3.11"},
        ],
    },
    # Fixture 2: 1x2 base + 1 include = 3 total
    "with_include": {
        "status": "success",
        "total_combinations": 3,
        "fail_fast": True,
        "has_max_parallel": False,
        "computed_combinations": [
            {"node-version": "16", "os": "ubuntu-latest"},
            {"node-version": "18", "os": "ubuntu-latest"},
            {"experimental": True, "node-version": "20", "os": "macos-latest"},
        ],
    },
    # Fixture 3: 3x3 = 9 minus 2 excludes = 7
    "with_exclude": {
        "status": "success",
        "total_combinations": 7,
        "fail_fast": True,
        "has_max_parallel": False,
        "computed_combinations": [
            {"os": "macos-latest", "python-version": "3.10"},
            {"os": "macos-latest", "python-version": "3.11"},
            {"os": "ubuntu-latest", "python-version": "3.9"},
            {"os": "ubuntu-latest", "python-version": "3.10"},
            {"os": "ubuntu-latest", "python-version": "3.11"},
            {"os": "windows-latest", "python-version": "3.10"},
            {"os": "windows-latest", "python-version": "3.11"},
        ],
    },
    # Fixture 4: 2x3 = 6 minus 1 exclude = 5, plus 1 include = 6
    "full_config": {
        "status": "success",
        "total_combinations": 6,
        "fail_fast": False,
        "max_parallel": 3,
        "has_max_parallel": True,
        "computed_combinations": [
            {"os": "ubuntu-latest", "ruby-version": "2.7"},
            {"os": "ubuntu-latest", "ruby-version": "3.0"},
            {"os": "ubuntu-latest", "ruby-version": "3.1"},
            {"os": "windows-latest", "ruby-version": "3.0"},
            {"os": "windows-latest", "ruby-version": "3.1"},
            {"coverage": True, "os": "ubuntu-latest", "ruby-version": "3.2"},
        ],
    },
    # Fixture 5: 10x10x10 = 1000 > max-size 50 -- must error
    "oversized": {
        "status": "error",
        "error_contains": "Matrix size 1000 exceeds maximum allowed size of 50",
    },
    # Fixture 6: missing 'matrix' key -- must error
    "error_invalid": {
        "status": "error",
        "error_contains": "must contain a 'matrix' key",
    },
}


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------
def log(msg):
    """Print a test status message."""
    print(f"  {msg}")


def log_pass(msg):
    print(f"  PASS: {msg}")


def log_fail(msg):
    print(f"  FAIL: {msg}")


def extract_sections(act_output):
    """Parse act output into named sections between START/END markers.

    Returns dict mapping fixture name to list of content lines (with act
    prefixes stripped).
    """
    sections = {}
    current_name = None
    current_lines = []

    for line in act_output.splitlines():
        # Strip act prefix: e.g. "[Job/step]   | actual content"
        content = line
        pipe_match = re.search(r"\|\s?(.*)", line)
        if pipe_match:
            content = pipe_match.group(1)

        start_match = re.match(r"=== START:(\S+) ===", content)
        end_match = re.match(r"=== END:(\S+) ===", content)

        if start_match:
            current_name = start_match.group(1)
            current_lines = []
        elif end_match and current_name:
            sections[current_name] = current_lines
            current_name = None
            current_lines = []
        elif current_name is not None:
            current_lines.append(content)

    return sections


def parse_json_from_lines(lines):
    """Try to parse JSON from a list of lines (skip non-JSON lines)."""
    text = "\n".join(lines).strip()
    # Find the JSON object in the text
    brace_start = text.find("{")
    if brace_start == -1:
        return None
    # Find matching closing brace
    depth = 0
    for i in range(brace_start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[brace_start : i + 1])
                except json.JSONDecodeError:
                    return None
    return None


# ---------------------------------------------------------------------------
# Structural workflow tests (no act required)
# ---------------------------------------------------------------------------
def run_structural_tests():
    """Validate workflow YAML structure, file references, and actionlint."""
    print("\n===== STRUCTURAL TESTS =====")
    failures = []

    workflow_file = os.path.join(SCRIPT_DIR, WORKFLOW_PATH)

    # Test 1: workflow file exists
    if os.path.exists(workflow_file):
        log_pass("Workflow file exists")
    else:
        log_fail("Workflow file missing")
        failures.append("Workflow file missing")
        return failures  # can't continue

    # Test 2: parse YAML and check structure
    # Use a simple approach: read as text and check for expected patterns
    with open(workflow_file) as f:
        wf_text = f.read()

    # Check triggers
    for trigger in ["push", "pull_request", "workflow_dispatch"]:
        if trigger in wf_text:
            log_pass(f"Trigger '{trigger}' found")
        else:
            log_fail(f"Trigger '{trigger}' missing")
            failures.append(f"Trigger '{trigger}' missing")

    # Check jobs section
    if "jobs:" in wf_text:
        log_pass("'jobs:' section found")
    else:
        log_fail("'jobs:' section missing")
        failures.append("'jobs:' section missing")

    # Check actions/checkout
    if "actions/checkout@v4" in wf_text:
        log_pass("actions/checkout@v4 referenced")
    else:
        log_fail("actions/checkout@v4 not referenced")
        failures.append("actions/checkout@v4 missing")

    # Check that it references matrix_generator.py
    if "matrix_generator.py" in wf_text:
        log_pass("References matrix_generator.py")
    else:
        log_fail("Does not reference matrix_generator.py")
        failures.append("matrix_generator.py not referenced")

    # Test 3: verify referenced script files exist
    script_file = os.path.join(SCRIPT_DIR, "matrix_generator.py")
    if os.path.exists(script_file):
        log_pass("matrix_generator.py exists")
    else:
        log_fail("matrix_generator.py missing")
        failures.append("matrix_generator.py missing")

    # Test 4: actionlint passes
    result = subprocess.run(
        ["actionlint", workflow_file],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        log_pass("actionlint passes (exit code 0)")
    else:
        log_fail(f"actionlint failed:\n{result.stdout}\n{result.stderr}")
        failures.append(f"actionlint failed: {result.stdout.strip()}")

    return failures


# ---------------------------------------------------------------------------
# Act-based integration tests
# ---------------------------------------------------------------------------
def setup_temp_repo():
    """Create a temporary git repo with all project files for act."""
    tmp_dir = tempfile.mkdtemp(prefix="matrix-gen-test-")

    # Copy project files into temp dir
    for rel_path in PROJECT_FILES:
        src = os.path.join(SCRIPT_DIR, rel_path)
        dst = os.path.join(tmp_dir, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)

    # Initialize git repo (act requires it)
    subprocess.run(
        ["git", "init"],
        cwd=tmp_dir,
        capture_output=True,
        check=True,
    )
    subprocess.run(
        ["git", "add", "."],
        cwd=tmp_dir,
        capture_output=True,
        check=True,
    )
    subprocess.run(
        ["git", "-c", "user.name=test", "-c", "user.email=test@test.com",
         "commit", "-m", "initial"],
        cwd=tmp_dir,
        capture_output=True,
        check=True,
    )

    return tmp_dir


def run_act(tmp_dir):
    """Run act push --rm in the temp repo and return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=180,
    )
    # Combine stdout and stderr (act sends some output to stderr)
    output = result.stdout + "\n" + result.stderr
    return result.returncode, output


def verify_success_fixture(name, section_lines, expected):
    """Verify a success fixture's output against expected values."""
    failures = []

    parsed = parse_json_from_lines(section_lines)
    if parsed is None:
        failures.append(f"{name}: Could not parse JSON from output")
        return failures

    # Check total_combinations
    actual_total = parsed.get("total_combinations")
    expected_total = expected["total_combinations"]
    if actual_total == expected_total:
        log_pass(f"{name}: total_combinations = {actual_total}")
    else:
        log_fail(f"{name}: total_combinations = {actual_total}, expected {expected_total}")
        failures.append(f"{name}: total_combinations mismatch")

    # Check fail-fast
    strategy = parsed.get("strategy", {})
    actual_ff = strategy.get("fail-fast")
    expected_ff = expected["fail_fast"]
    if actual_ff == expected_ff:
        log_pass(f"{name}: fail-fast = {actual_ff}")
    else:
        log_fail(f"{name}: fail-fast = {actual_ff}, expected {expected_ff}")
        failures.append(f"{name}: fail-fast mismatch")

    # Check max-parallel
    if expected.get("has_max_parallel"):
        actual_mp = strategy.get("max-parallel")
        expected_mp = expected["max_parallel"]
        if actual_mp == expected_mp:
            log_pass(f"{name}: max-parallel = {actual_mp}")
        else:
            log_fail(f"{name}: max-parallel = {actual_mp}, expected {expected_mp}")
            failures.append(f"{name}: max-parallel mismatch")
    else:
        if "max-parallel" not in strategy:
            log_pass(f"{name}: no max-parallel (as expected)")
        else:
            log_fail(f"{name}: unexpected max-parallel = {strategy.get('max-parallel')}")
            failures.append(f"{name}: unexpected max-parallel")

    # Check computed_combinations -- sort both for deterministic comparison
    actual_combos = parsed.get("computed_combinations", [])
    expected_combos = expected["computed_combinations"]

    # Normalize: sort list of dicts by their sorted key-value pairs
    def sort_key(d):
        return sorted(d.items())

    actual_sorted = sorted(actual_combos, key=sort_key)
    expected_sorted = sorted(expected_combos, key=sort_key)

    if actual_sorted == expected_sorted:
        log_pass(f"{name}: computed_combinations match ({len(actual_sorted)} entries)")
    else:
        log_fail(f"{name}: computed_combinations mismatch")
        log(f"  Expected: {json.dumps(expected_sorted, sort_keys=True)}")
        log(f"  Actual:   {json.dumps(actual_sorted, sort_keys=True)}")
        failures.append(f"{name}: computed_combinations mismatch")

    return failures


def verify_error_fixture(name, section_lines, expected):
    """Verify an error fixture's output contains expected error text."""
    failures = []
    section_text = "\n".join(section_lines)

    expected_msg = expected["error_contains"]
    if expected_msg in section_text:
        log_pass(f"{name}: error message found: '{expected_msg}'")
    else:
        log_fail(f"{name}: expected error '{expected_msg}' not in output")
        log(f"  Actual output: {section_text[:300]}")
        failures.append(f"{name}: error message missing")

    # Verify EXIT_CODE is non-zero
    exit_match = re.search(r"EXIT_CODE:(\d+)", section_text)
    if exit_match:
        code = int(exit_match.group(1))
        if code != 0:
            log_pass(f"{name}: EXIT_CODE = {code} (non-zero)")
        else:
            log_fail(f"{name}: EXIT_CODE = 0, expected non-zero")
            failures.append(f"{name}: exit code was 0")
    else:
        log_fail(f"{name}: EXIT_CODE not found in output")
        failures.append(f"{name}: EXIT_CODE missing")

    return failures


def run_act_tests():
    """Set up temp repo, run act, and verify all fixtures."""
    print("\n===== ACT INTEGRATION TESTS =====")
    failures = []

    # Set up the temp repo
    log("Setting up temporary git repo...")
    tmp_dir = setup_temp_repo()
    log(f"Temp repo: {tmp_dir}")

    try:
        # Run act
        log("Running act push --rm ...")
        exit_code, output = run_act(tmp_dir)
        log(f"act exit code: {exit_code}")

        # Save output to act-result.txt
        with open(ACT_RESULT_FILE, "w") as f:
            f.write("========== ACT RUN OUTPUT ==========\n")
            f.write(output)
            f.write("\n")

        # Assert act exited with 0
        if exit_code != 0:
            log_fail(f"act exited with code {exit_code}")
            failures.append(f"act exited with code {exit_code}")
            # Print last 40 lines for diagnostics
            lines = output.strip().splitlines()
            log("Last 40 lines of output:")
            for line in lines[-40:]:
                log(f"  {line}")
            return failures

        log_pass("act exited with code 0")

        # Check "Job succeeded" appears
        if "Job succeeded" in output:
            log_pass("'Job succeeded' found in output")
        else:
            log_fail("'Job succeeded' not found in output")
            failures.append("Job succeeded not found")

        # Parse sections from output
        sections = extract_sections(output)
        log(f"Parsed {len(sections)} sections: {list(sections.keys())}")

        # Verify each fixture
        for name, expected in EXPECTED.items():
            print(f"\n  --- Verifying: {name} ---")
            if name not in sections:
                log_fail(f"{name}: section not found in act output")
                failures.append(f"{name}: section missing")
                continue

            section_lines = sections[name]
            if expected["status"] == "success":
                failures.extend(verify_success_fixture(name, section_lines, expected))
            else:
                failures.extend(verify_error_fixture(name, section_lines, expected))

    finally:
        # Clean up temp dir
        shutil.rmtree(tmp_dir, ignore_errors=True)

    return failures


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("=" * 60)
    print("Environment Matrix Generator -- Test Harness")
    print("=" * 60)

    all_failures = []

    # Phase 1: structural tests (no act)
    all_failures.extend(run_structural_tests())

    # Phase 2: act integration tests
    all_failures.extend(run_act_tests())

    # Append test results summary to act-result.txt
    with open(ACT_RESULT_FILE, "a") as f:
        f.write("\n========== TEST RESULTS SUMMARY ==========\n")
        if all_failures:
            f.write(f"FAILURES ({len(all_failures)}):\n")
            for fail in all_failures:
                f.write(f"  - {fail}\n")
        else:
            f.write("ALL TESTS PASSED\n")

    # Final summary
    print("\n" + "=" * 60)
    if all_failures:
        print(f"FAILED: {len(all_failures)} failure(s)")
        for fail in all_failures:
            print(f"  - {fail}")
        sys.exit(1)
    else:
        print("ALL TESTS PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
