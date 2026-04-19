# PR Label Assigner

A Python-based label assigner for GitHub pull requests that applies labels to changed files based on configurable glob patterns and rules.

## Features

- ✅ Glob pattern matching (supports `*`, `**`, and wildcard patterns)
- ✅ Multiple labels per file (no duplicates)
- ✅ Priority ordering for rule conflicts
- ✅ Stateful `PRLabelAssigner` class for reusable operations
- ✅ Comprehensive test coverage with 21 unit tests
- ✅ GitHub Actions workflow for CI/CD integration

## Implementation Approach (TDD)

This project follows red/green/refactor test-driven development:

1. **Tests First** - 21 comprehensive tests covering:
   - Simple label assignment
   - Multiple labels per file
   - Glob pattern matching (double asterisk, extensions, wildcards)
   - Priority ordering
   - Label rules class behavior
   - Stateful assigner class
   - Edge cases (empty inputs, duplicates, case sensitivity)

2. **Minimum Code** - Implementation provides exactly what tests require:
   - `LabelRule` dataclass for pattern + labels + priority
   - `PRLabelAssigner` class for stateful operations
   - `assign_labels()` function for core logic
   - Pattern matching with fnmatch and special ** handling

3. **No Over-Engineering** - No unnecessary abstractions or premature optimization

## Files

| File | Purpose |
|------|---------|
| `pr_label_assigner.py` | Core implementation (145 lines with comments) |
| `test_pr_label_assigner.py` | 21 comprehensive unit tests |
| `.github/workflows/pr-label-assigner.yml` | CI/CD workflow for GitHub Actions |
| `act-result.txt` | Test execution results from GitHub Actions |

## Usage

### Basic Example

```python
from pr_label_assigner import LabelRule, PRLabelAssigner

# Define labeling rules
rules = [
    LabelRule(pattern="docs/**", labels=["documentation"]),
    LabelRule(pattern="src/api/**", labels=["api", "backend"]),
    LabelRule(pattern="src/**", labels=["code"]),
    LabelRule(pattern="*.test.py", labels=["tests"]),
]

# Create assigner
assigner = PRLabelAssigner(rules)

# Assign labels to changed files
changed_files = [
    "docs/README.md",
    "src/api/handler.py",
    "src/utils/helper.py",
    "test_main.py",
]

result = assigner.assign(changed_files)

# Output:
# {
#   "docs/README.md": ["documentation"],
#   "src/api/handler.py": ["api", "backend", "code"],
#   "src/utils/helper.py": ["code"],
#   "test_main.py": [],
# }
```

### Advanced: Functional API

```python
from pr_label_assigner import assign_labels, LabelRule

rules = [LabelRule(pattern="src/**", labels=["code"])]
result = assign_labels(["src/main.py"], rules)
```

## Test Results

All 21 tests pass locally and through GitHub Actions:

```
============================= 21 passed in 0.04s ==============================
```

### Test Coverage

- **Simple Assignment** (3 tests): Single file, no matches, empty input
- **Multiple Labels** (2 tests): File matches multiple rules, rule has multiple labels
- **Glob Patterns** (3 tests): `**` recursive, extension matching, wildcard patterns
- **Priority Ordering** (2 tests): With and without priority
- **Label Rules Class** (3 tests): Creation, priority, defaults
- **Assigner Class** (3 tests): Init, assign method, dynamic rule addition
- **Edge Cases** (5 tests): Empty inputs, duplicates, case sensitivity

## GitHub Actions Workflow

The workflow (`.github/workflows/pr-label-assigner.yml`):

- ✅ Triggers on: push, pull_request, workflow_dispatch
- ✅ Runs on: ubuntu-latest
- ✅ Steps:
  1. Checkout code
  2. Set up Python 3.12
  3. Install pytest
  4. Run all unit tests
  5. Run mock data test
  6. Generate test results file
- ✅ Passes actionlint validation (YAML syntax, action references)
- ✅ Successfully runs with `act` (Docker-based GitHub Actions runner)

## Pattern Matching

Patterns support standard glob syntax:

| Pattern | Matches | Example |
|---------|---------|---------|
| `docs/**` | Recursive in docs | `docs/api/endpoints.md` |
| `src/**/*.py` | Python files in src subtree | `src/utils/helper.py` |
| `*.test.py` | Files ending in `.test.py` | `utils.test.py` |
| `src/*/` | Direct subdirectories | `src/auth/` |
| `src/*/*` | Files in subdirectories | `src/api/v1/routes.py` |

## Running Tests

### Locally

```bash
python3 -m pytest test_pr_label_assigner.py -v
```

### Through GitHub Actions (with act)

```bash
act push --rm -j test -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
```

## Code Quality

- **No type stubs or mypy** - Uses type hints where they aid readability (Python 3.12+)
- **Minimal comments** - Only explains WHY, not WHAT (code is self-documenting)
- **No error handling for impossible cases** - Trusts framework guarantees
- **No premature abstractions** - Each function does one thing well

## Summary

This implementation demonstrates TDD principles:
- Tests define requirements
- Minimum code satisfies tests
- No over-engineering or unused features
- Comprehensive edge case coverage
- Integration with GitHub Actions for real-world use

The PR Label Assigner is production-ready and can be integrated into GitHub workflows to automatically label PRs based on changed file paths.
