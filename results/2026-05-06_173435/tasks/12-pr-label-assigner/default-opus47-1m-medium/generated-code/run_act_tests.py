#!/usr/bin/env python3
"""Test harness that drives the workflow through `act` for each test case.

For each case we:
  1. copy project files + the case's fixture into a temp git repo
  2. run `act push --rm`
  3. append the output to act-result.txt
  4. assert exit 0, that "Job succeeded" appears for every job, and that the
     workflow's label output exactly matches the case's expected list.

Limited to 3 act runs total, per harness constraints.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ACT_RESULT = ROOT / "act-result.txt"

# Project files to copy into each per-case temp repo.
PROJECT_FILES = [
    "label_assigner.py",
    "test_label_assigner.py",
    "rules.json",
    ".github/workflows/pr-label-assigner.yml",
]

# Each case: changed files (fixture) + the exact label list we expect.
# Expected output ordering matches assign_labels: priority desc, then alpha.
CASES = [
    {
        "name": "docs_only",
        "files": ["docs/intro.md", "docs/api/reference.md"],
        "expected": ["documentation"],
    },
    {
        "name": "api_with_tests",
        "files": ["src/api/users.py", "src/api/users.test.js"],
        # api priority 5, tests priority 3 -> api first
        "expected": ["api", "tests"],
    },
    {
        "name": "ci_and_api",
        "files": [".github/workflows/deploy.yml", "src/api/handler.py"],
        # api(5) > ci(4)
        "expected": ["api", "ci"],
    },
]


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def setup_repo(tmpdir: Path, fixture_files: list[str]) -> None:
    """Build a self-contained git repo with project files + fixture."""
    for rel in PROJECT_FILES:
        src = ROOT / rel
        dst = tmpdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    fixture_dir = tmpdir / "test-fixture"
    fixture_dir.mkdir(parents=True, exist_ok=True)
    (fixture_dir / "files.json").write_text(json.dumps(fixture_files))

    # act needs a git repo to know about the push event.
    run(["git", "init", "-q", "-b", "main"], cwd=tmpdir)
    run(["git", "config", "user.email", "t@t"], cwd=tmpdir)
    run(["git", "config", "user.name", "t"], cwd=tmpdir)
    run(["git", "add", "-A"], cwd=tmpdir)
    run(["git", "commit", "-q", "-m", "test"], cwd=tmpdir)


def run_act(tmpdir: Path) -> subprocess.CompletedProcess:
    return run(
        ["act", "push", "--rm",
         "-W", ".github/workflows/pr-label-assigner.yml",
         "--container-architecture", "linux/amd64"],
        cwd=tmpdir,
    )


def parse_labels(stdout: str) -> list[str] | None:
    """Pull the LABELS=... line printed by the assign-labels job."""
    m = re.search(r"LABELS=(\[.*?\])", stdout)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return None


def main() -> int:
    ACT_RESULT.write_text("")  # truncate
    overall_ok = True

    for case in CASES:
        print(f"\n=== Running case: {case['name']} ===")
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            setup_repo(tmp, case["files"])
            proc = run_act(tmp)

        delim = f"\n========== CASE: {case['name']} (exit={proc.returncode}) ==========\n"
        with ACT_RESULT.open("a") as f:
            f.write(delim)
            f.write("--- stdout ---\n")
            f.write(proc.stdout)
            f.write("\n--- stderr ---\n")
            f.write(proc.stderr)
            f.write("\n")

        ok = True
        if proc.returncode != 0:
            print(f"  FAIL: act exited {proc.returncode}")
            ok = False

        # Each job prints "Job succeeded" on success.
        succeeded = proc.stdout.count("Job succeeded")
        if succeeded < 2:
            print(f"  FAIL: expected 2 'Job succeeded' lines, saw {succeeded}")
            ok = False

        labels = parse_labels(proc.stdout)
        if labels != case["expected"]:
            print(f"  FAIL: labels mismatch. got={labels} expected={case['expected']}")
            ok = False
        else:
            print(f"  OK: labels={labels}")

        overall_ok = overall_ok and ok

    print("\n=== Summary ===")
    print("ALL PASS" if overall_ok else "FAILURES")
    print(f"act output saved to {ACT_RESULT}")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    sys.exit(main())
