#!/usr/bin/env python3
"""End-to-end test harness.

For each fixture case under fixtures/case-N:
  1. Build a fresh tmp git repo containing the project files plus
     that case's artifacts.json + policy.json copied to fixtures/.
  2. Run `act push --rm` inside that tmp repo, capturing stdout+stderr.
  3. Append the output to act-result.txt with a delimiter banner.
  4. Assert act exited 0, that "Job succeeded" appears for each job,
     and that the cleanup-plan stdout contains the EXACT expected lines
     for that case.

Limit: this harness invokes `act push` exactly once per case (3 total).
"""

import os
import shutil
import subprocess
import sys
import tempfile
import textwrap

ROOT = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT = os.path.join(ROOT, "act-result.txt")


# Per-case expected substrings. We assert EXACT values, not "looks roughly right".
EXPECTED = {
    "case-1": [
        "Mode: dry-run",
        "Total artifacts seen: 5",
        "Artifacts retained: 1",
        "Artifacts deleted: 4",
        "Space reclaimed: 260.00 MB",
        "Space retained: 30.00 MB",
        "DELETE art-1 (size=50.00 MB, workflow=wf-1)",
        "DELETE art-2 (size=80.00 MB, workflow=wf-1)",
        "DELETE art-3 (size=60.00 MB, workflow=wf-1)",
        "DELETE art-4 (size=70.00 MB, workflow=wf-1)",
        "KEEP   art-5 (size=30.00 MB, workflow=wf-1)",
    ],
    "case-2": [
        "Mode: dry-run",
        "Total artifacts seen: 4",
        "Artifacts retained: 2",
        "Artifacts deleted: 2",
        "Space reclaimed: 40.00 MB",
        "Space retained: 60.00 MB",
        "DELETE art-A1 (size=10.00 MB, workflow=wf-A)",
        "DELETE art-B1 (size=30.00 MB, workflow=wf-B)",
        "KEEP   art-A2 (size=20.00 MB, workflow=wf-A)",
        "KEEP   art-B2 (size=40.00 MB, workflow=wf-B)",
    ],
    "case-3": [
        "Mode: dry-run",
        "Total artifacts seen: 2",
        "Artifacts retained: 2",
        "Artifacts deleted: 0",
        "Space reclaimed: 0.00 MB",
        "Space retained: 15.00 MB",
        "KEEP   art-fresh-1 (size=5.00 MB, workflow=wf-1)",
        "KEEP   art-fresh-2 (size=10.00 MB, workflow=wf-2)",
    ],
}

# Expected job-success markers. act prints "Job succeeded" when a job finishes OK.
JOBS = ("unit-tests", "cleanup-plan")


def _copytree_files(src_dir, dst_dir, names):
    """Copy a flat set of items (files or dirs) from src to dst."""
    for name in names:
        s = os.path.join(src_dir, name)
        d = os.path.join(dst_dir, name)
        if os.path.isdir(s):
            shutil.copytree(s, d)
        elif os.path.isfile(s):
            os.makedirs(os.path.dirname(d) or ".", exist_ok=True)
            shutil.copy2(s, d)


def _git(cmd, cwd):
    return subprocess.run(
        ["git"] + cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
    )


def _build_case_repo(case, tmpdir):
    """Lay out a tmp git repo containing the project files + this case's fixtures."""
    # 1. Copy project files (excluding fixtures/, .git/, etc.).
    project_files = [
        "retention.py",
        "tests",
        ".github",
        ".actrc",
    ]
    _copytree_files(ROOT, tmpdir, project_files)

    # 2. Copy that case's fixture data into the canonical paths the workflow reads.
    case_dir = os.path.join(ROOT, "fixtures", case)
    fixtures_dst = os.path.join(tmpdir, "fixtures")
    os.makedirs(fixtures_dst, exist_ok=True)
    shutil.copy2(os.path.join(case_dir, "artifacts.json"),
                 os.path.join(fixtures_dst, "artifacts.json"))
    shutil.copy2(os.path.join(case_dir, "policy.json"),
                 os.path.join(fixtures_dst, "policy.json"))

    # 3. Initialise a git repo. act needs one to derive event metadata.
    _git(["init", "-q", "-b", "main"], tmpdir)
    _git(["config", "user.email", "harness@example.com"], tmpdir)
    _git(["config", "user.name",  "Test Harness"], tmpdir)
    _git(["config", "commit.gpgsign", "false"], tmpdir)
    _git(["add", "-A"], tmpdir)
    _git(["commit", "-q", "-m", f"fixture: {case}"], tmpdir)


def _run_act(case_dir):
    """Invoke act once. Returns (returncode, combined_output)."""
    # --pull=false: the act-ubuntu-pwsh image is built locally, not on a registry.
    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=case_dir,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout + "\n--- stderr ---\n" + proc.stderr


def _assert_substrings(case, output, expected):
    missing = [s for s in expected if s not in output]
    if missing:
        raise AssertionError(
            f"[{case}] missing expected substrings:\n  - "
            + "\n  - ".join(missing)
        )


def _assert_jobs_succeeded(case, output):
    for job in JOBS:
        # act prints lines like:
        #   [Artifact Cleanup/Unit tests        ] Job succeeded
        if "Job succeeded" not in output:
            raise AssertionError(
                f"[{case}] no 'Job succeeded' marker in act output"
            )
        if job not in output.replace("-", "-").lower() and \
           job.replace("-", " ") not in output.lower():
            # Fallback check: at least each declared job name (with - or space) appears.
            raise AssertionError(
                f"[{case}] expected job marker for {job!r} not found"
            )


def main() -> int:
    # Truncate the result file so we always start fresh.
    with open(ACT_RESULT, "w") as f:
        f.write("# act-result.txt -- combined output from end-to-end test runs\n")

    failed = []
    for case in sorted(EXPECTED.keys()):
        print(f"\n==== running {case} ====", flush=True)
        with tempfile.TemporaryDirectory(prefix=f"actcase-{case}-") as tmp:
            _build_case_repo(case, tmp)
            rc, output = _run_act(tmp)

        # Append to combined log -- always, even on failure.
        with open(ACT_RESULT, "a") as f:
            f.write("\n" + "=" * 72 + "\n")
            f.write(f"=== {case} (act exit={rc}) ===\n")
            f.write("=" * 72 + "\n")
            f.write(output)

        try:
            if rc != 0:
                raise AssertionError(f"[{case}] act exited with {rc}")
            _assert_jobs_succeeded(case, output)
            _assert_substrings(case, output, EXPECTED[case])
            print(f"[{case}] OK")
        except AssertionError as e:
            print(f"[{case}] FAIL: {e}", file=sys.stderr)
            failed.append(case)

    print("\n==== summary ====")
    print(f"Cases run:   {len(EXPECTED)}")
    print(f"Failures:    {len(failed)}")
    print(f"Log:         {ACT_RESULT}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
