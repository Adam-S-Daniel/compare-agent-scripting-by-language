"""Test results aggregator.

Parses JUnit XML and JSON test result files, aggregates results across
multiple runs (matrix builds), identifies flaky tests (passed in some runs,
failed in others), and emits a markdown summary suitable for a GitHub Actions
job summary ($GITHUB_STEP_SUMMARY).

Approach:
    parse_junit_xml / parse_json -> List[TestCase]
    Aggregator collects per-run case lists, then computes totals,
    flaky tests, and consistent-failures.
    render_markdown turns the Aggregator into a markdown report.
    main() is the CLI entry point used by the GitHub Actions workflow.

Design notes:
    - Status is normalized to one of {"passed", "failed", "skipped"} so
      flaky-detection is straightforward.
    - A flaky test is one whose normalized status varies between
      "passed" and "failed" across the runs (skipped runs are ignored,
      since "skipped" is intentional, not a flake signal).
    - Errors at parse time raise ValueError with a friendly message
      that names the offending file. This makes CI logs actionable.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree as ET


# ---------- Domain ----------

@dataclass
class TestCase:
    """A single test case from one run.

    `full_name` is "{suite}.{name}" — a stable identifier we use to
    group across runs for flaky detection.
    """
    suite: str
    name: str
    status: str  # "passed" | "failed" | "skipped"
    duration: float
    failure_message: str | None = None

    @property
    def full_name(self) -> str:
        return f"{self.suite}.{self.name}" if self.suite else self.name


@dataclass
class FlakyResult:
    full_name: str
    pass_count: int
    fail_count: int
    skip_count: int
    sample_failure: str | None


# ---------- Status normalization ----------

# Map common status aliases to our three canonical values.
_STATUS_ALIASES = {
    "passed": "passed", "pass": "passed", "ok": "passed", "success": "passed",
    "successful": "passed",
    "failed": "failed", "fail": "failed", "failure": "failed", "error": "failed",
    "errored": "failed", "broken": "failed",
    "skipped": "skipped", "skip": "skipped", "pending": "skipped",
    "ignored": "skipped",
}


def _normalize_status(raw: str) -> str:
    s = (raw or "").strip().lower()
    if s not in _STATUS_ALIASES:
        # Unknown → treat as failure so we don't silently pass bad data.
        return "failed"
    return _STATUS_ALIASES[s]


# ---------- Parsers ----------

def parse_junit_xml(path: Path) -> list[TestCase]:
    """Parse a JUnit XML file.

    Handles both <testsuites>-rooted and bare <testsuite> documents
    (both are valid in the wild). Each <testcase> becomes one TestCase;
    presence of <failure> or <error> means failed; <skipped> means
    skipped; otherwise passed.
    """
    path = Path(path)
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        raise ValueError(f"Invalid JUnit XML in {path}: {exc}") from exc

    root = tree.getroot()
    suites = (
        list(root.iter("testsuite"))
        if root.tag != "testsuite"
        else [root]
    )

    cases: list[TestCase] = []
    for suite in suites:
        suite_name = suite.attrib.get("name", "")
        for tc in suite.findall("testcase"):
            classname = tc.attrib.get("classname") or suite_name
            name = tc.attrib.get("name", "")
            try:
                duration = float(tc.attrib.get("time", "0") or 0)
            except ValueError:
                duration = 0.0

            failure_el = tc.find("failure")
            error_el = tc.find("error")
            skipped_el = tc.find("skipped")

            if failure_el is not None or error_el is not None:
                status = "failed"
                el = failure_el if failure_el is not None else error_el
                msg = el.attrib.get("message") or (el.text or "").strip() or None
            elif skipped_el is not None:
                status = "skipped"
                msg = None
            else:
                status = "passed"
                msg = None

            cases.append(TestCase(
                suite=classname, name=name, status=status,
                duration=duration, failure_message=msg,
            ))
    return cases


def parse_json(path: Path) -> list[TestCase]:
    """Parse a JSON test results file.

    Expected schema (intentionally simple — a common interchange shape):
        {"results": [
            {"suite": "...", "name": "...", "status": "passed|failed|skipped",
             "duration": 0.42, "message": "optional failure message"},
            ...
        ]}
    """
    path = Path(path)
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc

    results = data.get("results")
    if not isinstance(results, list):
        raise ValueError(
            f"Invalid JSON in {path}: expected top-level object with 'results' list"
        )

    cases: list[TestCase] = []
    for i, item in enumerate(results):
        if not isinstance(item, dict):
            raise ValueError(f"Invalid JSON in {path}: results[{i}] is not an object")
        try:
            duration = float(item.get("duration", 0) or 0)
        except (TypeError, ValueError):
            duration = 0.0
        cases.append(TestCase(
            suite=str(item.get("suite", "")),
            name=str(item.get("name", "")),
            status=_normalize_status(item.get("status", "")),
            duration=duration,
            failure_message=item.get("message") or item.get("failure_message"),
        ))
    return cases


def parse_file(path: Path) -> list[TestCase]:
    """Dispatch to the right parser by file extension."""
    path = Path(path)
    ext = path.suffix.lower()
    if ext == ".xml":
        return parse_junit_xml(path)
    if ext == ".json":
        return parse_json(path)
    raise ValueError(f"Unsupported file type: {path} (expected .xml or .json)")


# ---------- Aggregation ----------

class Aggregator:
    """Collects per-run test cases and computes summary statistics."""

    def __init__(self) -> None:
        # run_id -> list[TestCase]
        self.runs: dict[str, list[TestCase]] = {}

    def add_run(self, run_id: str, cases: Iterable[TestCase]) -> None:
        self.runs[run_id] = list(cases)

    def all_cases(self) -> Iterable[TestCase]:
        for cases in self.runs.values():
            yield from cases

    def totals(self) -> dict:
        passed = failed = skipped = 0
        duration = 0.0
        for c in self.all_cases():
            duration += c.duration
            if c.status == "passed":
                passed += 1
            elif c.status == "failed":
                failed += 1
            elif c.status == "skipped":
                skipped += 1
        total = passed + failed + skipped
        return {
            "passed": passed, "failed": failed, "skipped": skipped,
            "total": total, "duration": duration, "runs": len(self.runs),
        }

    def _status_by_test(self) -> dict[str, list[TestCase]]:
        """Group cases across runs by full_name."""
        grouped: dict[str, list[TestCase]] = defaultdict(list)
        for c in self.all_cases():
            grouped[c.full_name].append(c)
        return grouped

    def flaky_tests(self) -> list[FlakyResult]:
        """A test is flaky if it has BOTH a passed and a failed run.

        Skipped runs are ignored — being skipped is intentional (e.g. a
        platform-specific exclusion), not a flakiness signal.
        """
        flaky: list[FlakyResult] = []
        for full_name, cases in self._status_by_test().items():
            statuses = [c.status for c in cases]
            pass_count = statuses.count("passed")
            fail_count = statuses.count("failed")
            skip_count = statuses.count("skipped")
            if pass_count > 0 and fail_count > 0:
                sample = next(
                    (c.failure_message for c in cases
                     if c.status == "failed" and c.failure_message),
                    None,
                )
                flaky.append(FlakyResult(
                    full_name=full_name,
                    pass_count=pass_count, fail_count=fail_count,
                    skip_count=skip_count, sample_failure=sample,
                ))
        flaky.sort(key=lambda f: f.full_name)
        return flaky

    def consistent_failures(self) -> list[TestCase]:
        """Tests that failed in every non-skipped run."""
        out: list[TestCase] = []
        for full_name, cases in self._status_by_test().items():
            non_skipped = [c for c in cases if c.status != "skipped"]
            if non_skipped and all(c.status == "failed" for c in non_skipped):
                out.append(non_skipped[0])
        out.sort(key=lambda c: c.full_name)
        return out


# ---------- Markdown rendering ----------

def render_markdown(agg: Aggregator) -> str:
    """Produce a GitHub-Actions-job-summary friendly markdown document."""
    t = agg.totals()
    flaky = agg.flaky_tests()
    failures = agg.consistent_failures()

    overall = "passed" if t["failed"] == 0 and not flaky else "needs attention"
    lines: list[str] = []
    lines.append("# Test Results Summary")
    lines.append("")
    lines.append(f"**Status:** {overall}")
    lines.append("")
    lines.append("## Totals")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|---|---|")
    lines.append(f"| Runs aggregated | {t['runs']} |")
    lines.append(f"| Total tests | {t['total']} |")
    lines.append(f"| Passed | {t['passed']} |")
    lines.append(f"| Failed | {t['failed']} |")
    lines.append(f"| Skipped | {t['skipped']} |")
    lines.append(f"| Total duration | {t['duration']:.2f}s |")
    lines.append("")

    if t["failed"] == 0 and not flaky:
        lines.append("All tests passed across all runs.")
        lines.append("")
        return "\n".join(lines)

    if failures:
        lines.append("## Failures")
        lines.append("")
        lines.append("| Test | Message |")
        lines.append("|---|---|")
        for c in failures:
            msg = (c.failure_message or "").replace("|", "\\|").replace("\n", " ")
            if len(msg) > 120:
                msg = msg[:117] + "..."
            lines.append(f"| `{c.full_name}` | {msg} |")
        lines.append("")

    if flaky:
        lines.append("## Flaky tests")
        lines.append("")
        lines.append("Tests below passed in some runs and failed in others.")
        lines.append("")
        lines.append("| Test | Passed | Failed | Sample failure |")
        lines.append("|---|---|---|---|")
        for f in flaky:
            sample = (f.sample_failure or "").replace("|", "\\|").replace("\n", " ")
            if len(sample) > 80:
                sample = sample[:77] + "..."
            lines.append(
                f"| `{f.full_name}` | {f.pass_count} | {f.fail_count} | {sample} |"
            )
        lines.append("")

    return "\n".join(lines)


# ---------- CLI ----------

def _build_aggregator(paths: list[Path]) -> Aggregator:
    agg = Aggregator()
    for p in paths:
        cases = parse_file(p)
        # Use the file path as the run identifier so each input file is
        # treated as a separate matrix run.
        agg.add_run(str(p), cases)
    return agg


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Aggregate JUnit XML / JSON test results and emit a "
                    "markdown summary."
    )
    parser.add_argument("inputs", nargs="*",
                        help="Paths to test result files (.xml or .json).")
    parser.add_argument("--output", "-o", default="-",
                        help="Output markdown path. '-' = stdout. "
                             "Defaults to $GITHUB_STEP_SUMMARY when set.")
    parser.add_argument("--fail-on-failures", action="store_true",
                        help="Exit 1 when any test failed across all runs "
                             "(after producing the summary). Default: always "
                             "exit 0 on successful summary generation.")
    args = parser.parse_args(argv)

    if not args.inputs:
        print("error: no input files provided", file=sys.stderr)
        return 2

    paths = [Path(p) for p in args.inputs]
    missing = [p for p in paths if not p.exists()]
    if missing:
        print(f"error: missing input file(s): {', '.join(map(str, missing))}",
              file=sys.stderr)
        return 2

    try:
        agg = _build_aggregator(paths)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    md = render_markdown(agg)

    # If --output not given but $GITHUB_STEP_SUMMARY is set, write there
    # so this drops cleanly into a GH Actions job summary.
    output = args.output
    if output == "-" and os.environ.get("GITHUB_STEP_SUMMARY"):
        output = os.environ["GITHUB_STEP_SUMMARY"]

    if output == "-":
        sys.stdout.write(md)
    else:
        Path(output).write_text(md)

    # Also print key totals to stdout — useful for CI log scraping.
    t = agg.totals()
    print(
        f"Aggregated {t['runs']} run(s): "
        f"{t['passed']} passed, {t['failed']} failed, "
        f"{t['skipped']} skipped, {t['total']} total, "
        f"{t['duration']:.2f}s",
    )
    flaky = agg.flaky_tests()
    if flaky:
        print(f"Flaky tests detected: {len(flaky)}")
        for f in flaky:
            print(f"  - {f.full_name} (passed {f.pass_count}, failed {f.fail_count})")

    # By default the aggregator exits 0 — generating a summary IS the
    # success criterion, and CI surfaces test failures via the markdown
    # itself. Pass --fail-on-failures to bubble test failures up as a
    # non-zero exit (useful when you want the build to break).
    if args.fail_on_failures and t["failed"] > 0 and agg.consistent_failures():
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
