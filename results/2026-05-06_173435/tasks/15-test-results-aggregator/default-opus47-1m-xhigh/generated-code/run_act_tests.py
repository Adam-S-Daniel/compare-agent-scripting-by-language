"""act-based test harness.

For each scenario fixture pair, this harness:

    1. Builds an isolated git repo in a tempdir (project files + a
       scenario.txt that selects which fixtures to aggregate).
    2. Runs `act push --rm` against that repo and captures combined
       stdout+stderr.
    3. Appends the captured output to act-result.txt with a delimiter.
    4. Asserts the act exit code is 0.
    5. Asserts every scenario-specific expected substring is present
       (and that scenario-inappropriate substrings are absent).
    6. Asserts "Job succeeded" appears.

Per the task, this is the ONLY end-to-end execution path for the
script — every assertion goes through the GitHub Actions workflow.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

WORKSPACE = Path(__file__).resolve().parent
ACT_RESULT = WORKSPACE / "act-result.txt"


@dataclass
class Expectation:
    """Per-scenario assertions on the act output stream.

    `must_contain` strings are substring matches; each one MUST appear
    somewhere in the captured act output. `must_not_contain` strings
    are negative assertions — they must NOT appear in the output.

    The expected values come from manually computing the aggregator's
    output for each fixture pair (see fixtures/*.xml + fixtures/*.json).
    """
    must_contain: tuple[str, ...]
    must_not_contain: tuple[str, ...] = ()


# Each scenario's expected EXACT VALUES, derived by hand from the fixtures.
SCENARIOS: dict[str, Expectation] = {
    "all-pass": Expectation(
        must_contain=(
            # CLI summary line — exact totals
            "Aggregated 2 run(s): 6 passed, 0 failed, 0 skipped, 6 total",
            # Markdown body
            "All tests passed across all runs.",
            "**Status:** passed",
            "Total tests | 6",
            "Passed | 6",
            "Failed | 0",
            # Verification step + job
            "Verification passed for scenario=all-pass",
            "Job succeeded",
        ),
        must_not_contain=(
            "## Flaky tests",
            "## Failures",
        ),
    ),
    "with-flake": Expectation(
        must_contain=(
            "Aggregated 2 run(s): 5 passed, 1 failed, 2 skipped, 8 total",
            "Flaky tests detected: 1",
            "auth.login_rejects_bad_password (passed 1, failed 1)",
            "## Flaky tests",
            "**Status:** needs attention",
            "Total tests | 8",
            "Passed | 5",
            "Failed | 1",
            "Skipped | 2",
            "Verification passed for scenario=with-flake",
            "Job succeeded",
        ),
        must_not_contain=(
            "## Failures",
        ),
    ),
    "with-failures": Expectation(
        must_contain=(
            "Aggregated 2 run(s): 2 passed, 2 failed, 0 skipped, 4 total",
            "## Failures",
            "auth.login_rejects_bad_password",
            "AssertionError: expected 401, got 200",
            "**Status:** needs attention",
            "Total tests | 4",
            "Passed | 2",
            "Failed | 2",
            "Verification passed for scenario=with-failures",
            "Job succeeded",
        ),
        must_not_contain=(
            "## Flaky tests",
        ),
    ),
}


# Project files copied into each scenario's temp repo. tests/ is
# included so the workflow's pytest step exercises the unit tests.
PROJECT_FILES = (
    "aggregator.py",
    "conftest.py",
    "pytest.ini",
    ".actrc",
)
PROJECT_DIRS = (
    "tests",
    "fixtures",
    ".github",
)


def setup_temp_repo(scenario: str) -> Path:
    """Build a fresh git repo in a tempdir for one scenario."""
    tmp = Path(tempfile.mkdtemp(prefix=f"act-{scenario}-"))

    for name in PROJECT_FILES:
        src = WORKSPACE / name
        if src.exists():
            shutil.copy(src, tmp / name)

    for name in PROJECT_DIRS:
        src = WORKSPACE / name
        if src.is_dir():
            shutil.copytree(src, tmp / name)

    # The scenario file is what the workflow's "Resolve scenario" step
    # reads when no workflow_dispatch input is provided (our `act push`
    # uses the push event, not workflow_dispatch).
    (tmp / "scenario.txt").write_text(scenario + "\n")

    # act requires a git repo for `act push` to work.
    git = ["git", "-C", str(tmp)]
    subprocess.run(git + ["init", "-q", "-b", "main"], check=True)
    subprocess.run(git + ["config", "user.email", "test@example.com"], check=True)
    subprocess.run(git + ["config", "user.name", "Test"], check=True)
    subprocess.run(git + ["config", "commit.gpgsign", "false"], check=True)
    subprocess.run(git + ["add", "-A"], check=True)
    subprocess.run(git + ["commit", "-q", "-m", "fixture"], check=True)
    return tmp


def run_act(repo: Path) -> tuple[int, str]:
    """Execute `act push --rm --pull=false` in the given repo.

    --pull=false stops act from re-pulling our LOCAL custom image
    (act-ubuntu-pwsh:latest) from a registry it isn't published to.
    The image is built once via Dockerfile.act and reused locally.
    """
    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=600,
    )
    return proc.returncode, (proc.stdout + proc.stderr)


def append_to_act_result(scenario: str, rc: int, output: str) -> None:
    delim = "=" * 80
    header = f"\n{delim}\nSCENARIO: {scenario} (act exit code: {rc})\n{delim}\n"
    with ACT_RESULT.open("a", encoding="utf-8") as f:
        f.write(header)
        f.write(output)
        if not output.endswith("\n"):
            f.write("\n")


def assert_substrings(label: str, output: str, items: Iterable[str],
                      negative: bool = False) -> list[str]:
    """Return a list of failure messages (empty list = all passed)."""
    failures: list[str] = []
    for item in items:
        present = item in output
        if negative and present:
            failures.append(f"[{label}] unexpected substring present: {item!r}")
        elif not negative and not present:
            failures.append(f"[{label}] missing expected substring: {item!r}")
    return failures


def run_scenario(scenario: str, expectation: Expectation) -> list[str]:
    """Run one scenario end-to-end. Returns a list of failure messages."""
    print(f"\n--- scenario: {scenario} ---", flush=True)
    repo = setup_temp_repo(scenario)
    try:
        rc, output = run_act(repo)
        append_to_act_result(scenario, rc, output)

        failures: list[str] = []
        if rc != 0:
            failures.append(f"[{scenario}] act exited with code {rc} (expected 0)")

        failures += assert_substrings(scenario, output, expectation.must_contain)
        failures += assert_substrings(
            scenario, output, expectation.must_not_contain, negative=True,
        )

        # Tail summary for log readability.
        tail = "\n".join(output.splitlines()[-10:])
        print(f"act exit={rc}\n--- last 10 lines of act output ---\n{tail}",
              flush=True)
        return failures
    finally:
        # Best-effort cleanup; the tempdir is in /tmp so it'll get
        # reaped anyway, but explicit is friendlier.
        shutil.rmtree(repo, ignore_errors=True)


def main(argv: list[str] | None = None) -> int:
    # Reset act-result.txt at the start of each harness run so the
    # final file contains exactly one header per scenario.
    ACT_RESULT.write_text("")

    scenarios = list(SCENARIOS.keys()) if not argv else argv
    all_failures: list[str] = []
    for scenario in scenarios:
        if scenario not in SCENARIOS:
            print(f"unknown scenario: {scenario}", file=sys.stderr)
            return 2
        all_failures += run_scenario(scenario, SCENARIOS[scenario])

    print("\n" + "=" * 80)
    if all_failures:
        print(f"FAIL: {len(all_failures)} assertion(s) failed across "
              f"{len(scenarios)} scenario(s):")
        for f in all_failures:
            print(f"  - {f}")
        return 1

    print(f"PASS: all {len(scenarios)} scenario(s) succeeded.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] if len(sys.argv) > 1 else None))
