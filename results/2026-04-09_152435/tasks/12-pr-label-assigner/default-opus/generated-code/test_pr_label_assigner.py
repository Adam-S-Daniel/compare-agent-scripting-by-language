#!/usr/bin/env python3
"""
Tests for PR Label Assigner.

TDD approach: this file was written FIRST, before the implementation.
Each test function exercises a specific piece of functionality and outputs
structured results for verification by the test harness.
"""

import sys
import json
import os
import subprocess
import tempfile

# Ensure we can import from the same directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pr_label_assigner import assign_labels, load_config, match_file


def run_test(name, actual, expected):
    """Run a single test case and output structured result."""
    passed = actual == expected
    status = "PASS" if passed else "FAIL"
    print(f"=== TEST: {name} ===")
    print(f"EXPECTED: {expected}")
    print(f"ACTUAL: {actual}")
    print(f"RESULT: {status}")
    print(f"=== END TEST: {name} ===")
    return passed


# --- TDD Round 1: Basic glob matching ---

def test_basic_glob_matching():
    """A docs/** pattern should label documentation files."""
    config = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1}
        ]
    }
    files = ["docs/readme.md", "docs/api/guide.md"]
    labels = assign_labels(files, config)
    return run_test("basic_glob_matching", labels, ["documentation"])


# --- TDD Round 2: Multiple labels per file ---

def test_multiple_labels_per_file():
    """A file matching multiple rules should accumulate all labels."""
    config = {
        "rules": [
            {"pattern": "src/api/**", "labels": ["api"], "priority": 1},
            {"pattern": "src/**", "labels": ["core"], "priority": 2}
        ]
    }
    files = ["src/api/handler.py"]
    labels = assign_labels(files, config)
    return run_test("multiple_labels_per_file", labels, ["api", "core"])


# --- TDD Round 3: Wildcard extension matching ---

def test_wildcard_extension():
    """*.test.* should match test files regardless of directory depth."""
    config = {
        "rules": [
            {"pattern": "*.test.*", "labels": ["tests"], "priority": 1}
        ]
    }
    files = ["src/components/button.test.js", "utils.test.py"]
    labels = assign_labels(files, config)
    return run_test("wildcard_extension", labels, ["tests"])


# --- TDD Round 4: Priority ordering with exclusive rules ---

def test_priority_ordering_exclusive():
    """An exclusive high-priority rule should block lower-priority rules for that file."""
    config = {
        "rules": [
            {"pattern": "src/api/**", "labels": ["api-critical"], "priority": 1, "exclusive": True},
            {"pattern": "src/**", "labels": ["core"], "priority": 10}
        ]
    }
    files = ["src/api/handler.py"]
    labels = assign_labels(files, config)
    return run_test("priority_ordering_exclusive", labels, ["api-critical"])


def test_priority_non_exclusive():
    """Without exclusive flag, all matching rules contribute labels."""
    config = {
        "rules": [
            {"pattern": "src/api/**", "labels": ["api"], "priority": 1},
            {"pattern": "src/**", "labels": ["core"], "priority": 10}
        ]
    }
    files = ["src/api/handler.py"]
    labels = assign_labels(files, config)
    return run_test("priority_non_exclusive", labels, ["api", "core"])


# --- TDD Round 5: Edge cases ---

def test_empty_file_list():
    """Empty file list should return no labels."""
    config = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1}
        ]
    }
    labels = assign_labels([], config)
    return run_test("empty_file_list", labels, [])


def test_no_matching_rules():
    """Files that don't match any rule should produce no labels."""
    config = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1}
        ]
    }
    files = ["src/main.py"]
    labels = assign_labels(files, config)
    return run_test("no_matching_rules", labels, [])


# --- TDD Round 6: Multiple files with different labels ---

def test_multiple_files_different_labels():
    """Different files matching different rules should produce a union of labels."""
    config = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1},
            {"pattern": "src/api/**", "labels": ["api"], "priority": 2},
            {"pattern": "*.test.*", "labels": ["tests"], "priority": 3}
        ]
    }
    files = ["docs/readme.md", "src/api/handler.py", "src/app.test.js"]
    labels = assign_labels(files, config)
    return run_test("multiple_files_different_labels", labels, ["api", "documentation", "tests"])


# --- TDD Round 7: Specific pattern types ---

def test_github_ci_pattern():
    """Files under .github/ should match .github/** pattern."""
    config = {
        "rules": [
            {"pattern": ".github/**", "labels": ["ci"], "priority": 1}
        ]
    }
    files = [".github/workflows/ci.yml"]
    labels = assign_labels(files, config)
    return run_test("github_ci_pattern", labels, ["ci"])


def test_markdown_extension():
    """*.md should match any markdown file by extension."""
    config = {
        "rules": [
            {"pattern": "*.md", "labels": ["documentation"], "priority": 1}
        ]
    }
    files = ["README.md", "CHANGELOG.md"]
    labels = assign_labels(files, config)
    return run_test("markdown_extension", labels, ["documentation"])


# --- TDD Round 8: Deduplication ---

def test_deduplicate_labels():
    """Same label from multiple rules should appear only once."""
    config = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1},
            {"pattern": "*.md", "labels": ["documentation"], "priority": 2}
        ]
    }
    files = ["docs/guide.md"]
    labels = assign_labels(files, config)
    return run_test("deduplicate_labels", labels, ["documentation"])


# --- TDD Round 9: Config loading ---

def test_load_config_from_file(tmp_dir):
    """Config should load correctly from a JSON file."""
    config_data = {
        "rules": [
            {"pattern": "src/**", "labels": ["core"], "priority": 1}
        ]
    }
    config_path = os.path.join(tmp_dir, "test_config.json")
    with open(config_path, "w") as f:
        json.dump(config_data, f)

    config = load_config(config_path)
    labels = assign_labels(["src/main.py"], config)
    return run_test("load_config_from_file", labels, ["core"])


# --- TDD Round 10: Error handling ---

def test_invalid_config_missing_rules(tmp_dir):
    """Config without 'rules' key should raise ValueError."""
    config_path = os.path.join(tmp_dir, "bad_config.json")
    with open(config_path, "w") as f:
        json.dump({"not_rules": []}, f)

    try:
        load_config(config_path)
        return run_test("invalid_config_missing_rules", "no_error", "ValueError")
    except ValueError as e:
        has_msg = "rules" in str(e).lower()
        return run_test("invalid_config_missing_rules",
                        "ValueError" if has_msg else "bad_message", "ValueError")


def test_config_file_not_found():
    """Missing config file should raise FileNotFoundError."""
    try:
        load_config("/nonexistent/path/config.json")
        return run_test("config_file_not_found", "no_error", "FileNotFoundError")
    except FileNotFoundError:
        return run_test("config_file_not_found", "FileNotFoundError", "FileNotFoundError")


# --- TDD Round 11: Complex real-world scenario ---

def test_complex_scenario():
    """Full scenario with many rules and files, verifying exact label set."""
    config = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1},
            {"pattern": "src/api/**", "labels": ["api"], "priority": 2},
            {"pattern": "*.test.*", "labels": ["tests"], "priority": 3},
            {"pattern": "src/**", "labels": ["core"], "priority": 10},
            {"pattern": "*.md", "labels": ["documentation"], "priority": 5},
            {"pattern": "*.yml", "labels": ["config"], "priority": 5},
            {"pattern": ".github/**", "labels": ["ci"], "priority": 1}
        ]
    }
    files = [
        "docs/api-guide.md",
        "src/api/routes.py",
        "src/api/routes.test.py",
        "src/utils/helpers.py",
        "README.md",
        ".github/workflows/ci.yml",
        "config.yml"
    ]
    labels = assign_labels(files, config)
    return run_test("complex_scenario", labels,
                    ["api", "ci", "config", "core", "documentation", "tests"])


# --- TDD Round 12: CLI integration ---

def test_main_cli_output():
    """The CLI should output labels in the expected format."""
    config_data = {
        "rules": [
            {"pattern": "docs/**", "labels": ["documentation"], "priority": 1},
            {"pattern": "src/**", "labels": ["core"], "priority": 2}
        ]
    }
    tmp_dir = tempfile.mkdtemp()
    config_path = os.path.join(tmp_dir, "cli_config.json")
    with open(config_path, "w") as f:
        json.dump(config_data, f)

    result = subprocess.run(
        [sys.executable, "pr_label_assigner.py",
         "--config", config_path,
         "--files", "docs/readme.md", "src/main.py"],
        capture_output=True, text=True
    )
    output = result.stdout.strip()
    has_labels = "LABELS: core, documentation" in output
    return run_test("main_cli_output", has_labels, True)


def main():
    """Run all tests and report summary."""
    tmp_dir = tempfile.mkdtemp()

    print("=" * 60)
    print("PR Label Assigner - Test Suite")
    print("=" * 60)

    results = []
    results.append(test_basic_glob_matching())
    results.append(test_multiple_labels_per_file())
    results.append(test_wildcard_extension())
    results.append(test_priority_ordering_exclusive())
    results.append(test_priority_non_exclusive())
    results.append(test_empty_file_list())
    results.append(test_no_matching_rules())
    results.append(test_multiple_files_different_labels())
    results.append(test_github_ci_pattern())
    results.append(test_markdown_extension())
    results.append(test_deduplicate_labels())
    results.append(test_load_config_from_file(tmp_dir))
    results.append(test_invalid_config_missing_rules(tmp_dir))
    results.append(test_config_file_not_found())
    results.append(test_complex_scenario())
    results.append(test_main_cli_output())

    print("=" * 60)
    passed = sum(results)
    total = len(results)
    print(f"SUMMARY: {passed}/{total} tests passed")
    if passed == total:
        print("ALL TESTS PASSED")
    else:
        print("SOME TESTS FAILED")
        sys.exit(1)
    print("=" * 60)


if __name__ == "__main__":
    main()
