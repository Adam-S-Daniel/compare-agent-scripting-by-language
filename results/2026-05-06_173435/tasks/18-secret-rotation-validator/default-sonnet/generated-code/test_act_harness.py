"""
Act integration test harness.

For each test case this harness:
  1. Creates a temporary git repo containing all project files.
  2. Places the case-specific fixture file as secrets-config.json.
  3. Runs: act push --rm
  4. Captures full output and appends it (clearly delimited) to act-result.txt.
  5. Asserts act exited with code 0.
  6. Asserts "Job succeeded" appears in the output.
  7. Asserts EXACT expected values appear in the output (ROTATION-SUMMARY,
     EXPIRED-NAMES, WARNING-NAMES, OK-NAMES markers emitted by the script).

Run with:  pytest test_act_harness.py -v -s
"""

import os
import shutil
import subprocess
import tempfile

import pytest

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")

# Files / directories that must not be copied into the temp repo
_SKIP = {".git", "__pycache__", "act-result.txt", ".pytest_cache"}

# -----------------------------------------------------------------------
# Test cases: fixture file + exact expected marker strings
# -----------------------------------------------------------------------

TEST_CASES = [
    {
        "name": "expired",
        "fixture": "fixtures/expired_case.json",
        # DB_PASSWORD last_rotated 2023-11-01, policy 90d -> expires 2024-01-30
        # reference 2024-03-15 -> -45 days -> EXPIRED
        "expected_summary": "ROTATION-SUMMARY: expired=1 warning=0 ok=0",
        "expected_expired": "EXPIRED-NAMES: DB_PASSWORD",
        "expected_warning": "WARNING-NAMES: none",
        "expected_ok": "OK-NAMES: none",
    },
    {
        "name": "warning",
        "fixture": "fixtures/warning_case.json",
        # API_KEY last_rotated 2024-03-08, policy 14d -> expires 2024-03-22
        # reference 2024-03-15 -> 7 days -> WARNING (window=14)
        "expected_summary": "ROTATION-SUMMARY: expired=0 warning=1 ok=0",
        "expected_expired": "EXPIRED-NAMES: none",
        "expected_warning": "WARNING-NAMES: API_KEY",
        "expected_ok": "OK-NAMES: none",
    },
    {
        "name": "ok",
        "fixture": "fixtures/ok_case.json",
        # STRIPE_KEY last_rotated 2024-03-01, policy 90d -> expires 2024-05-30
        # reference 2024-03-15 -> 76 days -> OK
        "expected_summary": "ROTATION-SUMMARY: expired=0 warning=0 ok=1",
        "expected_expired": "EXPIRED-NAMES: none",
        "expected_warning": "WARNING-NAMES: none",
        "expected_ok": "OK-NAMES: STRIPE_KEY",
    },
    {
        "name": "mixed",
        "fixture": "fixtures/mixed_case.json",
        # DB_PASSWORD=expired, API_KEY=warning, STRIPE_KEY=ok
        "expected_summary": "ROTATION-SUMMARY: expired=1 warning=1 ok=1",
        "expected_expired": "EXPIRED-NAMES: DB_PASSWORD",
        "expected_warning": "WARNING-NAMES: API_KEY",
        "expected_ok": "OK-NAMES: STRIPE_KEY",
    },
]


def _copy_project_to(dest: str, fixture_file: str) -> None:
    """Copy project files into dest, overriding secrets-config.json with fixture."""
    for name in os.listdir(PROJECT_DIR):
        if name in _SKIP:
            continue
        src = os.path.join(PROJECT_DIR, name)
        dst = os.path.join(dest, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    # Override secrets-config.json with this test case's fixture
    shutil.copy2(
        os.path.join(PROJECT_DIR, fixture_file),
        os.path.join(dest, "secrets-config.json"),
    )


def _init_git_repo(repo_dir: str) -> None:
    """Initialise a git repo and create one commit so act can run on push."""
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    for cmd in [
        ["git", "init", "-b", "main"],
        ["git", "config", "user.email", "ci@test.local"],
        ["git", "config", "user.name", "CI Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "chore: test fixture"],
    ]:
        subprocess.run(cmd, cwd=repo_dir, check=True, capture_output=True, env=env)


def _run_act(repo_dir: str) -> tuple[int, str]:
    """Run act push --rm and return (exit_code, combined_output)."""
    result = subprocess.run(
        # --pull=false: use the local image without trying to pull from registry
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return result.returncode, result.stdout + result.stderr


# -----------------------------------------------------------------------
# Single pytest test that runs all act cases and writes act-result.txt
# -----------------------------------------------------------------------

def test_all_act_cases():
    """Run all four test cases through act and assert exact expected output."""
    # Initialise the results file
    with open(ACT_RESULT_FILE, "w") as f:
        f.write("# act-result.txt — Secret Rotation Validator\n\n")

    failures = []

    for case in TEST_CASES:
        print(f"\n{'='*60}")
        print(f"Running act test case: {case['name']}")
        print(f"{'='*60}")

        with tempfile.TemporaryDirectory() as tmpdir:
            _copy_project_to(tmpdir, case["fixture"])
            _init_git_repo(tmpdir)
            returncode, output = _run_act(tmpdir)

        # Append to act-result.txt (required artifact)
        delimiter = f"\n{'='*60}\nTEST CASE: {case['name']}\n{'='*60}\n"
        with open(ACT_RESULT_FILE, "a") as f:
            f.write(delimiter)
            f.write(output)
            f.write("\n")

        print(output[-3000:])  # show tail for -s mode

        # Collect failures rather than raising immediately so all cases run
        case_failures = []

        if returncode != 0:
            case_failures.append(
                f"[{case['name']}] act exited {returncode} (expected 0)"
            )

        if "Job succeeded" not in output:
            case_failures.append(
                f"[{case['name']}] 'Job succeeded' not found in act output"
            )

        for marker_key in (
            "expected_summary",
            "expected_expired",
            "expected_warning",
            "expected_ok",
        ):
            marker = case[marker_key]
            if marker not in output:
                case_failures.append(
                    f"[{case['name']}] Expected marker not found: {marker!r}"
                )

        failures.extend(case_failures)

    assert not failures, "\n".join(failures)
