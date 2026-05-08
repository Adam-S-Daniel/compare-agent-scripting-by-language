# Environment Matrix Generator

A Python-based tool that generates GitHub Actions build matrix configurations from JSON specifications. This implementation follows TDD methodology with comprehensive test coverage.

## Features

- **Build Matrix Generation**: Create Cartesian products of OS, language versions, and other dimensions
- **Include/Exclude Rules**: Add custom combinations or remove specific ones
- **Max-Parallel Limits**: Control concurrent job execution
- **Fail-Fast Control**: Configure job failure behavior
- **Size Validation**: Prevent matrix explosion with configurable limits
- **JSON I/O**: Load configurations from files and output standard GitHub Actions JSON

## Architecture

### Core Module: `matrix_generator.py`

Provides the main `MatrixGenerator` class and supporting types:

- `MatrixConfig`: Configuration dataclass with OS, language versions, and control options
- `MatrixGenerator`: Generates the GitHub Actions matrix JSON
- `MatrixValidationError`: Raised when configuration is invalid

Key design decisions:
- Uses itertools.product for efficient Cartesian product calculation
- Supports dynamic dimension building (only includes non-empty dimensions)
- Exclude rules implemented as negative filtering
- Size validation occurs after include/exclude application

### CLI: `generate_matrix.py`

Command-line interface accepting:

```
python3 generate_matrix.py --config config.json [--output output.json]
```

- Loads JSON configuration
- Generates matrix
- Outputs to stdout (default) or file
- Graceful error handling with meaningful messages

## Testing Approach

Developed using TDD (Test-Driven Development):

### Test Suites (19 tests total, all passing)

1. **test_matrix_generator.py** (10 tests)
   - Basic matrix generation from OS and version specs
   - Max-parallel limit enforcement
   - Include rule application
   - Exclude rule application
   - Fail-fast configuration
   - Max-size validation
   - JSON output format validation

2. **test_config_loading.py** (4 tests)
   - Loading configuration from JSON files
   - Config with include/exclude rules
   - Empty configurations
   - All dimensions (OS, Python, Node, max-parallel, fail-fast, max-size)

3. **test_cli.py** (5 tests)
   - CLI basic matrix generation
   - Output to file
   - Missing config error handling
   - Invalid JSON error handling
   - Complex rules via CLI

### Test Execution

```bash
# Run all tests locally
python3 -m pytest tests/ -v

# Run through GitHub Actions (via act)
python3 test_through_act.py
```

## GitHub Actions Workflow

The `.github/workflows/environment-matrix-generator.yml` workflow:

**Triggers:**
- Push to main/master
- Pull requests to main/master
- Weekly schedule (Monday 9 AM)
- Manual dispatch (workflow_dispatch)

**Steps:**
1. Checkout code
2. Set up Python 3.12
3. Install pytest
4. Verify module imports
5. Run 19 unit tests
6. Execute integration tests with test fixtures
7. Validate JSON schema compliance
8. Test error handling
9. Final verification

**Permissions:** Read-only (contents:read)

**Validation:**
- Passes actionlint with no errors or warnings
- All tests run successfully in isolated Docker container
- Exit code 0 on success

## Usage Examples

### Basic Configuration

```json
{
  "os": ["ubuntu-latest", "windows-latest"],
  "python_version": ["3.10", "3.11"]
}
```

Generates 4 combinations (2×2).

### With Rules

```json
{
  "os": ["ubuntu-latest", "windows-latest"],
  "python_version": ["3.10", "3.11"],
  "max_parallel": 2,
  "fail_fast": false,
  "exclude": [
    {"os": "windows-latest", "python_version": "3.10"}
  ],
  "include": [
    {"os": "macos-latest", "python_version": "3.12"}
  ]
}
```

Generates 4 combinations (3 base - 1 excluded + 1 included).

### Output Format

All matrices follow GitHub Actions strategy.matrix schema:

```json
{
  "include": [
    {"os": "ubuntu-latest", "python_version": "3.10"},
    {"os": "ubuntu-latest", "python_version": "3.11"},
    {"os": "windows-latest", "python_version": "3.11"},
    {"os": "macos-latest", "python_version": "3.12"}
  ],
  "max-parallel": 2,
  "fail-fast": false
}
```

## Development Notes

### TDD Methodology Applied

1. Write failing test first (RED)
2. Implement minimal code to pass (GREEN)
3. Refactor for clarity and efficiency (REFACTOR)
4. Repeat for each feature

This approach ensured:
- Comprehensive test coverage (100% of public API)
- Clear specification of expected behavior
- Confidence in refactoring
- No untested code paths

### Key Implementation Details

- **Dimension Handling**: Iteratively builds from any non-empty dimension combination
- **Exclude Logic**: Checks if all fields in exclude rule match entry
- **Size Validation**: Validates after includes/excludes applied
- **JSON Compatibility**: Output is directly usable as `strategy.matrix` input

## Files

```
.
├── matrix_generator.py          # Core library
├── generate_matrix.py           # CLI interface
├── test_through_act.py         # Act test harness
├── .github/
│   └── workflows/
│       └── environment-matrix-generator.yml  # GitHub Actions workflow
├── tests/
│   ├── test_matrix_generator.py # Matrix generation tests
│   ├── test_config_loading.py  # Config file loading tests
│   ├── test_cli.py            # CLI integration tests
│   └── fixtures/
│       ├── config_basic.json
│       ├── config_with_rules.json
│       └── config_large.json
└── act-result.txt             # Test results from act execution
```

## Act Test Results

All tests pass when executed through GitHub Actions via `act`:

```
✓ Test cases run: 1
✓ Test cases passed: 1
✓ Test cases failed: 0
✓ All tests passed through act!
```

Exit code: 0 (success)

## Requirements

- Python 3.10+
- pytest (for testing)
- act (for GitHub Actions simulation)
- actionlint (for workflow validation)

No external dependencies required for the core library.
