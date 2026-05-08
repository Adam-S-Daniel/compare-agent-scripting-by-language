#!/usr/bin/env python3
"""End-to-end test harness for the secret-rotation-validator workflow.

Runs three test cases through `act push --rm`, capturing each invocation's
output into `act-result.txt`. Also runs structural tests (workflow YAML
shape, file path references, actionlint exit code) which do NOT require an
act invocation.

Why three test cases (not more): the benchmark caps act runs at 3. Each
case below exercises a distinct concern:

  1. mixed-markdown-14d  — golden-path markdown output; covers all 3 buckets
                           (expired/warning/ok) and exact count + table rows.
  2. mixed-json-120d     — JSON format and a custom (longer) warning window;
                           exercises configurability and output format.
  3. all-ok-markdown-14d — only OK secrets; exercises the empty-group
                           rendering path.

Together they cover both formats, both fixtures, custom warning window,
and all three urgency outcomes — including the empty-group edge case.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import List


REPO_ROOT = Path(__file__).resolve().parent
ACT_RESULT = REPO_ROOT / "act-result.txt"
WORKFLOW_FILE = REPO_ROOT / ".github" / "workflows" / "secret-rotation-validator.yml"

# act prefixes shell-stdout lines as `[Workflow/Job]   | <content>`. Capture
# everything after the `|` so we can reconstruct the script's raw output.
SHELL_LINE_RE = re.compile(r"^\[[^\]]+\]\s*\|\s?(.*)$")


# ---------- Test cases ----------

TEST_CASES = [
    {
        "name": "mixed-markdown-14d",
        "env": {
            "FIXTURE": "secrets-mixed.json",
            "FORMAT": "markdown",
            "WARNING_DAYS": "14",
            "REFERENCE_DATE": "2026-05-07",
        },
        # Substrings expected verbatim in validator output.
        "expected_markdown_lines": [
            "# Secret Rotation Report",
            "Generated: 2026-05-07",
            "Warning window: 14 days",
            "Total secrets: 3 (1 expired, 1 warning, 1 ok)",
            "## Expired (1)",
            "## Warning (1)",
            "## OK (1)",
            "| DATABASE_PASSWORD | 2026-01-01 | 2026-01-31 | 96 | api, worker |",
            "| API_KEY | 2026-04-15 | 2026-05-15 | 8 | public-api |",
            "| JWT_SECRET | 2026-05-01 | 2026-07-30 | 84 | auth |",
        ],
    },
    {
        "name": "mixed-json-120d",
        "env": {
            "FIXTURE": "secrets-mixed.json",
            "FORMAT": "json",
            "WARNING_DAYS": "120",
            "REFERENCE_DATE": "2026-05-07",
        },
        # With warning_days=120, JWT_SECRET (84d out) joins the warning bucket.
        "expected_json_summary": {
            "total": 3,
            "expired": 1,
            "warning": 2,
            "ok": 0,
        },
        "expected_json_warning_days": 120,
        "expected_expired_names": ["DATABASE_PASSWORD"],
        "expected_warning_names_sorted": ["API_KEY", "JWT_SECRET"],  # by days_until_due
    },
    {
        "name": "all-ok-markdown-14d",
        "env": {
            "FIXTURE": "secrets-all-ok.json",
            "FORMAT": "markdown",
            "WARNING_DAYS": "14",
            "REFERENCE_DATE": "2026-05-07",
        },
        "expected_markdown_lines": [
            "Total secrets: 2 (0 expired, 0 warning, 2 ok)",
            "## Expired (0)",
            "## Warning (0)",
            "## OK (2)",
            "_No secrets in this group._",  # empty-group rendering
            "| TLS_CERT | 2026-04-01 |",
            "| SIGNING_KEY | 2026-05-01 |",
        ],
    },
]


# ---------- Helpers ----------

def _strip_act_prefix(line: str) -> str:
    m = SHELL_LINE_RE.match(line)
    return m.group(1) if m else line


def _extract_validator_output(stdout: str) -> str:
    """Pull lines between BEGIN_VALIDATOR_OUTPUT / END_VALIDATOR_OUTPUT markers,
    after stripping act's `[Workflow/Job]  |` prefix."""
    in_block = False
    captured: List[str] = []
    for raw in stdout.splitlines():
        content = _strip_act_prefix(raw)
        if "BEGIN_VALIDATOR_OUTPUT" in content:
            in_block = True
            continue
        if "END_VALIDATOR_OUTPUT" in content:
            in_block = False
            continue
        if in_block:
            captured.append(content)
    return "\n".join(captured)


def _setup_temp_repo() -> Path:
    """Create a temp git repo with all project files. Returns the repo path.

    Caller is responsible for cleanup; we deliberately keep it on disk so a
    failed run can be inspected.
    """
    tmp = Path(tempfile.mkdtemp(prefix="secret-rotation-act-"))
    for item in [".github", "src", "tests", ".actrc"]:
        src = REPO_ROOT / item
        dst = tmp / item
        if not src.exists():
            continue
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy(src, dst)
    # `act` requires a git repo — initialize and commit so it has HEAD.
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t.t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t.t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=tmp, check=True, env=env)
    return tmp


def _append_to_act_result(case_name: str, cmd: list, result: subprocess.CompletedProcess) -> None:
    sep = "=" * 70
    with ACT_RESULT.open("a") as f:
        f.write(f"\n{sep}\nTEST CASE: {case_name}\n{sep}\n")
        f.write(f"Command: {' '.join(cmd)}\n")
        f.write(f"Exit code: {result.returncode}\n")
        f.write(f"\n--- STDOUT ---\n{result.stdout}\n")
        f.write(f"\n--- STDERR ---\n{result.stderr}\n")
        f.write(f"\n{sep}\nEND TEST CASE: {case_name}\n{sep}\n")


def _run_act_for_case(repo: Path, case: dict) -> subprocess.CompletedProcess:
    """Invoke act for one test case. Returns the completed process.

    `--pull=false` keeps act from trying to docker-pull the locally-built
    `act-ubuntu-pwsh` image, which has no remote registry counterpart.
    """
    cmd = ["act", "push", "--rm", "--pull=false"]
    for k, v in case["env"].items():
        cmd.extend(["--env", f"{k}={v}"])
    print(f"[harness] running act for case '{case['name']}'...")
    return subprocess.run(cmd, cwd=repo, capture_output=True, text=True, timeout=600)


# ---------- Test classes ----------

class StructuralTests(unittest.TestCase):
    """Static checks: workflow YAML shape, file refs, actionlint."""

    def test_workflow_file_exists(self):
        self.assertTrue(WORKFLOW_FILE.is_file(), f"missing workflow: {WORKFLOW_FILE}")

    def test_workflow_yaml_parses(self):
        try:
            import yaml  # standard on Ubuntu CI but not always; fallback below.
        except ImportError:
            self.skipTest("PyYAML not installed; YAML structure check requires it")
        data = yaml.safe_load(WORKFLOW_FILE.read_text())
        # `on:` is a YAML reserved word that PyYAML loads as bool True.
        triggers = data.get(True, data.get("on"))
        self.assertIn("push", triggers)
        self.assertIn("pull_request", triggers)
        self.assertIn("schedule", triggers)
        self.assertIn("workflow_dispatch", triggers)
        self.assertIn("test", data["jobs"])
        self.assertIn("validate", data["jobs"])
        self.assertEqual(data["jobs"]["validate"]["needs"], "test")

    def test_workflow_references_existing_paths(self):
        """The workflow must reference src/secret_rotation.py and the fixture
        directory — both should exist on disk."""
        text = WORKFLOW_FILE.read_text()
        self.assertIn("src/secret_rotation.py", text)
        self.assertIn("tests/fixtures/", text)
        self.assertTrue((REPO_ROOT / "src" / "secret_rotation.py").is_file())
        self.assertTrue((REPO_ROOT / "tests" / "fixtures" / "secrets-mixed.json").is_file())
        self.assertTrue((REPO_ROOT / "tests" / "fixtures" / "secrets-all-ok.json").is_file())

    def test_actionlint_passes(self):
        """actionlint should exit 0 — assert it does."""
        if shutil.which("actionlint") is None:
            self.skipTest("actionlint not available")
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_FILE)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0,
                         f"actionlint failed:\n{result.stdout}\n{result.stderr}")


class ActIntegrationTests(unittest.TestCase):
    """End-to-end: run the workflow under act, assert exact output values."""

    @classmethod
    def setUpClass(cls):
        # Clear act-result.txt and produce one combined transcript across cases.
        ACT_RESULT.write_text("# act test transcript — run_act_tests.py\n")
        cls.repo = _setup_temp_repo()
        cls.case_results = {}
        for case in TEST_CASES:
            cp = _run_act_for_case(cls.repo, case)
            _append_to_act_result(case["name"], ["act", "push", "--rm"], cp)
            cls.case_results[case["name"]] = cp

    def _result(self, name: str) -> subprocess.CompletedProcess:
        return self.case_results[name]

    # ---- Per-case assertions ----

    def test_act_exit_code_zero_for_all_cases(self):
        for case in TEST_CASES:
            with self.subTest(case=case["name"]):
                cp = self._result(case["name"])
                self.assertEqual(
                    cp.returncode, 0,
                    f"act exited {cp.returncode} for {case['name']}\n"
                    f"--- stdout ---\n{cp.stdout[-2000:]}\n"
                    f"--- stderr ---\n{cp.stderr[-2000:]}",
                )

    def test_every_job_succeeded(self):
        for case in TEST_CASES:
            with self.subTest(case=case["name"]):
                stdout = self._result(case["name"]).stdout
                # Each workflow has two jobs (test, validate). Each should
                # report a "Job succeeded" line in act's output.
                count = stdout.count("Job succeeded")
                self.assertGreaterEqual(
                    count, 2,
                    f"expected >=2 'Job succeeded' lines for {case['name']}, got {count}",
                )

    def test_pytest_unit_tests_passed_in_test_job(self):
        """The 'test' job runs pytest; assert it reported all 28 tests passing."""
        for case in TEST_CASES:
            with self.subTest(case=case["name"]):
                stdout = self._result(case["name"]).stdout
                self.assertIn("28 passed", stdout,
                              f"pytest didn't show 28 passed for {case['name']}")

    def test_mixed_markdown_14d_exact_output(self):
        out = _extract_validator_output(self._result("mixed-markdown-14d").stdout)
        for line in next(c for c in TEST_CASES
                         if c["name"] == "mixed-markdown-14d")["expected_markdown_lines"]:
            self.assertIn(line, out, f"expected line not found: {line!r}\nGOT:\n{out}")

    def test_mixed_json_120d_exact_summary(self):
        out = _extract_validator_output(self._result("mixed-json-120d").stdout)
        # Validator JSON output must round-trip through json.loads.
        parsed = json.loads(out)
        case = next(c for c in TEST_CASES if c["name"] == "mixed-json-120d")
        self.assertEqual(parsed["summary"], case["expected_json_summary"])
        self.assertEqual(parsed["warning_days"], case["expected_json_warning_days"])
        self.assertEqual([s["name"] for s in parsed["expired"]], case["expected_expired_names"])
        self.assertEqual([s["name"] for s in parsed["warning"]],
                         case["expected_warning_names_sorted"])
        self.assertEqual(parsed["expired"][0]["days_overdue"], 96)
        self.assertEqual(parsed["expired"][0]["due_date"], "2026-01-31")
        # JWT_SECRET should now be in warning, due 2026-07-30, 84 days out.
        jwt = next(s for s in parsed["warning"] if s["name"] == "JWT_SECRET")
        self.assertEqual(jwt["due_date"], "2026-07-30")
        self.assertEqual(jwt["days_until_due"], 84)

    def test_all_ok_markdown_14d_exact_output(self):
        out = _extract_validator_output(self._result("all-ok-markdown-14d").stdout)
        case = next(c for c in TEST_CASES if c["name"] == "all-ok-markdown-14d")
        for line in case["expected_markdown_lines"]:
            self.assertIn(line, out, f"expected line not found: {line!r}\nGOT:\n{out}")
        # Empty-group placeholder must appear under both Expired and Warning,
        # so the marker count >= 2.
        self.assertGreaterEqual(out.count("_No secrets in this group._"), 2)


# ---------- Entry point ----------

def main() -> int:
    # We split into two passes: structural tests first (cheap, fail fast),
    # then the act integration tests (~minutes per run).
    loader = unittest.TestLoader()
    suite = unittest.TestSuite([
        loader.loadTestsFromTestCase(StructuralTests),
        loader.loadTestsFromTestCase(ActIntegrationTests),
    ])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
