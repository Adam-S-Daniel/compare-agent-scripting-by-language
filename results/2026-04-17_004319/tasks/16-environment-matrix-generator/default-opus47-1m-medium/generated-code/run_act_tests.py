"""End-to-end test harness: runs every fixture through `act` and asserts
exact expected values in the captured workflow output.

Produces ``act-result.txt`` (appended per case, clearly delimited).

Design note: act's `workflow_dispatch` inputs are awkward to set from the CLI,
so each case stages the chosen fixture as ``fixtures/basic.json`` in a scratch
git repo (the workflow's default), runs ``act push --rm``, and inspects the
combined log.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

ROOT = Path(__file__).parent.resolve()
RESULT_FILE = ROOT / "act-result.txt"
PROJECT_FILES = [
    "matrix_generator.py",
    "test_matrix_generator.py",
    ".github/workflows/environment-matrix-generator.yml",
    ".actrc",
]
FIXTURE_DIR = ROOT / "fixtures"

# Each case: fixture file -> expected values that must appear in act log.
CASES = {
    "basic.json": {
        "combo_count": 4,
        "fail_fast": "true",
        # No max-parallel expected.
        "max_parallel": None,
        # A selection of literal substrings that must appear in the printed JSON.
        "matrix_contains": [
            '"fail-fast": true',
            '"ubuntu-latest"',
            '"windows-latest"',
            '"3.11"',
            '"3.12"',
        ],
    },
    "exclude_include.json": {
        "combo_count": 4,  # 4 base - 1 exclude + 1 include
        "fail_fast": "false",
        "max_parallel": 2,
        "matrix_contains": [
            '"max-parallel": 2',
            '"fail-fast": false',
            '"exclude"',
            '"include"',
            '"experimental": true',
            '"macos-latest"',
        ],
    },
    "features.json": {
        "combo_count": 4,  # 1 os * 2 node * 2 features
        "fail_fast": "true",
        "max_parallel": 3,
        "matrix_contains": [
            '"max-parallel": 3',
            '"minimal"',
            '"full"',
            '"18"',
            '"20"',
        ],
    },
}


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def stage_repo(tmp: Path, fixture: str) -> None:
    """Copy project files into ``tmp`` and stage the chosen fixture as basic.json."""
    for rel in PROJECT_FILES:
        src = ROOT / rel
        dst = tmp / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    # Stage the case's fixture AS basic.json (the workflow default).
    (tmp / "fixtures").mkdir(exist_ok=True)
    shutil.copy2(FIXTURE_DIR / fixture, tmp / "fixtures" / "basic.json")
    # Minimal git repo -- act requires one.
    run(["git", "init", "-q", "-b", "main"], cwd=tmp)
    run(["git", "config", "user.email", "t@t"], cwd=tmp)
    run(["git", "config", "user.name", "t"], cwd=tmp)
    run(["git", "add", "-A"], cwd=tmp)
    run(["git", "commit", "-qm", "init"], cwd=tmp)


def extract_matrix_block(log: str) -> str:
    m = re.search(r"===MATRIX-BEGIN===(.*?)===MATRIX-END===", log, re.DOTALL)
    return m.group(1) if m else ""


def assert_case(name: str, expect: dict, log: str) -> list[str]:
    """Return list of failure messages (empty = pass)."""
    failures = []
    # 1. Combo count
    m = re.search(r"===COMBO-COUNT===(\d+)===", log)
    if not m:
        failures.append(f"{name}: COMBO-COUNT marker missing")
    else:
        actual = int(m.group(1))
        if actual != expect["combo_count"]:
            failures.append(
                f"{name}: combo count {actual} != expected {expect['combo_count']}"
            )
    # 2. fail-fast
    m = re.search(r"===FAIL-FAST===(\w+)===", log)
    if not m:
        failures.append(f"{name}: FAIL-FAST marker missing")
    elif m.group(1) != expect["fail_fast"]:
        failures.append(
            f"{name}: fail-fast '{m.group(1)}' != expected '{expect['fail_fast']}'"
        )
    # 3. max-parallel
    m = re.search(r"===MAX-PARALLEL===(\d+)===", log)
    if expect["max_parallel"] is None:
        if m:
            failures.append(f"{name}: unexpected MAX-PARALLEL in output ({m.group(1)})")
    else:
        if not m:
            failures.append(f"{name}: MAX-PARALLEL marker missing")
        elif int(m.group(1)) != expect["max_parallel"]:
            failures.append(
                f"{name}: max-parallel {m.group(1)} != expected {expect['max_parallel']}"
            )
    # 4. Matrix JSON contents
    block = extract_matrix_block(log)
    for needle in expect["matrix_contains"]:
        if needle not in block:
            failures.append(f"{name}: expected substring not in matrix JSON: {needle!r}")
    # 5. Every job succeeded
    # act prints "Job succeeded" at end of each successful job.
    succeeded = log.count("Job succeeded")
    if succeeded < 2:
        failures.append(f"{name}: expected >=2 'Job succeeded' lines, got {succeeded}")
    return failures


def main() -> int:
    RESULT_FILE.write_text("")  # truncate
    all_failures: list[str] = []

    for fixture, expect in CASES.items():
        print(f"\n=== Running case: {fixture} ===", flush=True)
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            stage_repo(tmp, fixture)
            proc = subprocess.run(
                ["act", "push", "--rm", "--pull=false"],
                cwd=tmp,
                capture_output=True,
                text=True,
                timeout=900,
            )
            combined = proc.stdout + "\n" + proc.stderr
            header = f"\n\n{'=' * 70}\nCASE: {fixture}\nexit_code: {proc.returncode}\n{'=' * 70}\n"
            with RESULT_FILE.open("a") as f:
                f.write(header)
                f.write(combined)

            if proc.returncode != 0:
                all_failures.append(f"{fixture}: act exit code {proc.returncode}")
            all_failures.extend(assert_case(fixture, expect, combined))

    print("\n=== Summary ===")
    if all_failures:
        print("FAILURES:")
        for f in all_failures:
            print(f"  - {f}")
        return 1
    print(f"All {len(CASES)} cases passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
