#!/usr/bin/env python3
"""Act-based end-to-end test harness for the dependency-license-checker workflow.

For each test case:
  1. Create a temp git repo with our project files + the case's fixture data
  2. Run `act push --rm`, capture the output
  3. Append the output to act-result.txt with a clear delimiter
  4. Assert exit code 0 (the workflow itself uses `continue-on-error` for the
     license check so denied deps don't fail the act run)
  5. Assert exact expected strings appear in the output
  6. Assert every job shows "Job succeeded"
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import textwrap
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent
ACT_RESULT = REPO / "act-result.txt"


@dataclass
class Case:
    name: str
    # Files to write into the temp repo, mapped path -> content
    files: dict[str, str]
    # Strings that MUST appear in act stdout/stderr
    must_contain: list[str] = field(default_factory=list)
    # Strings that must NOT appear
    must_not_contain: list[str] = field(default_factory=list)


def _project_files() -> dict[str, str]:
    """Snapshot the project files we want copied into each test repo."""
    files: dict[str, str] = {}
    paths = [
        "license_checker.py",
        ".github/workflows/dependency-license-checker.yml",
        ".actrc",
    ]
    for rel in paths:
        files[rel] = (REPO / rel).read_text()
    # tests directory + fixtures
    for sub in ("tests", "fixtures"):
        for p in (REPO / sub).rglob("*"):
            if p.is_file() and "__pycache__" not in p.parts:
                files[str(p.relative_to(REPO))] = p.read_text()
    return files


def _write_files(root: Path, files: dict[str, str]) -> None:
    for rel, content in files.items():
        dest = root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content)


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)


def _init_git(root: Path) -> None:
    _run(["git", "init", "-q", "-b", "main"], root)
    _run(["git", "config", "user.email", "test@example.com"], root)
    _run(["git", "config", "user.name", "tester"], root)
    _run(["git", "add", "-A"], root)
    cp = _run(["git", "commit", "-q", "-m", "init"], root)
    if cp.returncode != 0:
        raise RuntimeError(f"git commit failed: {cp.stderr}")


def _run_act(workdir: Path) -> subprocess.CompletedProcess:
    """Invoke `act push --rm` in workdir."""
    # --pull=false: the .actrc maps ubuntu-latest to a local-only image
    # (act-ubuntu-pwsh:latest). Without this, act tries to pull from a
    # registry that doesn't have it and fails immediately.
    cmd = ["act", "push", "--rm", "--pull=false"]
    return subprocess.run(
        cmd, cwd=str(workdir), capture_output=True, text=True,
        timeout=600,
    )


def _build_cases() -> list[Case]:
    base = _project_files()

    # Case A: mixed manifest with one denied + one unknown license.
    # Default fixture targets sample-package.json/sample-licenses.json.
    case_a = Case(
        name="mixed-mit-gpl-unknown",
        files=dict(base),
        must_contain=[
            "Job succeeded",
            "CHECKER_EXITCODE=1",  # script correctly flagged denied dep
            "LICENSE_SUMMARY approved=3 denied=1 unknown=1",
            "DEP lodash@4.17.21 license=MIT status=approved",
            "DEP express@4.18.2 license=MIT status=approved",
            "DEP evil-pkg@1.0.0 license=GPL-3.0 status=denied",
            "DEP obscure-lib@0.1.0 license=WTFPL status=unknown",
            "DEP jest@29.7.0 license=MIT status=approved",
        ],
    )

    # Case B: requirements.txt where every dep is approved (job exits 0).
    files_b = dict(base)
    # Override the default fixture by overwriting the sample-* files —
    # the workflow reads MANIFEST_PATH/CONFIG_PATH which default to
    # the sample-* paths under fixtures/.
    files_b["fixtures/sample-package.json"] = "{}"  # not used for this case
    # Use a different manifest: switch the workflow defaults via env in
    # the workflow file would require editing it; instead we reuse sample-*
    # paths for both cases and overwrite their contents.
    files_b["fixtures/sample-package.json"] = (REPO / "fixtures" / "all-clean-requirements.txt").read_text()
    # That won't work — extension matters. Instead overwrite the sample
    # JSON config and provide a clean package.json.
    files_b["fixtures/sample-package.json"] = (
        '{"name": "clean", "version": "1.0.0",'
        ' "dependencies": {"requests": "2.31.0", "flask": "2.3.3", "click": "8.1.7"}}'
    )
    files_b["fixtures/sample-licenses.json"] = (REPO / "fixtures" / "all-clean-licenses.json").read_text()
    case_b = Case(
        name="all-approved",
        files=files_b,
        must_contain=[
            "Job succeeded",
            "LICENSE_SUMMARY approved=3 denied=0 unknown=0",
            "DEP requests@2.31.0 license=Apache-2.0 status=approved",
            "DEP flask@2.3.3 license=BSD-3-Clause status=approved",
            "DEP click@8.1.7 license=BSD-3-Clause status=approved",
        ],
        must_not_contain=["status=denied"],
    )

    # Case C: empty manifest (zero deps -> zero counts, job succeeds).
    files_c = dict(base)
    files_c["fixtures/sample-package.json"] = (
        '{"name": "empty", "version": "1.0.0", "dependencies": {}}'
    )
    files_c["fixtures/sample-licenses.json"] = (
        '{"allow": ["MIT"], "deny": ["GPL-3.0"], "mock_licenses": {}}'
    )
    case_c = Case(
        name="empty-manifest",
        files=files_c,
        must_contain=[
            "Job succeeded",
            "LICENSE_SUMMARY approved=0 denied=0 unknown=0",
        ],
        must_not_contain=["status=denied"],
    )

    return [case_a, case_b, case_c]


def _append_result(handle, case: Case, cp: subprocess.CompletedProcess) -> None:
    handle.write("\n" + "=" * 80 + "\n")
    handle.write(f"CASE: {case.name}\n")
    handle.write(f"act exit code: {cp.returncode}\n")
    handle.write("-" * 80 + "\n")
    handle.write("STDOUT:\n")
    handle.write(cp.stdout)
    handle.write("\n" + "-" * 80 + "\n")
    handle.write("STDERR:\n")
    handle.write(cp.stderr)
    handle.write("\n")


def _run_case(case: Case, log) -> list[str]:
    """Run a single case under act and return list of failure messages."""
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix=f"act-{case.name}-") as td:
        root = Path(td)
        _write_files(root, case.files)
        _init_git(root)
        cp = _run_act(root)
        _append_result(log, case, cp)
        combined = cp.stdout + "\n" + cp.stderr

        if cp.returncode != 0:
            failures.append(
                f"{case.name}: act exited {cp.returncode} (expected 0)"
            )

        # Every workflow job (test + check) should report success.
        success_count = combined.count("Job succeeded")
        if success_count < 2:
            failures.append(
                f"{case.name}: expected >=2 'Job succeeded' lines, found {success_count}"
            )

        for needle in case.must_contain:
            if needle not in combined:
                failures.append(
                    f"{case.name}: missing expected output: {needle!r}"
                )
        for needle in case.must_not_contain:
            if needle in combined:
                failures.append(
                    f"{case.name}: unexpected output present: {needle!r}"
                )
    return failures


def main() -> int:
    cases = _build_cases()
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()

    all_failures: list[str] = []
    with ACT_RESULT.open("w") as log:
        log.write(f"Act test run: {len(cases)} cases\n")
        for case in cases:
            print(f"=== Running case: {case.name} ===", flush=True)
            failures = _run_case(case, log)
            log.flush()
            for f in failures:
                print(f"FAIL: {f}", flush=True)
            all_failures.extend(failures)

    if all_failures:
        print(f"\n{len(all_failures)} assertion failure(s):")
        for f in all_failures:
            print(f"  - {f}")
        return 1
    print(f"\nAll {len(cases)} cases passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
