"""Test results aggregator.

Parses JUnit XML and JSON test result files (one per matrix-build leg),
aggregates counts and timings, identifies flaky tests (cases that pass in
some runs and fail in others), and renders a markdown summary suitable for
a GitHub Actions job summary ($GITHUB_STEP_SUMMARY).

Designed for testability: small pure functions, parsing decoupled from
aggregation, rendering decoupled from I/O. The CLI entry point `run()` is
also called from the test suite directly so the I/O wiring is exercised.
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence

# Status vocabulary used internally. Errors and failures are merged into
# "failed" — most CI dashboards treat them the same and the JUnit error/
# failure distinction rarely matters for a summary view.
PASSED = "passed"
FAILED = "failed"
SKIPPED = "skipped"
VALID_STATUSES = {PASSED, FAILED, SKIPPED}


@dataclass(frozen=True)
class TestCase:
    name: str
    classname: str
    status: str
    duration: float
    message: str = ""

    @property
    def identity(self) -> tuple[str, str]:
        # classname+name is the closest thing JUnit has to a stable test id.
        return (self.classname, self.name)


@dataclass
class TestResults:
    """A single run's worth of cases (e.g. one matrix leg)."""
    cases: list[TestCase] = field(default_factory=list)


@dataclass
class Summary:
    total: int
    passed: int
    failed: int
    skipped: int
    duration: float


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def _coerce_float(value: object, default: float = 0.0) -> float:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default


def parse_junit_xml(path: Path) -> TestResults:
    """Parse a JUnit XML file (single <testsuite> or <testsuites> root)."""
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        raise ValueError(f"Failed to parse JUnit XML at {path}: {exc}") from exc

    root = tree.getroot()
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))

    cases: list[TestCase] = []
    for suite in suites:
        for case_el in suite.findall("testcase"):
            name = case_el.attrib.get("name", "")
            classname = case_el.attrib.get("classname", suite.attrib.get("name", ""))
            duration = _coerce_float(case_el.attrib.get("time"))

            # Status is determined by presence of child elements.
            failure = case_el.find("failure")
            error = case_el.find("error")
            skipped = case_el.find("skipped")

            if failure is not None or error is not None:
                status = FAILED
                msg_el = failure if failure is not None else error
                message = (msg_el.attrib.get("message") or
                           (msg_el.text or "").strip())
            elif skipped is not None:
                status = SKIPPED
                message = skipped.attrib.get("message", "")
            else:
                status = PASSED
                message = ""

            cases.append(TestCase(
                name=name, classname=classname,
                status=status, duration=duration, message=message,
            ))
    return TestResults(cases=cases)


def parse_json(path: Path) -> TestResults:
    """Parse a JSON file with shape {"tests": [{name, classname, status, duration, ...}]}."""
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse JSON at {path}: {exc}") from exc

    raw_cases = data.get("tests") if isinstance(data, dict) else data
    if not isinstance(raw_cases, list):
        raise ValueError(
            f"Failed to parse JSON at {path}: expected a list of tests "
            f"under the 'tests' key or at the top level"
        )

    cases: list[TestCase] = []
    for entry in raw_cases:
        if not isinstance(entry, dict):
            continue
        status = str(entry.get("status", "")).lower()
        # Map common synonyms to our vocabulary.
        if status in ("pass", "ok", "success"):
            status = PASSED
        elif status in ("fail", "error", "errored"):
            status = FAILED
        elif status in ("skip", "skipped", "ignored"):
            status = SKIPPED
        if status not in VALID_STATUSES:
            # Unknown status — skip silently rather than crashing the whole run.
            continue
        cases.append(TestCase(
            name=str(entry.get("name", "")),
            classname=str(entry.get("classname", "")),
            status=status,
            duration=_coerce_float(entry.get("duration")),
            message=str(entry.get("message", "")),
        ))
    return TestResults(cases=cases)


def parse_file(path: Path) -> TestResults:
    """Dispatch to the right parser based on file extension."""
    if not path.exists():
        raise FileNotFoundError(f"Test results file not found: {path}")
    suffix = path.suffix.lower()
    if suffix == ".xml":
        return parse_junit_xml(path)
    if suffix == ".json":
        return parse_json(path)
    raise ValueError(f"Unsupported file format: {path.suffix} (expected .xml or .json)")


# ---------------------------------------------------------------------------
# Aggregation + flaky detection
# ---------------------------------------------------------------------------

def aggregate(runs: Sequence[TestResults]) -> Summary:
    """Sum counts and durations across every case in every run."""
    passed = failed = skipped = 0
    duration = 0.0
    for run_results in runs:
        for case in run_results.cases:
            duration += case.duration
            if case.status == PASSED:
                passed += 1
            elif case.status == FAILED:
                failed += 1
            elif case.status == SKIPPED:
                skipped += 1
    total = passed + failed + skipped
    return Summary(total=total, passed=passed, failed=failed,
                   skipped=skipped, duration=duration)


def find_flaky(runs: Sequence[TestResults]) -> list[TestCase]:
    """A test is flaky if the same identity has both passed and failed runs.

    Skipped runs are intentionally excluded from the stability judgement —
    a skipped test contributes no signal about pass/fail behaviour.
    Returns one representative TestCase per flaky identity, ordered by
    classname+name for stable output.
    """
    statuses: dict[tuple[str, str], set[str]] = {}
    representative: dict[tuple[str, str], TestCase] = {}
    for run_results in runs:
        for case in run_results.cases:
            if case.status == SKIPPED:
                continue
            statuses.setdefault(case.identity, set()).add(case.status)
            representative.setdefault(case.identity, case)

    flaky_ids = sorted(
        ident for ident, seen in statuses.items()
        if PASSED in seen and FAILED in seen
    )
    return [representative[i] for i in flaky_ids]


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------

def _fmt_duration(seconds: float) -> str:
    if seconds < 60:
        return f"{seconds:.2f}s"
    minutes, sec = divmod(seconds, 60)
    return f"{int(minutes)}m {sec:.1f}s"


def render_markdown(named_runs: Sequence[tuple[str, TestResults]]) -> str:
    """Render the aggregated results as GitHub-flavored markdown."""
    runs = [r for _, r in named_runs]
    summary = aggregate(runs)
    flaky = find_flaky(runs)
    overall_passed = summary.failed == 0 and summary.total > 0
    status_text = "PASSED" if overall_passed else ("FAILED" if summary.failed else "PASSED")

    lines = [
        "# Test Results Summary",
        "",
        f"**Overall status:** {status_text}",
        "",
        "## Totals",
        "",
        "| Total | Passed | Failed | Skipped | Duration |",
        "|------:|-------:|-------:|--------:|---------:|",
        f"| {summary.total} | {summary.passed} | {summary.failed} | "
        f"{summary.skipped} | {_fmt_duration(summary.duration)} |",
        "",
        "## Per-run breakdown",
        "",
        "| Run | Total | Passed | Failed | Skipped | Duration |",
        "|-----|------:|-------:|-------:|--------:|---------:|",
    ]
    for name, run_results in named_runs:
        s = aggregate([run_results])
        lines.append(
            f"| {name} | {s.total} | {s.passed} | {s.failed} | "
            f"{s.skipped} | {_fmt_duration(s.duration)} |"
        )

    lines.append("")
    lines.append("## Flaky tests")
    lines.append("")
    if not flaky:
        lines.append("_No flaky tests detected._")
    else:
        lines.append("These tests passed in some runs and failed in others:")
        lines.append("")
        lines.append("| Test | Class |")
        lines.append("|------|-------|")
        for case in flaky:
            lines.append(f"| {case.name} | {case.classname} |")

    if summary.failed:
        lines.append("")
        lines.append("## Failed tests")
        lines.append("")
        lines.append("| Test | Class | Message |")
        lines.append("|------|-------|---------|")
        for _, run_results in named_runs:
            for case in run_results.cases:
                if case.status != FAILED:
                    continue
                msg = (case.message or "").replace("|", "\\|").replace("\n", " ")
                if len(msg) > 80:
                    msg = msg[:77] + "..."
                lines.append(f"| {case.name} | {case.classname} | {msg} |")

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Aggregate JUnit XML / JSON test results and emit a markdown summary."
    )
    p.add_argument("files", nargs="+",
                   help="Test result files (.xml or .json). Each is treated as one run.")
    p.add_argument("--output", "-o", required=True,
                   help="Path to write the markdown summary.")
    return p


def run(argv: Iterable[str]) -> int:
    """CLI entry point. Returns 0 on success, 1 if any test failed, 2 on error."""
    parser = _build_arg_parser()
    args = parser.parse_args(list(argv))

    named_runs: list[tuple[str, TestResults]] = []
    try:
        for fpath in args.files:
            path = Path(fpath)
            results = parse_file(path)
            named_runs.append((path.stem, results))
    except (FileNotFoundError, ValueError) as exc:
        # Print to stderr so it shows up in CI logs.
        print(f"error: {exc}", file=sys.stderr)
        return 2

    md = render_markdown(named_runs)
    Path(args.output).write_text(md)
    print(f"Wrote summary to {args.output}")

    summary = aggregate([r for _, r in named_runs])
    # Emit a one-line status that's easy to grep from CI logs / act output.
    print(
        f"AGGREGATOR_STATUS total={summary.total} passed={summary.passed} "
        f"failed={summary.failed} skipped={summary.skipped} "
        f"flaky={len(find_flaky([r for _, r in named_runs]))}"
    )
    return 0 if summary.failed == 0 else 1


def main() -> None:  # pragma: no cover - thin wrapper
    sys.exit(run(sys.argv[1:]))


if __name__ == "__main__":  # pragma: no cover
    main()
