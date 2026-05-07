#!/usr/bin/env python3
"""Test harness for PR Label Assigner - all tests run through act."""

import json
import os
import subprocess
import sys
import tempfile
import shutil
import yaml

WORK_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(WORK_DIR, "act-result.txt")

EXPECTED_LABELS = {
    "case1_docs_only": ["documentation"],
    "case2_mixed_changes": ["api", "documentation", "source", "tests"],
    "case3_test_files": ["api", "source", "tests"],
    "case4_frontend": ["api", "frontend", "source"],
    "case5_ci_changes": ["ci-cd"],
}

EXPECTED_FILE_ASSIGNMENTS = {
    "case1_docs_only": {
        "docs/readme.md": ["documentation", "documentation"],
        "docs/api/endpoints.md": ["documentation", "documentation"],
    },
    "case2_mixed_changes": {
        "src/api/routes.py": ["api", "source"],
        "src/api/models.py": ["api", "source"],
        "tests/test_routes.py": ["tests"],
        "docs/changelog.md": ["documentation", "documentation"],
    },
    "case3_test_files": {
        "src/utils.test.js": ["tests", "source"],
        "src/api/handler.test.ts": ["tests", "api", "source"],
        "tests/integration/test_auth.py": ["tests"],
    },
    "case4_frontend": {
        "src/ui/components/Button.tsx": ["frontend", "source"],
        "src/ui/styles/main.css": ["frontend", "frontend", "source"],
        "src/api/auth.py": ["api", "source"],
    },
    "case5_ci_changes": {
        ".github/workflows/ci.yml": ["ci-cd", "ci-cd"],
        ".github/workflows/deploy.yml": ["ci-cd", "ci-cd"],
    },
}


def run_workflow_structure_tests():
    """Test workflow YAML structure without running act."""
    print("=" * 60)
    print("WORKFLOW STRUCTURE TESTS")
    print("=" * 60)
    failures = []

    workflow_path = os.path.join(WORK_DIR, ".github/workflows/pr-label-assigner.yml")

    # Test 1: YAML is valid and has expected structure
    print("\n[TEST] Workflow YAML structure...")
    with open(workflow_path) as f:
        wf = yaml.safe_load(f)

    # PyYAML parses 'on' as boolean True key
    triggers = wf.get("on") or wf.get(True)
    assert triggers is not None, "Missing 'on' trigger"
    assert "push" in triggers, "Missing push trigger"
    assert "pull_request" in triggers, "Missing pull_request trigger"
    assert "workflow_dispatch" in triggers, "Missing workflow_dispatch trigger"
    assert "jobs" in wf, "Missing jobs"
    assert "assign-labels" in wf["jobs"], "Missing assign-labels job"
    print("  PASS: Triggers and jobs present")

    # Test 2: Job references the script correctly
    print("\n[TEST] Script file references...")
    job = wf["jobs"]["assign-labels"]
    steps_yaml = yaml.dump(job["steps"])
    assert "pr_label_assigner.py" in steps_yaml, "Workflow doesn't reference pr_label_assigner.py"
    assert "label_rules.json" in steps_yaml, "Workflow doesn't reference label_rules.json"

    assert os.path.exists(os.path.join(WORK_DIR, "pr_label_assigner.py")), "pr_label_assigner.py missing"
    assert os.path.exists(os.path.join(WORK_DIR, "label_rules.json")), "label_rules.json missing"
    print("  PASS: Script files exist and are referenced")

    # Test 3: Matrix includes all test fixtures
    print("\n[TEST] Matrix covers all fixtures...")
    matrix_fixtures = job["strategy"]["matrix"]["fixture"]
    for case in EXPECTED_LABELS:
        assert case in matrix_fixtures, f"Missing fixture {case} in matrix"
    print(f"  PASS: All {len(EXPECTED_LABELS)} fixtures in matrix")

    # Test 4: actionlint passes
    print("\n[TEST] actionlint validation...")
    result = subprocess.run(
        ["actionlint", workflow_path],
        capture_output=True, text=True
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    print("  PASS: actionlint clean")

    print("\n" + "=" * 60)
    print("ALL WORKFLOW STRUCTURE TESTS PASSED")
    print("=" * 60)


def run_act_tests():
    """Run all test cases through act and verify output."""
    print("\n" + "=" * 60)
    print("ACT INTEGRATION TESTS")
    print("=" * 60)

    # Clear previous results
    with open(ACT_RESULT_FILE, "w") as f:
        f.write("")

    tmp_dir = tempfile.mkdtemp(prefix="pr-label-assigner-test-")
    print(f"Temp repo: {tmp_dir}")

    try:
        # Set up a temp git repo with all project files
        subprocess.run(["git", "init", tmp_dir], capture_output=True, check=True)
        subprocess.run(
            ["git", "-C", tmp_dir, "config", "user.email", "test@test.com"],
            capture_output=True, check=True,
        )
        subprocess.run(
            ["git", "-C", tmp_dir, "config", "user.name", "Test"],
            capture_output=True, check=True,
        )

        # Copy project files (skip .actrc to avoid forcePull issues)
        for item in ["pr_label_assigner.py", "label_rules.json", ".github", "test_fixtures"]:
            src = os.path.join(WORK_DIR, item)
            dst = os.path.join(tmp_dir, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        subprocess.run(
            ["git", "-C", tmp_dir, "add", "-A"],
            capture_output=True, check=True,
        )
        subprocess.run(
            ["git", "-C", tmp_dir, "commit", "-m", "initial"],
            capture_output=True, check=True,
        )

        # Run act with local image (no pull)
        print("\nRunning act push --rm ...")
        result = subprocess.run(
            ["act", "push", "--rm", "-P", "ubuntu-latest=act-ubuntu-pwsh:latest", "--pull=false"],
            cwd=tmp_dir,
            capture_output=True,
            text=True,
            timeout=180,
        )

        act_output = result.stdout + "\n" + result.stderr
        with open(ACT_RESULT_FILE, "w") as f:
            f.write("=== ACT RUN OUTPUT ===\n")
            f.write(f"Exit code: {result.returncode}\n")
            f.write(f"Working dir: {tmp_dir}\n\n")
            f.write(act_output)

        print(f"Act exit code: {result.returncode}")

        # Assert act succeeded
        if result.returncode != 0:
            print("ACT FAILED! Output:")
            print(act_output[-3000:])
            sys.exit(1)

        # Assert all jobs succeeded
        print("\n[TEST] Verifying all jobs succeeded...")
        success_count = act_output.count("Job succeeded")
        assert success_count >= len(EXPECTED_LABELS), (
            f"Expected at least {len(EXPECTED_LABELS)} successful jobs, got {success_count}"
        )
        print(f"  PASS: {success_count} jobs succeeded")

        # Parse and verify each test case output
        print("\n[TEST] Verifying label assignments...")
        for case_name, expected_labels in EXPECTED_LABELS.items():
            print(f"\n  Checking {case_name}...")

            marker_start = f"=== Test Case: {case_name} ==="
            marker_end = f"=== End Case: {case_name} ==="

            # Find which job prefix contains this case
            start_idx = act_output.find(marker_start)
            assert start_idx != -1, f"Missing output marker for {case_name}"

            # Get the job prefix from the line containing the marker
            line_start = act_output.rfind("\n", 0, start_idx) + 1
            marker_line = act_output[line_start:act_output.find("\n", start_idx)]
            # Extract prefix like "[PR Label Assigner/assign-labels-1]"
            job_prefix = marker_line[:marker_line.index("]") + 1]

            # Collect all lines from this specific job between markers
            lines = act_output.split("\n")
            in_section = False
            content_lines = []
            for line in lines:
                if not line.startswith(job_prefix):
                    continue
                # Strip job prefix and "  | " separator
                after_prefix = line[len(job_prefix):]
                if "| " in after_prefix:
                    content = after_prefix[after_prefix.index("| ") + 2:]
                else:
                    continue

                if marker_start in content:
                    in_section = True
                    continue
                if marker_end in content:
                    break
                if in_section:
                    content_lines.append(content)

            json_str = "\n".join(content_lines)
            assert json_str.strip(), f"No JSON output found for {case_name}"

            result_data = json.loads(json_str)
            actual_labels = result_data["labels"]

            assert actual_labels == expected_labels, (
                f"Labels mismatch for {case_name}:\n"
                f"  Expected: {expected_labels}\n"
                f"  Got:      {actual_labels}"
            )
            print(f"    PASS: labels = {actual_labels}")

        print("\n" + "=" * 60)
        print("ALL ACT INTEGRATION TESTS PASSED")
        print("=" * 60)

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def main():
    run_workflow_structure_tests()
    run_act_tests()
    print(f"\nResults saved to: {ACT_RESULT_FILE}")
    print("\nALL TESTS PASSED")


if __name__ == "__main__":
    main()
