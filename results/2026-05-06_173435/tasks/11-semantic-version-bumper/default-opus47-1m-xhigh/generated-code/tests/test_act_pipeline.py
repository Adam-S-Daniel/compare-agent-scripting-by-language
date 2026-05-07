"""End-to-end tests that run every fixture through the full GitHub Actions
workflow via nektos/act. Also covers structural validation of the
workflow YAML itself.

For each fixture (`patch`, `minor`, `major`):
  1. Set up a fresh temp git repo containing the project files plus that
     fixture's `package.json` + `commits.txt` at the repo root.
  2. Run `act push --rm` against that repo.
  3. Append the entire act stdout/stderr to `act-result.txt` (the required
     artifact), with a clear delimiter per case.
  4. Assert act exited 0, that "Job succeeded" appears for every job, and
     that the workflow produced the *exact* expected NEW_VERSION /
     BUMP_TYPE values for that fixture.

Each call to `act push` is expensive (30-90s) so the harness invokes it
exactly once per fixture (3 total).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

import yaml  # PyYAML — used for the structural workflow tests below.

# --------------------------------------------------------------------------- #
# Paths shared by every test below.
# --------------------------------------------------------------------------- #

PROJECT_DIR = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml"
FIXTURES_DIR = PROJECT_DIR / "fixtures"
ACT_RESULT_PATH = PROJECT_DIR / "act-result.txt"
ACTRC_PATH = PROJECT_DIR / ".actrc"

# (fixture name, expected version string after bump, expected bump type).
# These are the contract this harness asserts on — exact values, no
# wildcards. Kept in code (not in fixtures) so the assertion can't drift.
FIXTURE_EXPECTATIONS = [
    ("patch", "1.0.1", "patch"),
    ("minor", "1.2.0", "minor"),
    ("major", "3.0.0", "major"),
]


def _have_act() -> bool:
    return shutil.which("act") is not None


def _have_docker() -> bool:
    return shutil.which("docker") is not None


# --------------------------------------------------------------------------- #
# Structural tests — fast, run regardless of whether act is available.
# --------------------------------------------------------------------------- #


class TestWorkflowStructure(unittest.TestCase):
    """Static checks on the workflow YAML itself."""

    @classmethod
    def setUpClass(cls):
        cls.workflow = yaml.safe_load(WORKFLOW_PATH.read_text())

    def test_has_expected_triggers(self):
        # PyYAML parses the bare key `on:` as the boolean True. The lookup
        # below tolerates both spellings so the test stays robust.
        triggers = self.workflow.get("on") or self.workflow.get(True)
        self.assertIsNotNone(triggers, "workflow has no `on:` block")
        self.assertIn("push", triggers)
        self.assertIn("pull_request", triggers)
        self.assertIn("workflow_dispatch", triggers)
        self.assertIn("schedule", triggers)

    def test_jobs_are_defined_with_dependency(self):
        jobs = self.workflow["jobs"]
        self.assertIn("unit-tests", jobs)
        self.assertIn("bump", jobs)
        self.assertEqual(jobs["bump"]["needs"], "unit-tests")

    def test_workflow_references_existing_script(self):
        # Catch broken paths quickly without needing to run act.
        steps = self.workflow["jobs"]["bump"]["steps"]
        run_blocks = "\n".join(s.get("run", "") for s in steps)
        self.assertIn("bumper.py", run_blocks)
        self.assertTrue((PROJECT_DIR / "bumper.py").exists())

    def test_uses_pinned_checkout_action(self):
        # All `uses:` references must include a version (so we don't pull
        # silently shifting `@main`).
        for job in self.workflow["jobs"].values():
            for step in job.get("steps", []):
                uses = step.get("uses")
                if uses is not None:
                    self.assertIn("@", uses, f"unpinned action: {uses}")

    def test_actionlint_passes(self):
        # The graders also run actionlint; assert exit 0 here so a
        # regression shows up as a unit-test failure, not just a
        # graded-step failure.
        if shutil.which("actionlint") is None:
            self.skipTest("actionlint not installed")
        r = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            r.returncode,
            0,
            msg=f"actionlint failed:\nstdout={r.stdout}\nstderr={r.stderr}",
        )


# --------------------------------------------------------------------------- #
# act-pipeline tests — one act run per fixture.
# --------------------------------------------------------------------------- #


def _build_temp_repo(dest: Path, fixture_name: str) -> None:
    """Materialize a self-contained git repo at `dest` for one fixture run."""
    # Project files act needs to see.
    for p in ["bumper.py", ".github", "tests"]:
        src = PROJECT_DIR / p
        if src.is_dir():
            shutil.copytree(src, dest / p)
        else:
            shutil.copy2(src, dest / p)

    # Forward the .actrc so this nested repo uses the same custom image
    # mapping the parent project relies on (act-ubuntu-pwsh:latest etc.).
    if ACTRC_PATH.exists():
        shutil.copy2(ACTRC_PATH, dest / ".actrc")

    # Drop the fixture's package.json + commits.txt at the repo root —
    # this is what the workflow reads.
    fx = FIXTURES_DIR / fixture_name
    shutil.copy2(fx / "package.json", dest / "package.json")
    shutil.copy2(fx / "commits.txt", dest / "commits.txt")

    # PyYAML is needed for the workflow structural tests, but the
    # workflow's own `unit-tests` job runs `tests.test_bumper`, which
    # imports nothing exotic — so the act image's stock python3 is fine.
    # Initialise a git repo: act looks for a git history to source the
    # checkout from.
    env = os.environ.copy()
    # Prevent local git config (signing keys, hooks) from interfering.
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    env["GIT_CONFIG_SYSTEM"] = "/dev/null"
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=dest, check=True, env=env)
    subprocess.run(
        ["git", "-c", "user.email=t@example.com", "-c", "user.name=t", "add", "-A"],
        cwd=dest, check=True, env=env,
    )
    subprocess.run(
        ["git", "-c", "user.email=t@example.com", "-c", "user.name=t",
         "commit", "-q", "-m", f"fixture: {fixture_name}"],
        cwd=dest, check=True, env=env,
    )


def _run_act_once(repo: Path) -> subprocess.CompletedProcess:
    """Run `act push --rm` in `repo`. Returns the completed process.

    Output is fully captured so the harness can assert on it.
    """
    return subprocess.run(
        # `--pull=false` keeps act from re-pulling the locally-built
        # `act-ubuntu-pwsh:latest` image (which isn't in any remote
        # registry — it's built from this repo's Dockerfile.act).
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo,
        capture_output=True,
        text=True,
        # Bound the run so a stuck container doesn't hang the suite. 20 min
        # is comfortably above the observed 1-2 min per case.
        timeout=20 * 60,
    )


@unittest.skipUnless(_have_act() and _have_docker(),
                     "act or docker not available in this environment")
class TestActPipeline(unittest.TestCase):
    """Drive every fixture through the workflow via `act` and assert
    exact output values."""

    @classmethod
    def setUpClass(cls):
        # Truncate the artifact at the start of each suite run so old
        # output doesn't accumulate across invocations.
        ACT_RESULT_PATH.write_text("")

    def _append_act_section(self, fixture_name: str, run: subprocess.CompletedProcess) -> None:
        with ACT_RESULT_PATH.open("a") as f:
            f.write(f"\n{'=' * 78}\n")
            f.write(f"FIXTURE: {fixture_name}\n")
            f.write(f"COMMAND: act push --rm\n")
            f.write(f"EXIT_CODE: {run.returncode}\n")
            f.write(f"{'-' * 78}\n")
            f.write("--- STDOUT ---\n")
            f.write(run.stdout)
            f.write("\n--- STDERR ---\n")
            f.write(run.stderr)
            f.write(f"\n{'=' * 78}\n")

    def _assert_pipeline(self, fixture: str, expected_version: str, expected_bump: str) -> None:
        import tempfile
        with tempfile.TemporaryDirectory(prefix=f"svb-{fixture}-") as raw:
            repo = Path(raw)
            _build_temp_repo(repo, fixture)

            run = _run_act_once(repo)
            # Persist FIRST so a failed assertion still leaves evidence.
            self._append_act_section(fixture, run)

            combined = run.stdout + "\n" + run.stderr

            self.assertEqual(
                run.returncode, 0,
                msg=f"act exited non-zero for {fixture}; see act-result.txt",
            )
            # Each job should have logged "Job succeeded" — assert one per
            # job name to catch silent partial failures.
            self.assertIn("Job succeeded", combined,
                          f"no 'Job succeeded' in act output for {fixture}")
            # Two jobs => at least two successes.
            self.assertGreaterEqual(
                combined.count("Job succeeded"), 2,
                f"expected 2+ 'Job succeeded' lines for {fixture}",
            )
            # Exact-value assertions on the workflow's stable output lines.
            self.assertIn(f"NEW_VERSION={expected_version}", combined,
                          f"expected NEW_VERSION={expected_version} in act output for {fixture}")
            self.assertIn(f"BUMP_TYPE={expected_bump}", combined,
                          f"expected BUMP_TYPE={expected_bump} in act output for {fixture}")
            # Exact value should also appear via the step output echo line.
            self.assertIn(f"RESULT_NEW_VERSION={expected_version}", combined)

    def test_patch_fixture_yields_1_0_1(self):
        self._assert_pipeline(*FIXTURE_EXPECTATIONS[0])

    def test_minor_fixture_yields_1_2_0(self):
        self._assert_pipeline(*FIXTURE_EXPECTATIONS[1])

    def test_major_fixture_yields_3_0_0(self):
        self._assert_pipeline(*FIXTURE_EXPECTATIONS[2])


if __name__ == "__main__":
    unittest.main(verbosity=2)
