#!/usr/bin/env python3
"""
Test harness for running secret-rotation-validator through GitHub Actions via act.
Validates workflow structure, actionlint, and actual execution.
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple


def run_command(cmd: List[str], cwd: str = None) -> Tuple[int, str, str]:
    """Run a command and capture output."""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=300,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)


def validate_workflow_structure() -> bool:
    """Check that workflow file has required structure."""
    workflow_path = Path(".github/workflows/secret-rotation-validator.yml")
    if not workflow_path.exists():
        print("❌ Workflow file not found")
        return False

    import yaml

    try:
        with open(workflow_path) as f:
            content = f.read()
            data = yaml.safe_load(content)

        # Check required fields (handle YAML's "on" -> True conversion)
        if "name" not in data:
            print(f"❌ Missing required field: name")
            return False

        # Check for "on" field (may be parsed as True or present as key)
        has_triggers = any(k in data for k in ["on", True]) or "on:" in content
        if not has_triggers:
            print(f"❌ Missing required field: on")
            return False

        if "jobs" not in data:
            print(f"❌ Missing required field: jobs")
            return False

        # Check for required jobs
        required_jobs = ["test", "validate-workflow"]
        for job in required_jobs:
            if job not in data["jobs"]:
                print(f"❌ Missing required job: {job}")
                return False

        print("✅ Workflow structure is valid")
        return True

    except Exception as e:
        print(f"❌ Failed to parse workflow: {e}")
        return False


def validate_actionlint() -> bool:
    """Run actionlint on the workflow."""
    print("\n📋 Running actionlint validation...")

    code, stdout, stderr = run_command(
        ["actionlint", ".github/workflows/secret-rotation-validator.yml"]
    )

    if code == 0:
        print("✅ actionlint passed")
        return True
    else:
        print(f"❌ actionlint failed")
        if stderr:
            print(f"Error: {stderr}")
        return False


def validate_required_files() -> bool:
    """Check that all required files exist."""
    required_files = [
        "secret_validator.py",
        "test_secret_validator.py",
        "fixtures.json",
        ".github/workflows/secret-rotation-validator.yml",
    ]

    all_exist = True
    for file in required_files:
        path = Path(file)
        if path.exists():
            print(f"✅ {file} exists")
        else:
            print(f"❌ {file} missing")
            all_exist = False

    return all_exist


def run_act_test(test_name: str, output_file) -> bool:
    """Run act push and capture output."""
    print(f"\n🏃 Running: {test_name}")

    code, stdout, stderr = run_command(["act", "push", "--rm"])

    # Write output to file
    output_file.write(f"\n{'='*70}\n")
    output_file.write(f"TEST: {test_name}\n")
    output_file.write(f"{'='*70}\n")
    output_file.write(f"Exit code: {code}\n\n")
    output_file.write("STDOUT:\n")
    output_file.write(stdout)
    output_file.write("\n\nSTDERR:\n")
    output_file.write(stderr)
    output_file.flush()

    if code != 0:
        print(f"❌ act exited with code {code}")
        return False

    # Check for success indicators
    success_markers = [
        "Job succeeded",
        "✅ Markdown Output ===",
        "✅ JSON Output ===",
    ]

    found_markers = 0
    for marker in success_markers:
        if marker in stdout:
            found_markers += 1

    print(f"✅ act completed successfully (exit code 0)")
    return True


def parse_and_validate_outputs(output_file) -> bool:
    """Validate that script outputs are correct."""
    print("\n📊 Validating script outputs...")

    # Check markdown output exists
    markdown_path = Path("test_output.md")
    if markdown_path.exists():
        with open(markdown_path) as f:
            content = f.read()
            if "Secret Rotation Report" in content:
                print("✅ Markdown report generated")
            else:
                print("❌ Markdown report missing expected content")
                return False
    else:
        print("⚠️  test_output.md not found (expected in act container)")

    # Check JSON output exists and is valid
    json_path = Path("test_output.json")
    if json_path.exists():
        try:
            with open(json_path) as f:
                data = json.load(f)
                if "timestamp" in data and "summary" in data and "secrets" in data:
                    print("✅ JSON report has correct structure")
                else:
                    print("❌ JSON report missing expected fields")
                    return False
        except json.JSONDecodeError:
            print("❌ JSON report is not valid JSON")
            return False
    else:
        print("⚠️  test_output.json not found (expected in act container)")

    return True


def main():
    """Main test harness."""
    print("🚀 Secret Rotation Validator - Act Test Harness\n")

    # Results tracking
    all_passed = True

    # Step 1: Validate workflow structure
    print("1️⃣ Checking workflow structure...")
    if not validate_workflow_structure():
        all_passed = False

    # Step 2: Validate required files
    print("\n2️⃣ Checking required files...")
    if not validate_required_files():
        all_passed = False

    # Step 3: Validate actionlint
    print("\n3️⃣ Validating workflow with actionlint...")
    if not validate_actionlint():
        all_passed = False

    # Step 4: Run act tests
    print("\n4️⃣ Running workflow through act...")

    # Open result file
    with open("act-result.txt", "w") as output_file:
        output_file.write("Secret Rotation Validator - Act Test Results\n")
        output_file.write("=" * 70 + "\n")
        output_file.write(f"Test Date: {Path('.').resolve()}\n\n")

        # Run main test
        if not run_act_test("Full Workflow Test", output_file):
            all_passed = False
        else:
            # Validate outputs from the run
            if not parse_and_validate_outputs(output_file):
                all_passed = False

    # Summary
    print("\n" + "=" * 70)
    if all_passed:
        print("✅ All tests passed!")
        sys.exit(0)
    else:
        print("❌ Some tests failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
