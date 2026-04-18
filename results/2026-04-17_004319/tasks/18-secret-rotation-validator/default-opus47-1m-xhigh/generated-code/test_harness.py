#!/usr/bin/env python3
"""End-to-end test harness for the secret-rotation-validator workflow.

For each test case this harness:
  1. Stages a fresh temp git repo containing the workflow, validator.py, and
     the case's fixture copied to fixtures/current.json / current.env.
  2. Runs `act push --rm` inside that temp repo.
  3. Captures stdout + stderr and appends them, clearly delimited, to
     act-result.txt in the current working directory.
  4. Asserts act exited 0 and that every job reached "Job succeeded".
  5. Parses the validator's JSON and Markdown output from the act log and
     asserts EXACT expected values for summary counts, bucket membership,
     expired ordering, and notify routing.

It also performs structural assertions on the workflow file: actionlint
passes, required triggers/jobs/permissions exist, and referenced paths
resolve to real files.

Run:
    python3 test_harness.py
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import traceback
from dataclasses import dataclass, field
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent
WORKFLOW_REL = Path(".github/workflows/secret-rotation-validator.yml")
WORKFLOW_ABS = ROOT / WORKFLOW_REL
ACT_RESULT = ROOT / "act-result.txt"


@dataclass
class Case:
    name: str
    fixture_json: str
    fixture_env: str
    expected_summary: dict
    expected_bucket_order: dict          # bucket -> ordered list of names
    expected_md_contains: list[str]
    expected_md_missing: list[str] = field(default_factory=list)
    expected_notify_route: str = "none"
    expected_notify_lines: list[str] = field(default_factory=list)


# Precomputed values — see calendar math captured in README / test_validator.py.
CASES: list[Case] = [
    Case(
        name="all-ok",
        fixture_json="all-ok.json",
        fixture_env="all-ok.env",
        expected_summary={
            "expired_count": 0,
            "warning_count": 0,
            "ok_count": 2,
            "total": 2,
        },
        expected_bucket_order={
            "expired": [],
            "warning": [],
            "ok": ["api-key-ok", "db-password"],  # sorted by days_until_expiry ASC
        },
        expected_md_contains=[
            "# Secret Rotation Report",
            "**Reference Date:** 2026-04-17",
            "**Warning Window:** 14 days",
            "- Expired: 0",
            "- Warning: 0",
            "- OK: 2",
            "- Total: 2",
            "_No expired secrets._",
            "_No warnings._",
            "| api-key-ok |",
            "| db-password |",
        ],
        expected_notify_route="none",
        expected_notify_lines=[
            "expired=0",
            "warning=0",
            "ok=2",
            "total=2",
        ],
    ),
    Case(
        name="has-warning",
        fixture_json="has-warning.json",
        fixture_env="has-warning.env",
        expected_summary={
            "expired_count": 0,
            "warning_count": 1,
            "ok_count": 1,
            "total": 2,
        },
        expected_bucket_order={
            "expired": [],
            "warning": ["expiring-soon"],
            "ok": ["fresh-api-key"],
        },
        expected_md_contains=[
            "- Expired: 0",
            "- Warning: 1",
            "- OK: 1",
            "- Total: 2",
            "_No expired secrets._",
            "| expiring-soon |",
            "| fresh-api-key |",
        ],
        expected_notify_route="slack",
        expected_notify_lines=[
            "expired=0",
            "warning=1",
            "ok=1",
            "total=2",
        ],
    ),
    Case(
        name="mixed",
        fixture_json="mixed.json",
        fixture_env="mixed.env",
        expected_summary={
            "expired_count": 2,
            "warning_count": 1,
            "ok_count": 2,
            "total": 5,
        },
        expected_bucket_order={
            # expired sorted by most-overdue first.
            "expired": ["ancient-key", "stale-cert"],
            "warning": ["almost-due"],
            "ok": ["healthy-1", "healthy-2"],
        },
        expected_md_contains=[
            "- Expired: 2",
            "- Warning: 1",
            "- OK: 2",
            "- Total: 5",
            "| ancient-key |",
            "| stale-cert |",
            "| almost-due |",
            "| healthy-1 |",
            "| healthy-2 |",
        ],
        expected_md_missing=[
            "_No expired secrets._",
            "_No warnings._",
        ],
        expected_notify_route="pager",
        expected_notify_lines=[
            "expired=2",
            "warning=1",
            "ok=2",
            "total=5",
        ],
    ),
]


# -- logging helpers ---------------------------------------------------------

def _append_act_result(header: str, body: str) -> None:
    with ACT_RESULT.open("a") as fh:
        fh.write(f"\n\n{'=' * 72}\n{header}\n{'=' * 72}\n")
        fh.write(body)
        if not body.endswith("\n"):
            fh.write("\n")


def _log(msg: str) -> None:
    print(msg, flush=True)


# -- act output parsing ------------------------------------------------------

_ACT_PREFIX_RE = re.compile(r"^\[[^\]]+\]\s*(?:\|\s?)?(.*)$")


def extract_script_output(act_stdout: str) -> str:
    """Strip act's '[job name]   | ' prefix from each line so we can search
    for our own delimiters in a clean stream."""
    cleaned_lines: list[str] = []
    for line in act_stdout.splitlines():
        m = _ACT_PREFIX_RE.match(line)
        if m:
            cleaned_lines.append(m.group(1))
        else:
            cleaned_lines.append(line)
    return "\n".join(cleaned_lines)


def extract_between(stream: str, start: str, end: str) -> str | None:
    pattern = re.compile(re.escape(start) + r"(.*?)" + re.escape(end), re.DOTALL)
    m = pattern.search(stream)
    if not m:
        return None
    return m.group(1).strip()


# -- structural validation ---------------------------------------------------

def validate_workflow_structure() -> None:
    """Static checks on the workflow file. No act execution."""
    _log("Structural checks ...")
    assert WORKFLOW_ABS.exists(), f"workflow missing: {WORKFLOW_ABS}"

    # actionlint
    al = subprocess.run(
        ["actionlint", str(WORKFLOW_ABS)],
        capture_output=True, text=True,
    )
    _append_act_result(
        "STRUCTURAL: actionlint",
        f"exit={al.returncode}\nstdout:\n{al.stdout}\nstderr:\n{al.stderr}",
    )
    assert al.returncode == 0, f"actionlint failed:\n{al.stdout}{al.stderr}"

    wf = yaml.safe_load(WORKFLOW_ABS.read_text())
    # In YAML 1.1, the bare key `on` can be parsed as the boolean True.
    triggers = wf.get("on", wf.get(True))
    assert triggers is not None, "workflow missing 'on' triggers"
    for trig in ("push", "pull_request", "schedule", "workflow_dispatch"):
        assert trig in triggers, f"missing trigger: {trig}"

    assert wf.get("permissions", {}).get("contents") == "read", \
        "permissions.contents should be read"

    jobs = wf["jobs"]
    assert "validate" in jobs, "missing 'validate' job"
    assert "notify" in jobs, "missing 'notify' job"
    assert jobs["notify"].get("needs") == "validate", \
        "'notify' must depend on 'validate'"

    # At least one step in validate must invoke validator.py
    val_steps = jobs["validate"].get("steps", [])
    run_text = "\n".join(s.get("run", "") for s in val_steps if "run" in s)
    assert "validator.py" in run_text, "validate job must run validator.py"

    # At least one step must use actions/checkout@v4
    assert any(
        s.get("uses", "").startswith("actions/checkout@v4") for s in val_steps
    ), "validate job must use actions/checkout@v4"

    # Referenced files must exist.
    for p in ("validator.py", "fixtures/current.json", "fixtures/current.env"):
        assert (ROOT / p).exists(), f"referenced path missing: {p}"

    _log("  ok: actionlint, triggers, jobs, dependency, permissions, file refs")


# -- per-case execution ------------------------------------------------------

def _git(*args: str, cwd: Path) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True)


def stage_temp_repo(case: Case, dest: Path) -> None:
    """Copy only the files the workflow needs into a fresh temp repo."""
    # Project files
    shutil.copy(ROOT / "validator.py", dest / "validator.py")
    shutil.copy(ROOT / ".actrc", dest / ".actrc")

    # Workflow
    (dest / ".github" / "workflows").mkdir(parents=True)
    shutil.copy(WORKFLOW_ABS, dest / WORKFLOW_REL)

    # Fixture staged as the "current" case.
    fixtures_dir = dest / "fixtures"
    fixtures_dir.mkdir()
    shutil.copy(ROOT / "fixtures" / case.fixture_json, fixtures_dir / "current.json")
    shutil.copy(ROOT / "fixtures" / case.fixture_env, fixtures_dir / "current.env")

    # act requires a git repo
    _git("init", "-q", "-b", "main", cwd=dest)
    _git("config", "user.email", "harness@example.com", cwd=dest)
    _git("config", "user.name", "Harness", cwd=dest)
    _git("add", ".", cwd=dest)
    _git("commit", "-q", "-m", f"case: {case.name}", cwd=dest)


def run_act(repo: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["act", "push", "--rm"],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=600,
    )


# -- assertions on act output ------------------------------------------------

def assert_case(case: Case, proc: subprocess.CompletedProcess) -> None:
    combined = proc.stdout + "\n" + proc.stderr
    cleaned = extract_script_output(combined)

    # 1. act exit code.
    assert proc.returncode == 0, (
        f"[{case.name}] act exited {proc.returncode}\n--- stderr ---\n{proc.stderr[-2000:]}"
    )

    # 2. Both jobs succeeded. act emits "Job succeeded" per job.
    n_success = combined.count("Job succeeded")
    assert n_success >= 2, (
        f"[{case.name}] expected >=2 'Job succeeded' markers, got {n_success}"
    )

    # 3. Extract the JSON block and parse it.
    raw_json = extract_between(
        cleaned, "---VALIDATOR-JSON-BEGIN---", "---VALIDATOR-JSON-END---"
    )
    assert raw_json, f"[{case.name}] JSON block missing from act output"
    data = json.loads(raw_json)

    # 3a. Summary counts (EXACT).
    summary = data["summary"]
    for key, expected in case.expected_summary.items():
        assert summary[key] == expected, (
            f"[{case.name}] summary[{key}]={summary[key]}, expected {expected}"
        )

    # 3b. Bucket ordering (EXACT).
    for bucket, expected_names in case.expected_bucket_order.items():
        got = [row["name"] for row in data[bucket]]
        assert got == expected_names, (
            f"[{case.name}] {bucket} names = {got}, expected {expected_names}"
        )

    # 3c. reference date and warning window round-tripped.
    expected_ref = (ROOT / "fixtures" / case.fixture_env).read_text()
    m = re.search(r"REFERENCE_DATE=(\S+)", expected_ref)
    if m:
        assert data["reference_date"] == m.group(1), (
            f"[{case.name}] reference_date in JSON ({data['reference_date']}) "
            f"!= env ({m.group(1)})"
        )

    # 4. Extract Markdown block.
    raw_md = extract_between(
        cleaned, "---VALIDATOR-MD-BEGIN---", "---VALIDATOR-MD-END---"
    )
    assert raw_md, f"[{case.name}] Markdown block missing from act output"
    for snippet in case.expected_md_contains:
        assert snippet in raw_md, (
            f"[{case.name}] MD missing snippet: {snippet!r}"
        )
    for snippet in case.expected_md_missing:
        assert snippet not in raw_md, (
            f"[{case.name}] MD unexpectedly contains: {snippet!r}"
        )

    # 5. Notify block & route.
    raw_notify = extract_between(cleaned, "---NOTIFY-BEGIN---", "---NOTIFY-END---")
    assert raw_notify, f"[{case.name}] NOTIFY block missing"
    for line in case.expected_notify_lines:
        assert line in raw_notify, (
            f"[{case.name}] notify missing line {line!r}: got\n{raw_notify}"
        )
    route_line = f"route={case.expected_notify_route}"
    assert route_line in raw_notify, (
        f"[{case.name}] notify missing {route_line!r}: got\n{raw_notify}"
    )


# -- main --------------------------------------------------------------------

def main() -> int:
    # Start with a clean act-result.txt on every harness run.
    ACT_RESULT.write_text("")

    try:
        validate_workflow_structure()
    except AssertionError as exc:
        _append_act_result("STRUCTURAL FAILURE", str(exc))
        _log(f"STRUCTURAL FAIL: {exc}")
        return 1

    any_failed = False
    for case in CASES:
        _log(f"\n=== Case: {case.name} ===")
        with tempfile.TemporaryDirectory(prefix=f"srv-{case.name}-") as tmp:
            repo = Path(tmp)
            stage_temp_repo(case, repo)
            proc = run_act(repo)
            header = (
                f"CASE: {case.name}\n"
                f"fixture: {case.fixture_json} / {case.fixture_env}\n"
                f"act exit: {proc.returncode}\n"
            )
            body = (
                "----- stdout -----\n" + proc.stdout +
                "\n----- stderr -----\n" + proc.stderr
            )
            _append_act_result(header.rstrip(), body)

            try:
                assert_case(case, proc)
                _log(f"  PASS: {case.name}")
            except AssertionError as exc:
                any_failed = True
                msg = f"ASSERT FAIL [{case.name}]: {exc}"
                _log(msg)
                _append_act_result(f"ASSERTION FAILURE: {case.name}", str(exc))
                # Continue to other cases so we see everything in act-result.txt.

    if any_failed:
        _log("\nOVERALL: FAIL")
        return 1
    _log("\nOVERALL: ALL CASES PASSED")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # pylint: disable=broad-except
        traceback.print_exc()
        sys.exit(2)
