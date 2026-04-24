"""
Act-based integration test harness.

For every fixture case in `fixtures/`:
  1. Create a fresh temp git repo
  2. Copy the project files (aggregator.py, .github/, conftest.py, ...)
  3. Copy the case's fixture files into `./test-results/` inside that repo
  4. Run `act push --rm` and capture stdout+stderr
  5. Append the captured output to `act-result.txt` with a clear delimiter
  6. Assert act exit code == 0, assert "Job succeeded" appears
  7. Assert the aggregator's Markdown output contains the EXACT expected
     totals for that case (e.g. `| Total | 9 |`, `| Passed | 7 |`, ...)

This harness is limited to 3 act runs — one per fixture case — per the
benchmark guardrails.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path


ROOT = Path(__file__).resolve().parent
ACT_RESULT_FILE = ROOT / "act-result.txt"


# ---------------------------------------------------------------------------
# Expected values
# ---------------------------------------------------------------------------
#
# For each fixture case, we pre-compute the totals we expect the aggregator
# to emit. These become exact string assertions against the act output.
CASES: list[dict] = [
    {
        "name": "case-clean",
        "fixture_dir": ROOT / "fixtures" / "case-clean",
        "expected": {
            # All rows from the rendered Markdown totals table
            "total": 4,
            "passed": 4,
            "failed": 0,
            "skipped": 0,
            "has_flaky": False,
            # Specific substrings that must appear in act output
            "must_contain": [
                "| Total | 4 |",
                "| Passed | 4 |",
                "| Failed | 0 |",
                "| Skipped | 0 |",
                "_No flaky tests detected._",
            ],
            "must_not_contain": [
                "## Failures",
            ],
        },
    },
    {
        "name": "case-flaky",
        "fixture_dir": ROOT / "fixtures" / "case-flaky",
        "expected": {
            # 3 shards x 3 tests each = 9 cases
            # Shard 1: all pass. Shard 2: 1 fail (test_network_call).
            # Shard 3: 2 pass, 1 skipped.
            "total": 9,
            "passed": 7,
            "failed": 1,
            "skipped": 1,
            "has_flaky": True,
            "must_contain": [
                "| Total | 9 |",
                "| Passed | 7 |",
                "| Failed | 1 |",
                "| Skipped | 1 |",
                "## Flaky Tests",
                # The flaky test's fully qualified name + its pass/fail counts
                "| pkg.Alpha::test_network_call | 2 | 1 |",
                # Its failure should be listed in the Failures section
                "## Failures",
                "connection timed out",
            ],
            "must_not_contain": [
                "_No flaky tests detected._",
            ],
        },
    },
    {
        "name": "case-consistent-fail",
        "fixture_dir": ROOT / "fixtures" / "case-consistent-fail",
        "expected": {
            # 2 shards x 2 tests each = 4 cases, one deterministic failure
            "total": 4,
            "passed": 2,
            "failed": 2,
            "skipped": 0,
            "has_flaky": False,
            "must_contain": [
                "| Total | 4 |",
                "| Passed | 2 |",
                "| Failed | 2 |",
                "| Skipped | 0 |",
                "## Failures",
                "_No flaky tests detected._",
                "assertion failed",
            ],
            "must_not_contain": [],
        },
    },
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    """Run a command, return the CompletedProcess with captured output."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def _prepare_repo(case: dict, tmp: Path) -> Path:
    """Create a temp git repo seeded with project files + case fixtures."""
    repo = tmp / case["name"]
    repo.mkdir(parents=True, exist_ok=True)

    # Copy project files (not fixtures — each case gets its own)
    for rel in ("aggregator.py", "conftest.py", ".actrc"):
        src = ROOT / rel
        if src.exists():
            shutil.copy(src, repo / rel)

    # Copy the workflow directory
    shutil.copytree(ROOT / ".github", repo / ".github")

    # Copy this case's fixtures into ./test-results/
    dst = repo / "test-results"
    dst.mkdir()
    for f in sorted(case["fixture_dir"].iterdir()):
        shutil.copy(f, dst / f.name)

    # Initialize git (act requires this to pick up ref info)
    env = os.environ.copy()
    env.setdefault("GIT_AUTHOR_NAME", "act-test")
    env.setdefault("GIT_AUTHOR_EMAIL", "act@test.local")
    env.setdefault("GIT_COMMITTER_NAME", "act-test")
    env.setdefault("GIT_COMMITTER_EMAIL", "act@test.local")
    for cmd in (
        ["git", "init", "-q", "-b", "main"],
        ["git", "add", "-A"],
        ["git", "-c", "user.name=act-test", "-c", "user.email=act@test.local",
         "commit", "-q", "-m", f"fixture: {case['name']}"],
    ):
        r = subprocess.run(cmd, cwd=repo, env=env, capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(
                f"{' '.join(cmd)} failed in {repo}:\n{r.stdout}\n{r.stderr}"
            )

    return repo


def _append_result(label: str, proc: subprocess.CompletedProcess[str]) -> None:
    """Append stdout+stderr for a case to act-result.txt with a banner."""
    banner = "=" * 80
    chunk = textwrap.dedent(f"""
    {banner}
    CASE: {label}
    EXIT: {proc.returncode}
    {banner}
    --- STDOUT ---
    """).lstrip()
    with open(ACT_RESULT_FILE, "a") as fh:
        fh.write(chunk)
        fh.write(proc.stdout or "")
        fh.write("\n--- STDERR ---\n")
        fh.write(proc.stderr or "")
        fh.write(f"\n--- END {label} ---\n")


def _assert_contains(haystack: str, needle: str, case: str) -> None:
    if needle not in haystack:
        print(
            f"[FAIL] case={case}: expected substring not found: {needle!r}",
            file=sys.stderr,
        )
        sys.exit(1)


def _assert_not_contains(haystack: str, needle: str, case: str) -> None:
    if needle in haystack:
        print(
            f"[FAIL] case={case}: forbidden substring found: {needle!r}",
            file=sys.stderr,
        )
        sys.exit(1)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    if shutil.which("act") is None:
        print("error: act not installed", file=sys.stderr)
        return 2

    # Fresh result file for this run
    if ACT_RESULT_FILE.exists():
        ACT_RESULT_FILE.unlink()

    workbench = ROOT / ".act-workbench"
    if workbench.exists():
        shutil.rmtree(workbench)
    workbench.mkdir()

    all_ok = True
    for case in CASES:
        print(f"\n>>> Running case: {case['name']}", flush=True)
        repo = _prepare_repo(case, workbench)
        # --rm: remove the container after; --quiet to reduce noise isn't used
        # because we want the workflow step logs in the output.
        proc = _run(["act", "push", "--rm"], cwd=repo)
        _append_result(case["name"], proc)
        out = (proc.stdout or "") + "\n" + (proc.stderr or "")

        # Hard requirements: act exit 0 + every job succeeded
        if proc.returncode != 0:
            print(f"[FAIL] act exit code was {proc.returncode} for {case['name']}",
                  file=sys.stderr)
            all_ok = False
            continue
        if "Job succeeded" not in out:
            print(f"[FAIL] 'Job succeeded' missing for {case['name']}", file=sys.stderr)
            all_ok = False
            continue

        # Exact-value assertions from the pre-computed expectations
        for needle in case["expected"]["must_contain"]:
            try:
                _assert_contains(out, needle, case["name"])
            except SystemExit:
                all_ok = False
        for needle in case["expected"]["must_not_contain"]:
            try:
                _assert_not_contains(out, needle, case["name"])
            except SystemExit:
                all_ok = False

        if all_ok:
            print(f"[OK] {case['name']}")

    print("\n" + ("ALL PASSED" if all_ok else "FAILURES"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
