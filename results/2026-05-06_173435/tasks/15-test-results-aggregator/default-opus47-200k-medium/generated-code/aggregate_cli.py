"""CLI entrypoint: parse multiple test result files and emit a markdown summary.

Usage:
    python3 aggregate_cli.py <fixtures-dir-or-files...> [--output summary.md]

If $GITHUB_STEP_SUMMARY is set, the summary is also appended there so it
shows up in the GitHub Actions job summary.

Exit code is non-zero if any test failed (so the workflow step fails when
the underlying matrix had failures), unless --no-fail is passed.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from aggregator import aggregate, parse_file, render_markdown


def _expand(paths: list[str]) -> list[Path]:
    out: list[Path] = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            for f in sorted(path.iterdir()):
                if f.suffix.lower() in (".json", ".xml"):
                    out.append(f)
        else:
            out.append(path)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Aggregate test results into a markdown summary.")
    ap.add_argument("inputs", nargs="+", help="Test result files (.json/.xml) or directories containing them.")
    ap.add_argument("--output", "-o", default="summary.md", help="Output markdown file (default: summary.md).")
    ap.add_argument("--no-fail", action="store_true", help="Always exit 0, even if tests failed.")
    args = ap.parse_args(argv)

    files = _expand(args.inputs)
    if not files:
        print("ERROR: no test result files found", file=sys.stderr)
        return 2

    runs = []
    for f in files:
        try:
            runs.append(parse_file(f))
        except (ValueError, FileNotFoundError) as e:
            print(f"ERROR parsing {f}: {e}", file=sys.stderr)
            return 2

    md = render_markdown(runs)
    Path(args.output).write_text(md)

    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a") as fh:
            fh.write(md)

    summary = aggregate(runs)
    # Print a one-line machine-greppable status for the workflow to assert on.
    print(
        f"AGGREGATE_RESULT total={summary.total} passed={summary.passed} "
        f"failed={summary.failed} skipped={summary.skipped} runs={summary.runs}"
    )
    print(md)

    if summary.failed and not args.no_fail:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
