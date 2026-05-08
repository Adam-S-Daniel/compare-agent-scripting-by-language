"""
Test harness for the environment matrix generator.

All functional tests run through the GitHub Actions workflow via `act`.
Workflow structure tests validate YAML, file existence, and actionlint.

TDD approach: these tests were written FIRST (failing), then generate_matrix.py
was implemented to make them pass.
"""

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest
import yaml

# Project root relative to this test file
PROJECT_ROOT = Path(__file__).parent.parent
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "environment-matrix-generator.yml"
SCRIPT_PATH = PROJECT_ROOT / "generate_matrix.py"
FIXTURES_DIR = PROJECT_ROOT / "fixtures"
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def setup_temp_repo(fixture_name: str) -> Path:
    """Copy project files + named fixture into a fresh temp git repo."""
    tmpdir = Path(tempfile.mkdtemp(prefix="matrix-test-"))

    # Copy project files
    for src in [SCRIPT_PATH, WORKFLOW_PATH]:
        rel = src.relative_to(PROJECT_ROOT)
        dst = tmpdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Copy .actrc so act uses the right platform image
    actrc = PROJECT_ROOT / ".actrc"
    if actrc.exists():
        shutil.copy2(actrc, tmpdir / ".actrc")

    # Copy the fixture as matrix-config.json (the workflow looks for this file)
    fixture_src = FIXTURES_DIR / fixture_name
    shutil.copy2(fixture_src, tmpdir / "matrix-config.json")

    # Initialise git repo
    subprocess.run(["git", "init"], cwd=tmpdir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=tmpdir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmpdir, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=tmpdir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "test"], cwd=tmpdir, check=True, capture_output=True)

    return tmpdir


def run_act(tmpdir: Path) -> tuple[int, str]:
    """Run `act push --rm` in tmpdir and return (exit_code, output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


def append_act_result(label: str, output: str, exit_code: int) -> None:
    """Append one test case's act output to act-result.txt."""
    with open(ACT_RESULT_FILE, "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"TEST CASE: {label}\n")
        f.write(f"EXIT CODE: {exit_code}\n")
        f.write(f"{'='*60}\n")
        f.write(output)
        f.write(f"\n{'='*60} END {label} {'='*60}\n")


# ---------------------------------------------------------------------------
# Workflow structure tests (no act required, instant)
# ---------------------------------------------------------------------------

class TestWorkflowStructure:
    def test_workflow_file_exists(self):
        assert WORKFLOW_PATH.exists(), f"Workflow file not found: {WORKFLOW_PATH}"

    def test_script_file_exists(self):
        assert SCRIPT_PATH.exists(), f"Script file not found: {SCRIPT_PATH}"

    def test_workflow_valid_yaml(self):
        content = WORKFLOW_PATH.read_text()
        parsed = yaml.safe_load(content)
        assert parsed is not None

    def test_workflow_has_push_trigger(self):
        parsed = yaml.safe_load(WORKFLOW_PATH.read_text())
        # YAML parses `on:` as boolean True; check both keys
        triggers = parsed.get("on", parsed.get(True, {})) or {}
        assert "push" in triggers, "Workflow must have a push trigger"

    def test_workflow_has_jobs(self):
        parsed = yaml.safe_load(WORKFLOW_PATH.read_text())
        assert "jobs" in parsed, "Workflow must have jobs"
        assert len(parsed["jobs"]) >= 1

    def test_workflow_has_checkout_step(self):
        parsed = yaml.safe_load(WORKFLOW_PATH.read_text())
        all_steps = []
        for job in parsed["jobs"].values():
            all_steps.extend(job.get("steps", []))
        uses_values = [s.get("uses", "") for s in all_steps]
        assert any("actions/checkout" in u for u in uses_values), \
            "Workflow must include actions/checkout"

    def test_workflow_references_script(self):
        content = WORKFLOW_PATH.read_text()
        assert "generate_matrix.py" in content, \
            "Workflow must reference generate_matrix.py"

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, \
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"

    def test_fixtures_exist(self):
        for fixture in ["basic-config.json", "exclude-config.json",
                        "include-config.json", "full-config.json",
                        "overflow-config.json"]:
            assert (FIXTURES_DIR / fixture).exists(), f"Fixture missing: {fixture}"

    def test_fixtures_are_valid_json(self):
        for fixture in FIXTURES_DIR.glob("*.json"):
            data = json.loads(fixture.read_text())
            assert isinstance(data, dict), f"{fixture.name} must be a JSON object"


# ---------------------------------------------------------------------------
# Act-based functional tests
# ---------------------------------------------------------------------------

class TestActFunctional:
    """Each method sets up a temp git repo, runs act, asserts on exact output."""

    def test_basic_matrix(self):
        """2 OS x 2 python-version = 4 combinations, fail-fast: false."""
        tmpdir = setup_temp_repo("basic-config.json")
        try:
            exit_code, output = run_act(tmpdir)
            append_act_result("basic-config", output, exit_code)

            assert exit_code == 0, f"act exited {exit_code}:\n{output}"
            assert "Job succeeded" in output, f"Job did not succeed:\n{output}"

            # Extract JSON output from the act log
            matrix_json = _extract_matrix_json(output)
            assert matrix_json is not None, f"No MATRIX_JSON found in output:\n{output}"

            assert matrix_json["fail-fast"] is False
            assert matrix_json["_total_combinations"] == 4
            assert "ubuntu-latest" in matrix_json["matrix"]["os"]
            assert "windows-latest" in matrix_json["matrix"]["os"]
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    def test_exclude_rules(self):
        """4 combinations minus 1 excluded = 3 effective combinations."""
        tmpdir = setup_temp_repo("exclude-config.json")
        try:
            exit_code, output = run_act(tmpdir)
            append_act_result("exclude-config", output, exit_code)

            assert exit_code == 0, f"act exited {exit_code}:\n{output}"
            assert "Job succeeded" in output

            matrix_json = _extract_matrix_json(output)
            assert matrix_json is not None, f"No MATRIX_JSON found:\n{output}"

            # 4 base - 1 excluded = 3
            assert matrix_json["_total_combinations"] == 3
            assert len(matrix_json["matrix"]["exclude"]) == 1
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    def test_include_rules(self):
        """1 base combination + 1 include entry = 2 total."""
        tmpdir = setup_temp_repo("include-config.json")
        try:
            exit_code, output = run_act(tmpdir)
            append_act_result("include-config", output, exit_code)

            assert exit_code == 0, f"act exited {exit_code}:\n{output}"
            assert "Job succeeded" in output

            matrix_json = _extract_matrix_json(output)
            assert matrix_json is not None, f"No MATRIX_JSON found:\n{output}"

            assert matrix_json["_total_combinations"] == 2
            assert len(matrix_json["matrix"]["include"]) == 1
            assert matrix_json["matrix"]["include"][0].get("experimental") is True
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    def test_full_config(self):
        """2 OS x 3 python-version x 2 debug = 12, minus 3 excluded = 9, max-parallel=4."""
        tmpdir = setup_temp_repo("full-config.json")
        try:
            exit_code, output = run_act(tmpdir)
            append_act_result("full-config", output, exit_code)

            assert exit_code == 0, f"act exited {exit_code}:\n{output}"
            assert "Job succeeded" in output

            matrix_json = _extract_matrix_json(output)
            assert matrix_json is not None, f"No MATRIX_JSON found:\n{output}"

            assert matrix_json["_total_combinations"] == 9
            assert matrix_json["max-parallel"] == 4
            assert matrix_json["fail-fast"] is False
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    def test_overflow_validation(self):
        """Config that exceeds max-size should output an error message."""
        tmpdir = setup_temp_repo("overflow-config.json")
        try:
            exit_code, output = run_act(tmpdir)
            append_act_result("overflow-config", output, exit_code)

            # The job uses continue-on-error, so act still exits 0
            assert exit_code == 0, f"act exited {exit_code}:\n{output}"
            assert "Job succeeded" in output

            # The error message should appear in the output
            assert "exceeds maximum" in output, \
                f"Expected 'exceeds maximum' error in output:\n{output}"
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)


# ---------------------------------------------------------------------------
# JSON extraction helper
# ---------------------------------------------------------------------------

def _strip_act_prefix(line: str) -> str:
    """Strip the act log prefix like '[Job/step]   | ' from a line."""
    # Act output lines look like: "[Job/step]   | actual content"
    if "]" in line:
        after_bracket = line[line.index("]") + 1:]
        # Strip leading whitespace and the pipe separator
        stripped = after_bracket.lstrip()
        if stripped.startswith("|"):
            return stripped[1:].lstrip()
        return stripped
    return line


def _extract_matrix_json(output: str) -> dict | None:
    """Parse the MATRIX_JSON marker from act output, handling act's line prefix."""
    lines = output.splitlines()
    marker = "MATRIX_JSON:"
    for i, line in enumerate(lines):
        if marker in line:
            json_lines = []
            depth = 0
            started = False
            for raw in lines[i + 1:]:
                content = _strip_act_prefix(raw)
                if not started:
                    if content.startswith("{"):
                        started = True
                    else:
                        continue
                json_lines.append(content)
                depth += content.count("{") - content.count("}")
                if started and depth <= 0:
                    break
            if json_lines:
                try:
                    return json.loads("\n".join(json_lines))
                except json.JSONDecodeError:
                    pass
    return None
