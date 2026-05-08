#!/usr/bin/env python3
"""CLI script to run test results aggregator from GitHub Actions."""
import sys
import argparse
from pathlib import Path
from aggregator import generate_markdown_summary


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate test results and generate markdown summary"
    )
    parser.add_argument(
        "result_files",
        nargs="+",
        help="Paths to test result files (XML or JSON)",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="test-summary.md",
        help="Output file for markdown summary (default: test-summary.md)",
    )

    args = parser.parse_args()

    # Validate that files exist
    for file_path in args.result_files:
        if not Path(file_path).exists():
            print(f"Error: File not found: {file_path}", file=sys.stderr)
            return 1

    try:
        summary = generate_markdown_summary(args.result_files)

        # Write to output file
        output_path = Path(args.output)
        output_path.write_text(summary)

        # Also print to stdout
        print(summary)
        print(f"\nSummary written to: {output_path}")

        return 0
    except Exception as e:
        print(f"Error generating summary: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
