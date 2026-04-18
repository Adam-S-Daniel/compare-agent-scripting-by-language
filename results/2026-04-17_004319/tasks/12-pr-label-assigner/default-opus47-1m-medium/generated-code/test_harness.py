#!/usr/bin/env python3
"""Integration test harness.

For every directory under `fixtures/`, this harness:

1. Builds a temporary git repo containing the script, the workflow, and the
   fixture copied into `fixture/` (the path the workflow reads from).
2. Runs `act push --rm` against that repo.
3. Captures stdout+stderr, appends to `act-result.txt`.
4. Asserts act exits 0, every job reports "Job succeeded", and the emitted
   label block (between LABELS_BEGIN / LABELS_END) matches `expected.txt`.

Per the benchmark rules this harness never calls the Python script directly;
all test cases execute through the GitHub Actions workflow via act.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FIXTURES_DIR = ROOT / "fixtures"
RESULT_FILE = ROOT / "act-result.txt"
ACTRC = ROOT / ".actrc"


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, cwd=str(cwd), capture_output=True, text=True, check=False
    )


def _setup_repo(case_dir: Path, workdir: Path) -> None:
    """Copy script, workflow, and fixture data into a fresh git repo."""
    # Project files that all cases share.
    shutil.copy(ROOT / "label_assigner.py", workdir / "label_assigner.py")
    (workdir / ".github" / "workflows").mkdir(parents=True, exist_ok=True)
    shutil.copy(
        ROOT / ".github/workflows/pr-label-assigner.yml",
        workdir / ".github/workflows/pr-label-assigner.yml",
    )
    if ACTRC.exists():
        shutil.copy(ACTRC, workdir / ".actrc")
    # Per-case fixture data lands at the path the workflow reads.
    fixture_dst = workdir / "fixture"
    fixture_dst.mkdir()
    shutil.copy(case_dir / "rules.json", fixture_dst / "rules.json")
    shutil.copy(case_dir / "files.txt", fixture_dst / "files.txt")

    # Minimal git repo so `act push` has a commit to work against.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(
        ["git", "config", "user.email", "harness@example.com"],
        cwd=workdir,
        check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "harness"], cwd=workdir, check=True
    )
    subprocess.run(["git", "add", "-A"], cwd=workdir, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "fixture"], cwd=workdir, check=True
    )


def _parse_labels(act_output: str) -> list[str]:
    """Extract the LABELS_BEGIN...LABELS_END block from act logs.

    act prefixes every line with stuff like `| `, so we strip common prefixes
    before matching delimiters.
    """
    labels: list[str] = []
    in_block = False
    for raw in act_output.splitlines():
        # Strip the `[... ] ... | ` prefix act emits around command stdout.
        cleaned = raw
        if "| " in cleaned:
            cleaned = cleaned.split("| ", 1)[1]
        cleaned = cleaned.rstrip()
        if cleaned.endswith("LABELS_BEGIN"):
            in_block = True
            labels = []
            continue
        if cleaned.endswith("LABELS_END"):
            in_block = False
            continue
        if in_block:
            # Drop any leading whitespace that survived prefix stripping.
            label = cleaned.strip()
            if label:
                labels.append(label)
    return labels


def _append_result(header: str, body: str) -> None:
    with RESULT_FILE.open("a", encoding="utf-8") as f:
        f.write("=" * 72 + "\n")
        f.write(header + "\n")
        f.write("=" * 72 + "\n")
        f.write(body)
        if not body.endswith("\n"):
            f.write("\n")


def _read_expected(case_dir: Path) -> list[str]:
    text = (case_dir / "expected.txt").read_text(encoding="utf-8")
    return [line.strip() for line in text.splitlines() if line.strip()]


def _check_workflow_structure() -> None:
    """Workflow-structure assertions (YAML shape + referenced paths exist)."""
    # Use a tiny YAML reader rather than adding a PyYAML dependency: we just
    # verify the key fields are present as substrings in the right sections.
    wf = (ROOT / ".github/workflows/pr-label-assigner.yml").read_text(
        encoding="utf-8"
    )
    assert "on:" in wf, "workflow missing 'on:' triggers"
    assert "pull_request" in wf, "workflow should trigger on pull_request"
    assert "push" in wf, "workflow should trigger on push"
    assert "workflow_dispatch" in wf, "workflow should allow workflow_dispatch"
    assert "actions/checkout@v4" in wf, "workflow must checkout the repo"
    assert "label_assigner.py" in wf, "workflow must reference the script"
    assert (ROOT / "label_assigner.py").exists(), "script file missing"
    # actionlint should pass.
    result = _run(["actionlint", ".github/workflows/pr-label-assigner.yml"], ROOT)
    assert result.returncode == 0, (
        f"actionlint failed:\n{result.stdout}\n{result.stderr}"
    )
    print("workflow structure: OK")


def _run_case(case_dir: Path) -> bool:
    case_name = case_dir.name
    print(f"\n--- case: {case_name} ---")
    with tempfile.TemporaryDirectory(prefix=f"act-{case_name}-") as tmp:
        workdir = Path(tmp)
        _setup_repo(case_dir, workdir)
        # `act push --rm` builds and runs the workflow end-to-end.
        # --pull=false: the ubuntu-latest image is a locally-built pwsh image
        # (see .actrc); act would otherwise try to fetch it from a registry.
        proc = _run(["act", "push", "--rm", "--pull=false"], workdir)
        combined = (
            f"$ act push --rm   (case={case_name})\n"
            f"exit_code={proc.returncode}\n"
            f"--- stdout ---\n{proc.stdout}\n"
            f"--- stderr ---\n{proc.stderr}\n"
        )
        _append_result(f"CASE: {case_name}", combined)
        if proc.returncode != 0:
            print(f"FAIL: act exited {proc.returncode}")
            print(proc.stdout[-2000:])
            print(proc.stderr[-2000:])
            return False
        if "Job succeeded" not in proc.stdout and "Job succeeded" not in proc.stderr:
            print("FAIL: 'Job succeeded' not found in act output")
            return False
        labels = _parse_labels(proc.stdout + "\n" + proc.stderr)
        expected = _read_expected(case_dir)
        if labels != expected:
            print(f"FAIL: labels mismatch\n  expected: {expected}\n  got:      {labels}")
            return False
        print(f"PASS: labels={labels}")
        return True


def main() -> int:
    # Fresh result file each run so act-result.txt is deterministic.
    RESULT_FILE.write_text("", encoding="utf-8")

    _check_workflow_structure()

    cases = sorted(p for p in FIXTURES_DIR.iterdir() if p.is_dir())
    if not cases:
        print("no fixture cases found")
        return 1

    ok = 0
    for case_dir in cases:
        if _run_case(case_dir):
            ok += 1
    total = len(cases)
    print(f"\n{ok}/{total} cases passed")
    return 0 if ok == total else 1


if __name__ == "__main__":
    sys.exit(main())
