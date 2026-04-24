"""
Workflow / act integration tests.

Each test case:
  - Sets up a throwaway git repo with project files + that case's fixture + policy
  - Runs `act push --rm`
  - Appends raw act output (clearly delimited) to /<workspace>/act-result.txt
  - Asserts exit code 0, "Job succeeded", and EXACT expected numbers parsed
    from the "CLEANUP PLAN SUMMARY" / DELETE NAMES / KEEP NAMES markers.

We limit ourselves to 2 `act push` runs to stay under the 3-run cap; the two
cases exercise all three retention policies between them.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
ACT_RESULT = ROOT / "act-result.txt"

PROJECT_FILES = [
    "cleanup.py",
    ".github/workflows/artifact-cleanup-script.yml",
]

# Local .actrc: pin to a locally-cached image and disable force-pull.
ACTRC_CONTENT = "-P ubuntu-latest=catthehacker/ubuntu:act-latest\n--pull=false\n"


def _have_prereqs() -> tuple[bool, str]:
    if not shutil.which("act"):
        return False, "act not installed"
    if not shutil.which("docker"):
        return False, "docker not installed"
    try:
        subprocess.run(
            ["docker", "info"],
            check=True,
            capture_output=True,
            timeout=10,
        )
    except Exception as exc:  # noqa: BLE001
        return False, f"docker daemon unreachable: {exc}"
    return True, ""


def _write_case(tmp: Path, fixture: list[dict], policy: dict) -> None:
    """Populate a temp directory with the project + this case's data."""
    (tmp / "fixtures").mkdir(parents=True, exist_ok=True)
    for rel in PROJECT_FILES:
        src = ROOT / rel
        if not src.exists():
            continue
        dst = tmp / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    (tmp / "fixtures/case.json").write_text(json.dumps(fixture))
    (tmp / "fixtures/policy.json").write_text(json.dumps(policy))
    (tmp / ".actrc").write_text(ACTRC_CONTENT)

    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "case"], cwd=tmp, check=True
    )


def _run_act(tmp: Path) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env.setdefault("ACT_DISABLE_VERSION_CHECK", "1")
    return subprocess.run(
        ["act", "push", "--rm"],
        cwd=tmp,
        env=env,
        capture_output=True,
        text=True,
        timeout=600,
    )


def _append_result(label: str, proc: subprocess.CompletedProcess) -> None:
    header = f"\n{'=' * 72}\n== CASE: {label} (exit={proc.returncode})\n{'=' * 72}\n"
    with ACT_RESULT.open("a") as f:
        f.write(header)
        f.write("---- STDOUT ----\n")
        f.write(proc.stdout)
        f.write("\n---- STDERR ----\n")
        f.write(proc.stderr)
        f.write("\n")


def _strip_act_prefix(text: str) -> str:
    """Remove act's per-line `[job] | ` prefix so we can regex step output."""
    out = []
    for line in text.splitlines():
        # drop the `[artifact-cleanup-script/Plan artifact cleanup]   | ` part
        cleaned = re.sub(r"^\[.*?\]\s*\|\s?", "", line)
        cleaned = re.sub(r"^\[.*?\]\s*", "", cleaned)
        out.append(cleaned)
    return "\n".join(out)


def _extract_summary(text: str) -> dict:
    clean = _strip_act_prefix(text)
    m = re.search(r"CLEANUP PLAN SUMMARY ===\s*(\{.*?\})", clean, re.S)
    assert m, f"did not find summary JSON in act output:\n{clean[:2000]}"
    return json.loads(m.group(1))


def _extract_names(text: str, label: str) -> set[str]:
    clean = _strip_act_prefix(text)
    m = re.search(rf"=== {label} NAMES ===\s*([^\n]*)", clean)
    assert m, f"did not find {label} NAMES block"
    val = m.group(1).strip()
    return set(val.split(",")) if val else set()


# ---- fixtures & expected values -------------------------------------------------

FIXTURE_SAMPLE = [
    {"name": "build-linux-old",    "size_bytes": 524288000, "created_at": "2026-02-01T10:00:00+00:00", "workflow_run_id": 1001, "workflow_name": "ci"},
    {"name": "build-linux-recent", "size_bytes": 104857600, "created_at": "2026-04-18T10:00:00+00:00", "workflow_run_id": 1050, "workflow_name": "ci"},
    {"name": "test-logs-1",        "size_bytes": 10485760,  "created_at": "2026-04-10T10:00:00+00:00", "workflow_run_id": 1040, "workflow_name": "ci"},
    {"name": "test-logs-2",        "size_bytes": 10485760,  "created_at": "2026-04-15T10:00:00+00:00", "workflow_run_id": 1045, "workflow_name": "ci"},
    {"name": "release-bundle-v1",  "size_bytes": 209715200, "created_at": "2026-03-01T10:00:00+00:00", "workflow_run_id": 2001, "workflow_name": "release"},
    {"name": "release-bundle-v2",  "size_bytes": 209715200, "created_at": "2026-04-19T10:00:00+00:00", "workflow_run_id": 2002, "workflow_name": "release"},
]
TOTAL_SIZE = sum(a["size_bytes"] for a in FIXTURE_SAMPLE)  # 1_069_547_520


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.touch()


@pytest.fixture(scope="module")
def prereq_check():
    ok, reason = _have_prereqs()
    if not ok:
        pytest.skip(reason)


# ---- workflow structure tests (fast, no act needed) ----------------------------


def test_workflow_yaml_structure():
    import yaml
    wf = yaml.safe_load((ROOT / ".github/workflows/artifact-cleanup-script.yml").read_text())
    # PyYAML parses the key `on:` as Python boolean True — handle both forms.
    triggers = wf.get("on") or wf.get(True)
    assert triggers is not None, "no trigger block"
    assert "push" in triggers
    assert "workflow_dispatch" in triggers
    assert "schedule" in triggers
    assert "plan" in wf["jobs"]
    steps = wf["jobs"]["plan"]["steps"]
    assert any(s.get("uses", "").startswith("actions/checkout@v4") for s in steps)
    assert any(s.get("uses", "").startswith("actions/setup-python@v5") for s in steps)


def test_script_paths_referenced_exist():
    wf_text = (ROOT / ".github/workflows/artifact-cleanup-script.yml").read_text()
    assert "cleanup.py" in wf_text
    assert (ROOT / "cleanup.py").exists()


def test_actionlint_passes():
    if not shutil.which("actionlint"):
        pytest.skip("actionlint not installed")
    r = subprocess.run(
        ["actionlint", ".github/workflows/artifact-cleanup-script.yml"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, f"actionlint failed: {r.stdout}\n{r.stderr}"


# ---- act integration tests -----------------------------------------------------


def test_act_case_max_age(prereq_check, tmp_path_factory):
    """Case A: delete artifacts older than 30 days (now = 2026-04-20)."""
    tmp = tmp_path_factory.mktemp("case_age")
    policy = {"max_age_days": 30, "now": "2026-04-20T12:00:00+00:00"}
    _write_case(tmp, FIXTURE_SAMPLE, policy)

    proc = _run_act(tmp)
    _append_result("max_age_30d", proc)

    assert proc.returncode == 0, proc.stderr
    combined = proc.stdout + proc.stderr
    assert "Job succeeded" in combined

    summary = _extract_summary(proc.stdout)
    # build-linux-old (Feb 1) and release-bundle-v1 (Mar 1) are > 30d old
    assert summary["deleted_count"] == 2
    assert summary["retained_count"] == 4
    reclaimed = 524288000 + 209715200  # 734_003_200
    assert summary["space_reclaimed_bytes"] == reclaimed
    assert summary["total_size_before_bytes"] == TOTAL_SIZE
    assert summary["total_size_after_bytes"] == TOTAL_SIZE - reclaimed
    assert summary["dry_run"] is True

    deleted = _extract_names(proc.stdout, "DELETE")
    assert deleted == {"build-linux-old", "release-bundle-v1"}
    kept = _extract_names(proc.stdout, "KEEP")
    assert kept == {
        "build-linux-recent",
        "test-logs-1",
        "test-logs-2",
        "release-bundle-v2",
    }


def test_act_case_keep_latest_and_size(prereq_check, tmp_path_factory):
    """Case B: keep newest 1 per workflow + overall 300MB cap."""
    tmp = tmp_path_factory.mktemp("case_keepN_size")
    # With keep_latest_n=1 alone, delete 4 (leaving build-linux-recent 100MB
    # + release-bundle-v2 200MB = ~300MB). Add a 300MB budget: survivors
    # total is 104857600 + 209715200 = 314_572_800 > 300_000_000 so the
    # size policy must evict the largest survivor (release-bundle-v2).
    policy = {"keep_latest_n": 1, "max_total_bytes": 300_000_000}
    _write_case(tmp, FIXTURE_SAMPLE, policy)

    proc = _run_act(tmp)
    _append_result("keep_latest_1_plus_300MB_cap", proc)

    assert proc.returncode == 0, proc.stderr
    combined = proc.stdout + proc.stderr
    assert "Job succeeded" in combined

    summary = _extract_summary(proc.stdout)
    # keep-N deletes: build-linux-old, test-logs-1, test-logs-2, release-bundle-v1
    # then size trims release-bundle-v2 (biggest remaining).
    assert summary["deleted_count"] == 5
    assert summary["retained_count"] == 1
    reclaimed = 524288000 + 10485760 + 10485760 + 209715200 + 209715200
    assert summary["space_reclaimed_bytes"] == reclaimed
    assert summary["total_size_after_bytes"] == TOTAL_SIZE - reclaimed

    deleted = _extract_names(proc.stdout, "DELETE")
    assert deleted == {
        "build-linux-old",
        "test-logs-1",
        "test-logs-2",
        "release-bundle-v1",
        "release-bundle-v2",
    }
    kept = _extract_names(proc.stdout, "KEEP")
    assert kept == {"build-linux-recent"}
