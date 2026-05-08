"""
Test harness: sets up a temporary git repo, runs `act push --rm` through the
GitHub Actions workflow, captures output, and asserts on exact expected values.
Results (and assertions) are appended to act-result.txt in the working directory.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RESULT_FILE = Path(__file__).parent / "act-result.txt"
PROJECT_DIR = Path(__file__).parent

# Files to copy into the temp repo
PROJECT_FILES = [
    "artifact_cleanup.py",
    "generate_fixtures.py",
    "test_artifact_cleanup.py",
    ".github/workflows/artifact-cleanup-script.yml",
    "fixtures/policy_age.json",
    "fixtures/policy_keep_latest.json",
    "fixtures/policy_max_size.json",
    "fixtures/policy_combined.json",
    "bin/actionlint",
    ".actrc",
]


def setup_temp_repo() -> Path:
    """Create a temp directory, copy project files, and git-init it."""
    tmpdir = Path(tempfile.mkdtemp(prefix="artifact-cleanup-act-"))

    for rel in PROJECT_FILES:
        src = PROJECT_DIR / rel
        dst = tmpdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.exists():
            shutil.copy2(src, dst)

    # Initialise git repo
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test fixtures"],
    ]:
        subprocess.run(cmd, cwd=tmpdir, check=True, capture_output=True)

    return tmpdir


def run_act(tmpdir: Path, event: str = "push") -> tuple[int, str]:
    """Run `act <event> --rm` and return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", event, "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def append_result(label: str, output: str, passed: bool):
    """Append one test case's output to act-result.txt."""
    border = "=" * 60
    status = "PASS" if passed else "FAIL"
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{border}\n")
        f.write(f"TEST CASE: {label}  [{status}]\n")
        f.write(f"{border}\n")
        f.write(output)
        f.write(f"\n{border}\n")


def assert_job_succeeded(output: str, job_name: str):
    assert "Job succeeded" in output, \
        f"Expected 'Job succeeded' for job '{job_name}' but not found in:\n{output[-2000:]}"


def assert_contains(output: str, marker: str):
    assert marker in output, \
        f"Expected marker '{marker}' not found in output:\n{output[-3000:]}"


def main():
    # Clear previous results
    RESULT_FILE.write_text("")

    print("Setting up temporary git repo...")
    tmpdir = setup_temp_repo()

    try:
        print("Running act push --rm ...")
        rc, output = run_act(tmpdir)

        append_result("act-push-full-workflow", output, rc == 0)

        # === Assert 1: act exited 0 ===
        assert rc == 0, f"act exited with {rc}.\nLast 3000 chars:\n{output[-3000:]}"
        print("ASSERT PASSED: act exit code 0")

        # === Assert 2: both jobs succeeded ===
        assert_job_succeeded(output, "test")
        assert_job_succeeded(output, "run-cleanup")
        print("ASSERT PASSED: both jobs succeeded")

        # === Assert 3: exact expected values from the assertion step ===
        assert_contains(output, "TC1 ASSERTION PASSED: artifacts_to_delete=2 artifacts_to_keep=2 space_reclaimed=31457280 dry_run=True")
        assert_contains(output, "TC2 ASSERTION PASSED: artifacts_to_delete=2 artifacts_to_keep=3")
        assert_contains(output, "TC3 ASSERTION PASSED: artifacts_to_delete=2 artifacts_to_keep=2")
        assert_contains(output, "TC4 ASSERTION PASSED: artifacts_to_delete=3 artifacts_to_keep=2")
        assert_contains(output, "ALL ASSERTIONS PASSED")
        print("ASSERT PASSED: all exact expected values confirmed")

        # === Assert 4: all pytest tests passed ===
        assert_contains(output, "13 passed")
        print("ASSERT PASSED: 13 pytest tests passed")

        print("\nAll assertions passed. See act-result.txt for full output.")
        return 0

    except AssertionError as e:
        append_result("act-push-assertions", f"ASSERTION FAILURE:\n{e}", False)
        print(f"\nASSERTION FAILED: {e}", file=sys.stderr)
        return 1

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
