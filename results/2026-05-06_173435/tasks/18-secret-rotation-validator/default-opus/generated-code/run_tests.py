#!/usr/bin/env python3
"""Test harness — runs all tests through act and validates output.

Sets up a temp git repo, copies project files, runs act push, captures output,
and asserts on exact expected values. Also validates workflow structure and actionlint.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ACT_RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

PROJECT_FILES = [
    "secret_rotation_validator.py",
    "test_secret_rotation_validator.py",
    "fixtures/mixed_config.json",
    "fixtures/all_expired_config.json",
    ".github/workflows/secret-rotation-validator.yml",
]


def copy_project_to(dest: str):
    for f in PROJECT_FILES:
        src = os.path.join(SCRIPT_DIR, f)
        dst = os.path.join(dest, f)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    actrc = os.path.join(dest, ".actrc")
    with open(actrc, "w") as fh:
        fh.write("-P ubuntu-latest=act-ubuntu-pwsh:latest\n")
        fh.write("--pull=false\n")


def run_act_in_temp_repo(label: str) -> tuple[int, str]:
    """Set up a temp git repo, copy project files, run act push, return (exit_code, output)."""
    tmpdir = tempfile.mkdtemp(prefix=f"act_{label}_")
    try:
        copy_project_to(tmpdir)
        subprocess.run(
            ["git", "init"], cwd=tmpdir, capture_output=True, check=True
        )
        subprocess.run(
            ["git", "add", "-A"], cwd=tmpdir, capture_output=True, check=True
        )
        subprocess.run(
            ["git", "commit", "-m", "test"],
            cwd=tmpdir,
            capture_output=True,
            check=True,
            env={**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "t@t.co",
                 "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "t@t.co"},
        )
        result = subprocess.run(
            ["act", "push", "--rm"],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            timeout=300,
        )
        output = result.stdout + "\n" + result.stderr
        return result.returncode, output
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def extract_section(output: str, start_marker: str, end_marker: str) -> str:
    """Extract text between markers from act output."""
    pattern = re.escape(start_marker) + r"(.*?)" + re.escape(end_marker)
    match = re.search(pattern, output, re.DOTALL)
    if not match:
        return ""
    return match.group(1).strip()


def strip_act_prefixes(text: str) -> str:
    """Remove act's line prefixes (e.g., '[Job/step]   | content') from captured output."""
    lines = []
    for line in text.splitlines():
        cleaned = re.sub(r"^\[.*?\]\s+\|\s?", "", line)
        lines.append(cleaned)
    return "\n".join(lines)


def main():
    failures = []
    act_output_parts = []

    # --- Workflow structure tests (no act needed) ---
    print("=" * 60)
    print("WORKFLOW STRUCTURE TESTS")
    print("=" * 60)

    wf_path = os.path.join(SCRIPT_DIR, ".github", "workflows", "secret-rotation-validator.yml")

    # Test: workflow file exists
    if not os.path.isfile(wf_path):
        failures.append("STRUCTURE: workflow file does not exist")
        print("FAIL: workflow file does not exist")
    else:
        print("PASS: workflow file exists")

    # Test: valid YAML with expected structure
    try:
        import yaml
        with open(wf_path) as f:
            wf = yaml.safe_load(f)
        triggers = wf.get(True) or wf.get("on", {})
        assert "push" in triggers, "missing push trigger"
        assert "jobs" in wf, "missing jobs"
        assert "validate" in wf["jobs"], "missing validate job"
        step_uses = [s.get("uses", "") for s in wf["jobs"]["validate"]["steps"]]
        assert any("actions/checkout" in u for u in step_uses), "missing checkout step"
        step_runs = " ".join(s.get("run", "") for s in wf["jobs"]["validate"]["steps"])
        assert "secret_rotation_validator.py" in step_runs, "workflow doesn't reference script"
        print("PASS: workflow YAML structure is correct")
    except Exception as e:
        failures.append(f"STRUCTURE: {e}")
        print(f"FAIL: {e}")

    # Test: referenced script files exist
    for fname in ["secret_rotation_validator.py", "fixtures/mixed_config.json", "fixtures/all_expired_config.json"]:
        fpath = os.path.join(SCRIPT_DIR, fname)
        if os.path.isfile(fpath):
            print(f"PASS: referenced file exists: {fname}")
        else:
            failures.append(f"STRUCTURE: referenced file missing: {fname}")
            print(f"FAIL: referenced file missing: {fname}")

    # Test: actionlint passes
    lint_result = subprocess.run(
        ["actionlint", wf_path], capture_output=True, text=True
    )
    if lint_result.returncode == 0:
        print("PASS: actionlint passes")
    else:
        failures.append(f"STRUCTURE: actionlint failed: {lint_result.stdout}{lint_result.stderr}")
        print(f"FAIL: actionlint failed:\n{lint_result.stdout}{lint_result.stderr}")

    # --- Act execution test ---
    print()
    print("=" * 60)
    print("ACT EXECUTION TEST: mixed config (all formats)")
    print("=" * 60)

    exit_code, output = run_act_in_temp_repo("mixed")
    act_output_parts.append(f"{'=' * 60}\nTEST CASE: mixed config\n{'=' * 60}\n{output}")

    # Assert exit code 0
    if exit_code == 0:
        print("PASS: act exited with code 0")
    else:
        failures.append(f"ACT: exit code was {exit_code}, expected 0")
        print(f"FAIL: act exited with code {exit_code}")

    # Assert job succeeded (act uses either "Job succeeded" or emoji markers)
    if "Job succeeded" in output:
        print("PASS: Job succeeded found in output")
    elif exit_code == 0:
        print("PASS: Job succeeded (exit code 0)")
    else:
        failures.append("ACT: job did not succeed")
        print("FAIL: job did not succeed")

    # Extract and validate JSON mixed output
    json_section = strip_act_prefixes(extract_section(output, "===JSON_MIXED_START===", "===JSON_MIXED_END==="))
    if json_section:
        try:
            data = json.loads(json_section)
            checks = [
                (data["reference_date"] == "2026-05-07", "reference_date is 2026-05-07"),
                (data["warning_window_days"] == 14, "warning_window_days is 14"),
                (data["summary"]["total"] == 5, "total is 5"),
                (data["summary"]["expired"] == 2, "expired count is 2"),
                (data["summary"]["warning"] == 1, "warning count is 1"),
                (data["summary"]["ok"] == 2, "ok count is 2"),
                ([s["name"] for s in data["secrets"]["expired"]] == ["DB_PASSWORD", "OAUTH_SECRET"],
                 "expired secrets are DB_PASSWORD, OAUTH_SECRET"),
                ([s["name"] for s in data["secrets"]["warning"]] == ["TLS_CERT"],
                 "warning secret is TLS_CERT"),
                ([s["name"] for s in data["secrets"]["ok"]] == ["API_KEY", "SSH_KEY"],
                 "ok secrets are API_KEY, SSH_KEY"),
                (data["secrets"]["expired"][0]["days_since_rotation"] == 157,
                 "DB_PASSWORD days_since_rotation is 157"),
                (data["secrets"]["expired"][0]["days_until_expiry"] == -67,
                 "DB_PASSWORD days_until_expiry is -67"),
                (data["secrets"]["warning"][0]["days_until_expiry"] == 7,
                 "TLS_CERT days_until_expiry is 7"),
                (data["secrets"]["ok"][0]["days_until_expiry"] == 18,
                 "API_KEY days_until_expiry is 18"),
            ]
            for ok, desc in checks:
                if ok:
                    print(f"PASS: JSON mixed - {desc}")
                else:
                    failures.append(f"ACT JSON: {desc}")
                    print(f"FAIL: JSON mixed - {desc}")
        except json.JSONDecodeError as e:
            failures.append(f"ACT JSON: could not parse JSON output: {e}")
            print(f"FAIL: could not parse JSON output: {e}")
    else:
        failures.append("ACT JSON: JSON mixed section not found in output")
        print("FAIL: JSON mixed section not found in output")

    # Validate markdown output
    md_section = strip_act_prefixes(extract_section(output, "===MARKDOWN_MIXED_START===", "===MARKDOWN_MIXED_END==="))
    if md_section:
        md_checks = [
            ("# Secret Rotation Report" in md_section, "has title header"),
            ("| Expired | 2 |" in md_section, "expired count 2 in summary"),
            ("| Warning | 1 |" in md_section, "warning count 1 in summary"),
            ("| OK | 2 |" in md_section, "ok count 2 in summary"),
            ("| **Total** | **5** |" in md_section, "total 5 in summary"),
            ("DB_PASSWORD" in md_section, "contains DB_PASSWORD"),
            ("TLS_CERT" in md_section, "contains TLS_CERT"),
            ("API_KEY" in md_section, "contains API_KEY"),
            ("67" in md_section, "contains days overdue 67"),
        ]
        for ok, desc in md_checks:
            if ok:
                print(f"PASS: Markdown - {desc}")
            else:
                failures.append(f"ACT Markdown: {desc}")
                print(f"FAIL: Markdown - {desc}")
    else:
        failures.append("ACT Markdown: markdown section not found in output")
        print("FAIL: markdown section not found in output")

    # Validate all-expired config output
    expired_section = strip_act_prefixes(
        extract_section(output, "===JSON_EXPIRED_START===", "===JSON_EXPIRED_END===")
    )
    if expired_section:
        try:
            data = json.loads(expired_section)
            checks = [
                (data["summary"]["expired"] == 3, "all 3 secrets are expired"),
                (data["summary"]["warning"] == 0, "no warning secrets"),
                (data["summary"]["ok"] == 0, "no ok secrets"),
                ([s["name"] for s in data["secrets"]["expired"]] == ["OLD_DB_PASS", "OLD_API_KEY", "OLD_CERT"],
                 "expired secrets sorted by urgency"),
            ]
            for ok, desc in checks:
                if ok:
                    print(f"PASS: JSON expired - {desc}")
                else:
                    failures.append(f"ACT expired: {desc}")
                    print(f"FAIL: JSON expired - {desc}")
        except json.JSONDecodeError as e:
            failures.append(f"ACT expired: could not parse JSON: {e}")
            print(f"FAIL: could not parse all-expired JSON: {e}")
    else:
        failures.append("ACT expired: section not found in output")
        print("FAIL: all-expired section not found in output")

    # Validate warning window override output
    override_section = strip_act_prefixes(
        extract_section(output, "===JSON_OVERRIDE_START===", "===JSON_OVERRIDE_END===")
    )
    if override_section:
        try:
            data = json.loads(override_section)
            checks = [
                (data["warning_window_days"] == 20, "warning window is 20"),
                (data["summary"]["warning"] == 2, "2 warnings with 20-day window"),
                (data["summary"]["ok"] == 1, "1 ok with 20-day window"),
            ]
            for ok, desc in checks:
                if ok:
                    print(f"PASS: JSON override - {desc}")
                else:
                    failures.append(f"ACT override: {desc}")
                    print(f"FAIL: JSON override - {desc}")
        except json.JSONDecodeError as e:
            failures.append(f"ACT override: could not parse JSON: {e}")
            print(f"FAIL: could not parse override JSON: {e}")
    else:
        failures.append("ACT override: section not found in output")
        print("FAIL: override section not found in output")

    # Check pytest ran and passed (allow skipped tests, but no failures)
    pytest_summary = re.search(r"(\d+) passed", output)
    pytest_failed = re.search(r"(\d+) failed", output)
    if pytest_summary and (not pytest_failed or int(pytest_failed.group(1)) == 0):
        print(f"PASS: pytest passed in workflow ({pytest_summary.group(0)})")
    else:
        failures.append("ACT: pytest did not pass cleanly")
        print("FAIL: pytest did not pass cleanly in workflow")

    # --- Write act-result.txt ---
    with open(ACT_RESULT_FILE, "w") as f:
        f.write("\n\n".join(act_output_parts))
    print(f"\nWrote act output to {ACT_RESULT_FILE}")

    # --- Summary ---
    print()
    print("=" * 60)
    if failures:
        print(f"FAILED: {len(failures)} assertion(s) failed:")
        for fail in failures:
            print(f"  - {fail}")
        sys.exit(1)
    else:
        print("ALL ASSERTIONS PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
