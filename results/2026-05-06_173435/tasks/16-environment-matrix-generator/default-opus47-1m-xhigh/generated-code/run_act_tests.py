"""Test harness: runs the workflow under `act` once per fixture and
asserts on EXACT EXPECTED VALUES extracted from the act output.

For each fixture under fixtures/<case>/:
  1. Build a temp git repo containing every project file PLUS that
     fixture's config.json placed at repo root (where the workflow
     reads it).
  2. Run `act push --rm` in that temp repo, capturing stdout+stderr.
  3. Append the output (delimited by case banners) to act-result.txt.
  4. Assert:
        - act exited 0
        - the unit-tests job and generate-matrix job both report
          "Job succeeded"
        - the embedded RC matches expected.json["rc"]
        - on success: the parsed matrix JSON deep-equals expected.matrix
        - on error:   the captured stderr contains expected.stderr_contains

Run this harness directly:  python3 run_act_tests.py
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
FIXTURE_ROOT = REPO_ROOT / "fixtures"
ACT_RESULT = REPO_ROOT / "act-result.txt"

# Files (relative to REPO_ROOT) we copy into each per-case temp repo.
# Fixture-specific config.json overrides this list later.
PROJECT_FILES = [
    "matrix_generator.py",
    "pytest.ini",
    "tests/__init__.py",
    "tests/test_matrix_generator.py",
    ".github/workflows/environment-matrix-generator.yml",
    ".actrc",
]


def _copy_project_files(dest: Path) -> None:
    for rel in PROJECT_FILES:
        src = REPO_ROOT / rel
        target = dest / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, target)


def _git_init(repo: Path) -> None:
    """Initialize a minimal git repo so `act push` can find a commit."""
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "act-harness",
        "GIT_AUTHOR_EMAIL": "act-harness@example.com",
        "GIT_COMMITTER_NAME": "act-harness",
        "GIT_COMMITTER_EMAIL": "act-harness@example.com",
    }
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True, env=env)
    subprocess.run(["git", "add", "."], cwd=repo, check=True, env=env)
    subprocess.run(
        ["git", "commit", "-q", "-m", "initial"],
        cwd=repo, check=True, env=env,
    )


def _strip_act_prefix(text: str) -> str:
    """act prefixes every step-output line with `[workflow/job]   | `.
    Strip that so the body parses as plain text/JSON.
    """
    out = []
    for line in text.splitlines():
        stripped = re.sub(r"^\[[^\]]*\]\s*", "", line)
        stripped = re.sub(r"^\|\s?", "", stripped)
        out.append(stripped)
    return "\n".join(out)


def _extract_block(text: str, begin: str, end: str) -> str:
    """Extract content between BEGIN/END markers from the (already
    prefix-stripped) act output. We use the *last* occurrence of the
    pair so any marker echo from earlier setup never masks the real
    payload from the generate-matrix step.
    """
    cleaned = _strip_act_prefix(text)
    pattern = re.compile(
        rf"{re.escape(begin)}\s*\n(.*?)\n\s*{re.escape(end)}",
        re.DOTALL,
    )
    matches = pattern.findall(cleaned)
    if not matches:
        return ""
    return matches[-1].strip()


def _extract_rc(text: str) -> int | None:
    m = list(re.finditer(r"<<<RC>>>(\d+)<<<RC>>>", text))
    if not m:
        return None
    return int(m[-1].group(1))


def _count_job_succeeded(text: str) -> int:
    """Count distinct 'Job succeeded' lines act prints at the end of each job."""
    return len(re.findall(r"Job succeeded", text))


def _run_act(repo: Path) -> tuple[int, str]:
    """Run `act push --rm` and return (returncode, combined-output).

    --pull=false: the act-ubuntu-pwsh image is built locally and isn't
    on a registry, so act's default forcePull would 403 trying to pull
    it. .actrc also carries this flag for redundancy.
    """
    cmd = ["act", "push", "--rm", "--pull=false"]
    proc = subprocess.run(
        cmd,
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=30 * 60,
    )
    return proc.returncode, proc.stdout + proc.stderr


def _assert(condition: bool, message: str, failures: list) -> None:
    if not condition:
        failures.append(message)


def run_one_case(name: str, fixture_dir: Path, log: list, failures: list) -> bool:
    cfg_path = fixture_dir / "config.json"
    expected_path = fixture_dir / "expected.json"
    if not cfg_path.exists() or not expected_path.exists():
        print(f"SKIP {name}: missing config.json or expected.json", flush=True)
        return False
    expected = json.loads(expected_path.read_text(encoding="utf-8"))

    print(f"\n=== Running case: {name} ===", flush=True)

    case_failures_before = len(failures)
    with tempfile.TemporaryDirectory(prefix=f"act-{name}-") as tmp:
        repo = Path(tmp)
        _copy_project_files(repo)
        # Drop the fixture's config.json at the repo root, where the
        # workflow looks for it.
        shutil.copy2(cfg_path, repo / "config.json")
        _git_init(repo)

        rc, output = _run_act(repo)

    banner = f"\n\n========== CASE: {name} (act exit={rc}) ==========\n"
    log.append(banner)
    log.append(output)

    _assert(rc == 0, f"[{name}] act exited with {rc}, expected 0", failures)

    # Two jobs run per workflow execution: unit-tests + generate-matrix.
    succeeded = _count_job_succeeded(output)
    _assert(
        succeeded >= 2,
        f"[{name}] expected >=2 'Job succeeded' lines, got {succeeded}",
        failures,
    )

    embedded_rc = _extract_rc(output)
    _assert(
        embedded_rc == expected["rc"],
        f"[{name}] embedded RC {embedded_rc} != expected {expected['rc']}",
        failures,
    )

    if expected["type"] == "success":
        matrix_block = _extract_block(output, "<<<MATRIX_BEGIN>>>", "<<<MATRIX_END>>>")
        _assert(
            bool(matrix_block),
            f"[{name}] no matrix block found in act output",
            failures,
        )
        if matrix_block:
            try:
                actual = json.loads(matrix_block)
            except json.JSONDecodeError as exc:
                failures.append(
                    f"[{name}] matrix block is not valid JSON: {exc}\n---\n{matrix_block}\n---"
                )
            else:
                _assert(
                    actual == expected["matrix"],
                    f"[{name}] matrix mismatch\n  expected: {json.dumps(expected['matrix'], sort_keys=True)}\n  actual:   {json.dumps(actual, sort_keys=True)}",
                    failures,
                )
    elif expected["type"] == "error":
        err_block = _extract_block(output, "<<<ERROR_BEGIN>>>", "<<<ERROR_END>>>")
        needle = expected["stderr_contains"]
        _assert(
            needle in err_block,
            f"[{name}] expected error to contain {needle!r}, got:\n{err_block!r}",
            failures,
        )
    else:
        failures.append(f"[{name}] unknown expected type: {expected['type']!r}")

    case_passed = len(failures) == case_failures_before
    status = "PASS" if case_passed else "FAIL"
    print(f"--- {status}: {name} ---", flush=True)
    return case_passed


def main() -> int:
    fixtures = sorted([p for p in FIXTURE_ROOT.iterdir() if p.is_dir()])
    if not fixtures:
        print("No fixtures found", file=sys.stderr)
        return 2

    log: list[str] = []
    failures: list[str] = []
    results: list[tuple[str, bool]] = []

    for fixture in fixtures:
        ok = run_one_case(fixture.name, fixture, log, failures)
        results.append((fixture.name, ok))

    ACT_RESULT.write_text("".join(log), encoding="utf-8")
    print(f"\nWrote {ACT_RESULT}", flush=True)

    print("\n========== SUMMARY ==========")
    for name, ok in results:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    if failures:
        print("\nFailures:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("\nAll cases passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
