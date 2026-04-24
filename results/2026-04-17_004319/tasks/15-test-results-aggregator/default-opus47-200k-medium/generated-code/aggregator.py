"""Test-results aggregator.

Parses test results from JUnit XML and a simple JSON format, aggregates across
multiple files (e.g. a matrix build), detects flaky tests (same test with mixed
pass/fail outcomes across runs), and emits a Markdown summary suitable for
a GitHub Actions job summary ($GITHUB_STEP_SUMMARY).
"""
from __future__ import annotations

import json
import sys
import argparse
import glob
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree as ET


@dataclass
class TestResult:
    __test__ = False  # prevent pytest from trying to collect this class
    name: str
    status: str          # "passed" | "failed" | "skipped"
    duration: float
    run: str             # identifier for which run/file this came from
    message: str | None = None


@dataclass
class Aggregate:
    passed: int
    failed: int
    skipped: int
    duration: float
    total: int
    flaky: list[TestResult] = field(default_factory=list)
    runs: list[str] = field(default_factory=list)
    failures: list[TestResult] = field(default_factory=list)


# ---------- parsing ----------

def _run_name(path: Path) -> str:
    return path.stem


def parse_junit_xml(path: Path) -> list[TestResult]:
    """Parse a JUnit XML file. Supports both <testsuite> and <testsuites> roots."""
    path = Path(path)
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        raise ValueError(f"Failed to parse JUnit XML {path}: {e}") from e

    root = tree.getroot()
    suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))

    results: list[TestResult] = []
    run = _run_name(path)
    for suite in suites:
        for case in suite.findall("testcase"):
            classname = case.get("classname", "")
            name = case.get("name", "")
            full = f"{classname}.{name}" if classname else name
            try:
                duration = float(case.get("time", "0") or 0)
            except ValueError:
                duration = 0.0

            message = None
            if case.find("failure") is not None:
                status = "failed"
                message = case.find("failure").get("message")
            elif case.find("error") is not None:
                status = "failed"
                message = case.find("error").get("message")
            elif case.find("skipped") is not None:
                status = "skipped"
            else:
                status = "passed"

            results.append(TestResult(
                name=full, status=status, duration=duration, run=run, message=message,
            ))
    return results


def parse_json(path: Path) -> list[TestResult]:
    """Parse a JSON test-results file.

    Expected shape: {"tests": [{"name": str, "status": str, "duration": float, "message"?: str}, ...]}
    """
    path = Path(path)
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON {path}: {e}") from e

    if not isinstance(data, dict) or "tests" not in data:
        raise ValueError(f"Invalid JSON in {path}: missing 'tests' key")

    run = _run_name(path)
    results: list[TestResult] = []
    for t in data["tests"]:
        status = t.get("status", "passed")
        if status not in ("passed", "failed", "skipped"):
            raise ValueError(f"Unknown status {status!r} in {path}")
        results.append(TestResult(
            name=t.get("name", "<unnamed>"),
            status=status,
            duration=float(t.get("duration", 0.0)),
            run=run,
            message=t.get("message"),
        ))
    return results


def parse_file(path: Path) -> list[TestResult]:
    """Dispatch to the right parser based on file extension."""
    path = Path(path)
    ext = path.suffix.lower()
    if ext == ".xml":
        return parse_junit_xml(path)
    if ext == ".json":
        return parse_json(path)
    raise ValueError(f"Unsupported file extension {ext!r} for {path}")


# ---------- aggregation ----------

def find_flaky(results: Iterable[TestResult]) -> list[TestResult]:
    """A test is flaky if it both passed and failed across runs.
    Skipped outcomes are ignored when deciding flakiness.
    Returns one representative TestResult per flaky test name (the first failure seen).
    """
    by_name: dict[str, set[str]] = {}
    failures_by_name: dict[str, TestResult] = {}
    for r in results:
        by_name.setdefault(r.name, set()).add(r.status)
        if r.status == "failed" and r.name not in failures_by_name:
            failures_by_name[r.name] = r
    flaky = []
    for name, statuses in by_name.items():
        if "passed" in statuses and "failed" in statuses:
            flaky.append(failures_by_name[name])
    flaky.sort(key=lambda r: r.name)
    return flaky


def aggregate(results: list[TestResult],
              flaky: list[TestResult] | None = None,
              failures: list[TestResult] | None = None) -> Aggregate:
    passed = sum(1 for r in results if r.status == "passed")
    failed = sum(1 for r in results if r.status == "failed")
    skipped = sum(1 for r in results if r.status == "skipped")
    duration = sum(r.duration for r in results)
    runs = sorted({r.run for r in results})
    return Aggregate(
        passed=passed, failed=failed, skipped=skipped, duration=duration,
        total=len(results),
        flaky=flaky if flaky is not None else find_flaky(results),
        runs=runs,
        failures=failures if failures is not None
                 else [r for r in results if r.status == "failed"],
    )


# ---------- markdown ----------

def generate_markdown(agg: Aggregate) -> str:
    lines: list[str] = []
    lines.append("# Test Results Summary")
    lines.append("")
    lines.append(f"Aggregated across {len(agg.runs)} run(s): {', '.join(agg.runs) or '(none)'}")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("|---|---|")
    lines.append(f"| Passed | {agg.passed} |")
    lines.append(f"| Failed | {agg.failed} |")
    lines.append(f"| Skipped | {agg.skipped} |")
    lines.append(f"| Total | {agg.total} |")
    lines.append(f"| Duration | {agg.duration:.2f}s |")
    lines.append("")

    lines.append("## Flaky Tests")
    if agg.flaky:
        lines.append("")
        lines.append("| Test | Example message |")
        lines.append("|---|---|")
        for f in agg.flaky:
            lines.append(f"| `{f.name}` | {f.message or ''} |")
    else:
        lines.append("")
        lines.append("No flaky tests detected.")
    lines.append("")

    lines.append("## Failures")
    if agg.failures:
        lines.append("")
        lines.append("| Test | Run | Message |")
        lines.append("|---|---|---|")
        for f in agg.failures:
            lines.append(f"| `{f.name}` | {f.run} | {f.message or ''} |")
    else:
        lines.append("")
        lines.append("No failures.")
    lines.append("")

    return "\n".join(lines)


# ---------- CLI ----------

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Aggregate test results into a Markdown summary.")
    p.add_argument("paths", nargs="+", help="Files or globs to parse (JUnit XML or JSON).")
    p.add_argument("--output", "-o", default=None,
                   help="Path to write the markdown to. Defaults to stdout.")
    p.add_argument("--fail-on-error", action="store_true",
                   help="Exit non-zero if aggregated results contain any failures.")
    args = p.parse_args(argv)

    files: list[Path] = []
    for pat in args.paths:
        matched = [Path(m) for m in sorted(glob.glob(pat))]
        if not matched and Path(pat).exists():
            matched = [Path(pat)]
        if not matched:
            print(f"warning: no files matched {pat!r}", file=sys.stderr)
        files.extend(matched)

    if not files:
        print("error: no input files found", file=sys.stderr)
        return 2

    all_results: list[TestResult] = []
    for f in files:
        try:
            all_results.extend(parse_file(f))
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            return 2

    agg = aggregate(all_results)
    md = generate_markdown(agg)

    if args.output:
        Path(args.output).write_text(md)
    else:
        sys.stdout.write(md)
        if not md.endswith("\n"):
            sys.stdout.write("\n")

    # Also print a compact line so CI logs show totals even without summary.
    print(
        f"[aggregator] runs={len(agg.runs)} total={agg.total} "
        f"passed={agg.passed} failed={agg.failed} skipped={agg.skipped} "
        f"flaky={len(agg.flaky)} duration={agg.duration:.2f}s",
        file=sys.stderr,
    )
    if args.fail_on_error and agg.failed > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
