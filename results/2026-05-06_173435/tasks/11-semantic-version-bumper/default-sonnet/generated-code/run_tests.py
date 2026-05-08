#!/usr/bin/env python3
"""
Act test harness for semantic-version-bumper.

Sets up a temp git repo with all project files, runs 'act push --rm'
once (all test cases are embedded in the workflow), captures the output,
asserts exact expected values, and writes act-result.txt.

Expected version outputs per test case (defined in the workflow):
  TC1: 1.0.0 + fix commits    -> 1.0.1 (patch)
  TC2: 1.0.0 + feat + fix     -> 1.1.0 (minor)
  TC3: 1.0.0 + feat!          -> 2.0.0 (major via !)
  TC4: 2.3.4 + feat + fix     -> 2.4.0 (minor, non-trivial base)
  TC5: 1.5.2 + chore/docs     -> 1.5.2 (no bump)
  TC6: 3.0.0 + BREAKING CHANGE-> 4.0.0 (major via keyword)
"""
import subprocess
import tempfile
import shutil
import sys
import re
from pathlib import Path

WORKSPACE_DIR = Path(__file__).parent

# Expected outputs defined here — must match workflow step assertions exactly
EXPECTED_VERSIONS = {
    "TC1": "1.0.1",
    "TC2": "1.1.0",
    "TC3": "2.0.0",
    "TC4": "2.4.0",
    "TC5": "1.5.2",
    "TC6": "4.0.0",
}


def build_temp_repo() -> str:
    """
    Create a temp directory, copy all project files, and init a git repo.
    The workflow embeds all test cases, so no per-case VERSION/commits.txt needed.
    """
    temp_dir = tempfile.mkdtemp(prefix="semver-act-")

    # Copy project files (skip .git, cache dirs, and previous run artifacts)
    skip = {".git", "__pycache__", ".claude", "act-result.txt", ".pytest_cache"}
    for item in WORKSPACE_DIR.iterdir():
        if item.name in skip:
            continue
        dest = Path(temp_dir) / item.name
        if item.is_dir():
            shutil.copytree(item, dest, ignore=shutil.ignore_patterns("__pycache__"))
        else:
            shutil.copy2(item, dest)

    # Copy .actrc so act uses the correct Docker image
    actrc = WORKSPACE_DIR / ".actrc"
    if actrc.exists():
        shutil.copy2(actrc, Path(temp_dir) / ".actrc")

    # Init git repo required by act
    for cmd in [
        ["git", "init", "-b", "main"],
        ["git", "config", "user.email", "test@semver.local"],
        ["git", "config", "user.name", "Semver Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test: initial commit for act run"],
    ]:
        subprocess.run(cmd, cwd=temp_dir, check=True, capture_output=True)

    return temp_dir


def run_act(temp_dir: str) -> subprocess.CompletedProcess:
    """Run 'act push --rm' in the temp repo and return the result."""
    return subprocess.run(
        ["act", "push", "--rm", "-P", "ubuntu-latest=act-ubuntu-pwsh:latest", "--pull=false"],
        cwd=temp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )


def parse_tc_version(output: str, tc: str) -> str | None:
    """Extract TCN_NEW_VERSION: X.Y.Z from act output."""
    match = re.search(rf"{tc}_NEW_VERSION:\s*(\d+\.\d+\.\d+)", output)
    return match.group(1) if match else None


def main() -> int:
    act_result_file = WORKSPACE_DIR / "act-result.txt"
    all_passed = True

    print("=" * 60)
    print("Semantic Version Bumper — Act Test Run")
    print("=" * 60)
    print(f"\nBuilding temp git repo from: {WORKSPACE_DIR}")

    temp_dir = build_temp_repo()
    print(f"Temp repo: {temp_dir}")

    try:
        print("\nRunning: act push --rm  (this may take 30-90s) ...")
        result = run_act(temp_dir)
        combined = result.stdout + result.stderr
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

    # Write full output to act-result.txt
    with open(act_result_file, "w") as f:
        f.write("# Semantic Version Bumper — Act Test Results\n")
        f.write(f"# Exit code: {result.returncode}\n\n")
        f.write("=" * 60 + "\n")
        f.write("ACT OUTPUT\n")
        f.write("=" * 60 + "\n")
        f.write(combined)
        f.write("\n" + "=" * 60 + "\n")
        f.write("ASSERTIONS\n")
        f.write("=" * 60 + "\n")

    # ---- Assert exit code 0 ----
    if result.returncode != 0:
        msg = f"FAIL: act exited with code {result.returncode}"
        print(msg)
        with open(act_result_file, "a") as f:
            f.write(f"{msg}\n")
            f.write("STDOUT:\n" + result.stdout[-3000:] + "\n")
            f.write("STDERR:\n" + result.stderr[-3000:] + "\n")
        all_passed = False
    else:
        print("PASS: act exited with code 0")

    # ---- Assert 'Job succeeded' ----
    if "Job succeeded" in combined:
        msg = "PASS: 'Job succeeded' found in output"
    else:
        msg = "FAIL: 'Job succeeded' not found in output"
        all_passed = False
    print(msg)
    with open(act_result_file, "a") as f:
        f.write(msg + "\n")

    # ---- Assert exact expected versions ----
    for tc, expected in EXPECTED_VERSIONS.items():
        actual = parse_tc_version(combined, tc)
        if actual == expected:
            msg = f"PASS {tc}: expected {expected}, got {actual}"
        else:
            msg = f"FAIL {tc}: expected {expected}, got {actual!r}"
            all_passed = False
        print(msg)
        with open(act_result_file, "a") as f:
            f.write(msg + "\n")

    # ---- Final summary ----
    print("\n" + "=" * 60)
    if all_passed:
        print("ALL ASSERTIONS PASSED")
        with open(act_result_file, "a") as f:
            f.write("\nALL ASSERTIONS PASSED\n")
    else:
        print("SOME ASSERTIONS FAILED — see act-result.txt for details")
        with open(act_result_file, "a") as f:
            f.write("\nSOME ASSERTIONS FAILED\n")

    print(f"\nFull act output saved to: {act_result_file}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
