#!/usr/bin/env python3
"""Runs each test case in test_fixture.json through the label assigner and prints results.

Output format (one line per case):
  CASE <name>: LABELS: <sorted-json-array>

The outer test harness (run_tests.py) parses these lines to assert exact expected values.
"""

import json
import sys

from pr_label_assigner import assign_labels, load_config


def main() -> int:
    try:
        rules = load_config('label_config.json')
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    try:
        with open('test_fixture.json') as f:
            fixture = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(f"ERROR loading test_fixture.json: {exc}", file=sys.stderr)
        return 1

    failures = 0
    for case in fixture['test_cases']:
        name = case['name']
        files = case['files']
        expected = sorted(case['expected_labels'])

        labels = assign_labels(files, rules)
        actual = sorted(labels)

        print(f"CASE {name}: LABELS: {json.dumps(actual)}")

        if actual != expected:
            print(f"  FAIL: expected {json.dumps(expected)}, got {json.dumps(actual)}", file=sys.stderr)
            failures += 1
        else:
            print(f"  PASS")

    if failures:
        print(f"\n{failures} test case(s) FAILED", file=sys.stderr)
        return 1

    print(f"\nAll {len(fixture['test_cases'])} test cases PASSED")
    return 0


if __name__ == '__main__':
    sys.exit(main())
