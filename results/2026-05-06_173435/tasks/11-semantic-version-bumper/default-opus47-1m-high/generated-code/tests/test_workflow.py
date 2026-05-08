"""End-to-end test harness for the semantic version bumper.

Per task requirements, every functional test case runs through the
GitHub Actions workflow via ``act``. For each case we:

1. Build a self-contained temporary git repo (bumper.py + workflow +
   fixture data + package.json + CHANGELOG.md).
2. Run ``act push --rm`` against it.
3. Append the act output to ``act-result.txt`` (delimited per case).
4. Assert exit code 0, "Job succeeded", and exact-value output assertions
   on the new version and changelog content.

Workflow structure tests (YAML parse, references, actionlint) are also
included here; they don't run act and are cheap.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_FILE = ROOT / ".github" / "workflows" / "semantic-version-bumper.yml"
ACT_RESULT_FILE = ROOT / "act-result.txt"
BUMP_DATE = "2026-05-07"


# ---------------------------------------------------------------------------
# Test cases. Each one is a self-contained scenario fed into the workflow.
# ---------------------------------------------------------------------------

CASES = [
    {
        "name": "feat_minor",
        "description": "feat commit + non-bumping commit -> minor bump",
        "starting_version": "1.2.3",
        "commits": [
            "feat(auth): add SSO login flow",
            "docs: update onboarding guide",
        ],
        "expected_version": "1.3.0",
        "expected_section": "Features",
        "expected_subject": "add SSO login flow",
    },
    {
        "name": "fix_patch",
        "description": "only fix commits -> patch bump",
        "starting_version": "1.2.3",
        "commits": [
            "fix: handle null in commit parser",
            "fix(api): correct error code for 404",
        ],
        "expected_version": "1.2.4",
        "expected_section": "Bug Fixes",
        "expected_subject": "handle null in commit parser",
    },
    {
        "name": "breaking_major",
        "description": "feat with ! marker -> major bump",
        "starting_version": "1.2.3",
        "commits": [
            "feat(api)!: redesign request payload",
        ],
        "expected_version": "2.0.0",
        "expected_section": "BREAKING CHANGES",
        "expected_subject": "redesign request payload",
    },
    {
        "name": "mixed_minor",
        "description": "feat + fix + chore -> minor bump (highest wins)",
        "starting_version": "0.9.5",
        "commits": [
            "fix: trim whitespace from inputs",
            "feat: add CSV export",
            "chore: bump dev dependencies",
        ],
        "expected_version": "0.10.0",
        "expected_section": "Features",
        "expected_subject": "add CSV export",
    },
    {
        "name": "chore_none",
        "description": "no bumping commits -> version unchanged",
        "starting_version": "2.0.1",
        "commits": [
            "chore: lint cleanup",
            "docs: typo fix in README",
        ],
        "expected_version": "2.0.1",
        "expected_section": None,
        "expected_subject": None,
    },
]


# ---------------------------------------------------------------------------
# Helpers to construct an isolated repo per case and invoke act on it.
# ---------------------------------------------------------------------------

def _build_case_repo(tmp_path: Path, case: dict) -> Path:
    """Materialize a self-contained git repo for one test case."""
    workdir = tmp_path / case["name"]
    workdir.mkdir()

    # Project files
    shutil.copy(ROOT / "bumper.py", workdir / "bumper.py")
    (workdir / "package.json").write_text(
        json.dumps({"name": "demo-app", "version": case["starting_version"]}, indent=2)
        + "\n"
    )
    (workdir / "CHANGELOG.md").write_text("# Changelog\n\n")

    # Per-case fixture: mock commit log
    fixtures = workdir / "fixtures"
    fixtures.mkdir()
    (fixtures / "commits.txt").write_text("\n".join(case["commits"]) + "\n")

    # Workflow + .actrc (so act uses the local custom image w/ pwsh, even
    # though we don't need pwsh here — the .actrc is the project default).
    wf_dst = workdir / ".github" / "workflows"
    wf_dst.mkdir(parents=True)
    shutil.copy(WORKFLOW_FILE, wf_dst / WORKFLOW_FILE.name)
    if (ROOT / ".actrc").exists():
        shutil.copy(ROOT / ".actrc", workdir / ".actrc")

    # Init git repo so act has something to push.
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "config", "user.name", "test"], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "add", "."], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=workdir, check=True, env=env)
    return workdir


def _run_act(workdir: Path) -> subprocess.CompletedProcess:
    """Run ``act push --rm`` inside the case repo.

    ``--pull=false`` is critical: the parent project's .actrc points at
    ``act-ubuntu-pwsh:latest`` which is a locally-built image. Without
    --pull=false, act tries to pull from Docker Hub and fails immediately
    with "pull access denied".
    """
    return subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=600,
    )


_ACT_LINE_PREFIX_RE = re.compile(r"^\[[^\]]+\]\s+\|\s?(.*)$")


def _strip_act_prefix(text: str) -> str:
    """Strip act's ``[workflow/job]   | `` prefix from each output line.

    Act prefixes every captured stdout line from a step's ``run:`` block,
    which gets in the way of regex assertions on the script's actual output.
    Lines that don't carry the prefix (act's own status lines) pass through.
    """
    cleaned = []
    for line in text.splitlines():
        m = _ACT_LINE_PREFIX_RE.match(line)
        cleaned.append(m.group(1) if m else line)
    return "\n".join(cleaned)


def _append_act_result(case_name: str, proc: subprocess.CompletedProcess) -> None:
    """Append delimited act output to act-result.txt."""
    sep = "=" * 80
    body = (
        f"\n{sep}\n"
        f"CASE: {case_name}\n"
        f"EXIT_CODE: {proc.returncode}\n"
        f"{sep}\n"
        f"--- STDOUT ---\n{proc.stdout}\n"
        f"--- STDERR ---\n{proc.stderr}\n"
    )
    with ACT_RESULT_FILE.open("a") as f:
        f.write(body)


# ---------------------------------------------------------------------------
# Session-level setup: clean act-result.txt at the start of the session.
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session", autouse=True)
def _reset_act_result_file():
    if ACT_RESULT_FILE.exists():
        ACT_RESULT_FILE.unlink()
    ACT_RESULT_FILE.write_text(
        f"# act-result.txt — generated by tests/test_workflow.py\n"
        f"# Each case run is delimited by a row of '=' and tagged with CASE: <name>\n"
    )
    yield


# ---------------------------------------------------------------------------
# Workflow structure tests (cheap, no act).
# ---------------------------------------------------------------------------

def test_workflow_yaml_parses_and_has_expected_structure():
    """Workflow file is valid YAML and declares the expected triggers/jobs."""
    import yaml  # PyYAML ships with most python envs; if not, pip install pyyaml.

    data = yaml.safe_load(WORKFLOW_FILE.read_text())
    # PyYAML parses bare ``on:`` as the boolean True key, so accept either.
    triggers = data.get("on", data.get(True))
    assert triggers is not None, "Workflow has no 'on:' triggers"
    # Accept dict or list/string forms.
    if isinstance(triggers, dict):
        trigger_keys = set(triggers.keys())
    elif isinstance(triggers, list):
        trigger_keys = set(triggers)
    else:
        trigger_keys = {triggers}
    assert "push" in trigger_keys, f"Expected 'push' trigger; got {trigger_keys}"

    assert "jobs" in data and data["jobs"], "Workflow has no jobs"
    job = next(iter(data["jobs"].values()))
    assert "runs-on" in job
    step_uses = [s.get("uses", "") for s in job["steps"]]
    assert any(u.startswith("actions/checkout@") for u in step_uses), \
        "Workflow must check out the repo with actions/checkout"


def test_workflow_references_existing_files():
    text = WORKFLOW_FILE.read_text()
    assert "bumper.py" in text, "Workflow does not reference bumper.py"
    # Files referenced must exist in the project repo.
    assert (ROOT / "bumper.py").exists()
    assert (ROOT / "fixtures" / "commits.txt").exists()
    assert (ROOT / "package.json").exists()


def test_actionlint_passes():
    """actionlint must report no errors against the workflow."""
    proc = subprocess.run(
        ["actionlint", str(WORKFLOW_FILE)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, (
        f"actionlint failed (exit {proc.returncode}):\n"
        f"STDOUT:\n{proc.stdout}\n"
        f"STDERR:\n{proc.stderr}"
    )


# ---------------------------------------------------------------------------
# End-to-end act-driven test cases.
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("case", CASES, ids=[c["name"] for c in CASES])
def test_act_workflow_case(case, tmp_path):
    """One ``act push`` invocation per scenario, with exact-value asserts."""
    workdir = _build_case_repo(tmp_path, case)
    proc = _run_act(workdir)
    _append_act_result(case["name"], proc)

    raw_output = proc.stdout + "\n" + proc.stderr
    output = _strip_act_prefix(raw_output)

    # 1. act exited cleanly.
    assert proc.returncode == 0, (
        f"act failed for '{case['name']}' (exit {proc.returncode}); "
        f"see act-result.txt"
    )

    # 2. The job actually ran successfully.
    assert "Job succeeded" in output, (
        f"'Job succeeded' marker missing for '{case['name']}'"
    )

    # 3. Exact new-version assertion (parsed from delimited output block).
    m = re.search(
        r"===NEW_VERSION_START===\s*\n([^\n]+)\n===NEW_VERSION_END===",
        output,
    )
    assert m, f"NEW_VERSION block not found in act output for '{case['name']}'"
    actual_version = m.group(1).strip()
    assert actual_version == case["expected_version"], (
        f"Expected version {case['expected_version']!r} for '{case['name']}'; "
        f"got {actual_version!r}"
    )

    # 4. Exact package.json version assertion.
    m_pkg = re.search(
        r"===PACKAGE_JSON_VERSION_START===\s*\n([^\n]+)\n===PACKAGE_JSON_VERSION_END===",
        output,
    )
    assert m_pkg, f"PACKAGE_JSON_VERSION block not found for '{case['name']}'"
    pkg_version = m_pkg.group(1).strip()
    assert pkg_version == case["expected_version"], (
        f"package.json version mismatch for '{case['name']}': "
        f"expected {case['expected_version']!r}, got {pkg_version!r}"
    )

    # 5. Changelog: when a real bump happened, the section + subject must appear.
    m_cl = re.search(
        r"===CHANGELOG_START===\s*\n(.*?)\n===CHANGELOG_END===",
        output,
        re.DOTALL,
    )
    assert m_cl, f"CHANGELOG block missing for '{case['name']}'"
    changelog = m_cl.group(1)
    if case["expected_section"]:
        assert case["expected_section"] in changelog, (
            f"Expected section '{case['expected_section']}' in changelog "
            f"for '{case['name']}'; changelog was:\n{changelog}"
        )
        assert case["expected_subject"] in changelog, (
            f"Expected subject '{case['expected_subject']}' in changelog "
            f"for '{case['name']}'"
        )
        assert f"## {case['expected_version']} - {BUMP_DATE}" in changelog, (
            f"Expected version+date heading in changelog for '{case['name']}'"
        )
    else:
        # No-bump path: changelog should still be present but without a new heading.
        assert "## " not in changelog, (
            f"Unexpected version heading in changelog for no-bump case "
            f"'{case['name']}':\n{changelog}"
        )
