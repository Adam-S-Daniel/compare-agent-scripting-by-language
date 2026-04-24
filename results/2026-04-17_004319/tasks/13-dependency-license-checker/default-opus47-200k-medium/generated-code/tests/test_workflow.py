"""
End-to-end pipeline tests.

Each test case:
  1. Builds a temp git repo containing the project + that case's fixtures.
  2. Runs `act push --rm` against it.
  3. Appends the full act output to act-result.txt in the project root.
  4. Asserts the run exited 0, every job succeeded, and the expected
     EXACT strings appear in the output for that fixture data.

Also includes workflow-structure tests (YAML parse + actionlint).

Limit: at most 3 `act push` invocations (two test cases + one re-run budget).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

try:
    import yaml  # noqa: F401
    HAVE_YAML = True
except ImportError:
    HAVE_YAML = False


PROJECT_ROOT = Path(__file__).resolve().parent.parent
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"
WORKFLOW = PROJECT_ROOT / ".github" / "workflows" / "dependency-license-checker.yml"


# ---------- workflow structure tests ----------

def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"missing workflow file: {WORKFLOW}"


@pytest.mark.skipif(not HAVE_YAML, reason="PyYAML not installed")
def test_workflow_yaml_structure():
    import yaml
    data = yaml.safe_load(WORKFLOW.read_text())
    # Note: YAML parses bare "on" as bool True — handle both
    triggers = data.get("on", data.get(True))
    assert triggers is not None, "workflow must declare triggers"
    for t in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert t in triggers, f"missing trigger: {t}"

    jobs = data["jobs"]
    assert "unit-tests" in jobs
    assert "license-scan" in jobs
    # license-scan depends on unit-tests
    assert jobs["license-scan"].get("needs") == "unit-tests"

    # permissions should be declared (least-privilege)
    assert data.get("permissions", {}).get("contents") == "read"


def test_workflow_references_existing_script_paths():
    text = WORKFLOW.read_text()
    assert "license_checker.py" in text
    assert (PROJECT_ROOT / "license_checker.py").exists()
    assert (PROJECT_ROOT / "fixtures" / "requirements.txt").exists()
    assert (PROJECT_ROOT / "fixtures" / "licenses.json").exists()
    assert (PROJECT_ROOT / "fixtures" / "license_lookup.json").exists()
    assert (PROJECT_ROOT / "tests" / "test_license_checker.py").exists()


def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )


# ---------- act end-to-end tests ----------

def _copy_project(dest: Path) -> None:
    """Copy the project into a temp dir. Skip .git and caches."""
    for item in PROJECT_ROOT.iterdir():
        if item.name in {".git", "__pycache__", ".pytest_cache", "act-result.txt"}:
            continue
        target = dest / item.name
        if item.is_dir():
            shutil.copytree(item, target, ignore=shutil.ignore_patterns(
                "__pycache__", ".pytest_cache", "*.pyc"
            ))
        else:
            shutil.copy2(item, target)


def _init_git_repo(path: Path) -> None:
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=path, check=True)
    subprocess.run(["git", "add", "-A"], cwd=path, check=True)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t",
         "commit", "-q", "-m", "init"],
        cwd=path,
        check=True,
    )


def _run_act(cwd: Path) -> subprocess.CompletedProcess:
    # Propagate .actrc if present in the host workspace
    actrc_src = PROJECT_ROOT / ".actrc"
    if actrc_src.exists():
        shutil.copy2(actrc_src, cwd / ".actrc")
    return subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=600,
    )


def _append_result(label: str, cp: subprocess.CompletedProcess) -> None:
    block = [
        "=" * 72,
        f"TEST CASE: {label}",
        f"exit_code: {cp.returncode}",
        "-" * 72,
        "STDOUT:",
        cp.stdout,
        "-" * 72,
        "STDERR:",
        cp.stderr,
        "=" * 72,
        "",
    ]
    with ACT_RESULT_FILE.open("a") as f:
        f.write("\n".join(block))


def _assert_success(label: str, cp: subprocess.CompletedProcess) -> None:
    combined = cp.stdout + "\n" + cp.stderr
    assert cp.returncode == 0, (
        f"[{label}] act returned {cp.returncode}\n{combined[-3000:]}"
    )
    # Every job must show Job succeeded. Our workflow has two jobs.
    succeeded = combined.count("Job succeeded")
    assert succeeded >= 2, (
        f"[{label}] expected both jobs to succeed (saw {succeeded} 'Job succeeded')\n"
        f"{combined[-3000:]}"
    )


@pytest.fixture(scope="module", autouse=True)
def _clear_act_result():
    if ACT_RESULT_FILE.exists():
        ACT_RESULT_FILE.unlink()
    yield


@pytest.mark.e2e
def test_act_case_mixed_licenses(tmp_path):
    """Run with the default fixtures — a mix of approved/denied/unknown."""
    work = tmp_path / "proj"
    work.mkdir()
    _copy_project(work)
    _init_git_repo(work)

    cp = _run_act(work)
    _append_result("mixed_licenses", cp)
    _assert_success("mixed_licenses", cp)

    out = cp.stdout + cp.stderr

    # Expected exact substrings for the default fixtures.
    # 5 deps: flask(BSD-3, approved), requests(Apache-2.0, approved),
    # click(BSD-3, approved), pyyaml(MIT, approved), mysterypkg(unknown license).
    expected = [
        "flask==2.0.1  license=BSD-3-Clause  status=APPROVED",
        "requests==2.28.0  license=Apache-2.0  status=APPROVED",
        "click==8.1.3  license=BSD-3-Clause  status=APPROVED",
        "pyyaml==6.0  license=MIT  status=APPROVED",
        "mysterypkg==1.0.0  license=SomeCustom-1.0  status=UNKNOWN",
        "Total: 5  Approved: 4  Denied: 0  Unknown: 1",
    ]
    for needle in expected:
        assert needle in out, f"[mixed_licenses] missing expected output: {needle!r}"

    # Unit-tests job must have run the pytest collection.
    assert "17 passed" in out, "[mixed_licenses] expected 17 unit tests to pass"


@pytest.mark.e2e
def test_act_case_with_denied_license(tmp_path):
    """Replace fixtures with a denied-license scenario; report should count it."""
    work = tmp_path / "proj"
    work.mkdir()
    _copy_project(work)

    # Overwrite requirements + lookup to include a GPL-3.0 package.
    (work / "fixtures" / "requirements.txt").write_text(
        "flask==2.0.1\nevilpkg==1.0.0\n"
    )
    (work / "fixtures" / "license_lookup.json").write_text(json.dumps({
        "flask": "BSD-3-Clause",
        "evilpkg": "GPL-3.0",
    }))

    _init_git_repo(work)
    cp = _run_act(work)
    _append_result("denied_license", cp)
    _assert_success("denied_license", cp)

    out = cp.stdout + cp.stderr
    expected = [
        "flask==2.0.1  license=BSD-3-Clause  status=APPROVED",
        "evilpkg==1.0.0  license=GPL-3.0  status=DENIED",
        "Total: 2  Approved: 1  Denied: 1  Unknown: 0",
    ]
    for needle in expected:
        assert needle in out, f"[denied_license] missing expected output: {needle!r}"
