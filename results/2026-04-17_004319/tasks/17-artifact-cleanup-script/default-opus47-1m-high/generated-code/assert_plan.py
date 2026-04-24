#!/usr/bin/env python3
"""
Compare the `summary` block of a plan.json against an expected.json spec.
Exits 0 on match, 1 on mismatch. Used by the GitHub Actions scenario step.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: assert_plan.py <plan.json> <expected.json>", file=sys.stderr)
        return 2
    plan_path, expected_path = Path(argv[1]), Path(argv[2])
    plan = json.loads(plan_path.read_text())
    expected = json.loads(expected_path.read_text())
    summary = plan.get("summary", {})

    print("Summary:", json.dumps(summary, indent=2))
    print("Expected:", json.dumps(expected, indent=2))

    mismatches = []
    for key, value in expected.items():
        actual = summary.get(key)
        if actual != value:
            mismatches.append(f"  {key}: expected {value}, got {actual}")

    if mismatches:
        print("ASSERTION FAILED:", file=sys.stderr)
        for m in mismatches:
            print(m, file=sys.stderr)
        return 1

    print("ASSERTION PASSED: plan summary matches expected.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
