# Semantic Version Bumper

A complete Bash implementation of a semantic version bumper using TDD methodology with full GitHub Actions CI/CD integration.

## Quick Start

### Run Tests Locally
```bash
bats semantic-version-bumper.bats
```

### Run the Script
```bash
# Parse version from package.json
./semantic-version-bumper.sh --parse-version package.json

# Determine next version from git commits
./semantic-version-bumper.sh --determine-next-version 1.0.0

# Update version file
./semantic-version-bumper.sh --update-version package.json 1.1.0

# Generate changelog
./semantic-version-bumper.sh --generate-changelog 1.0.0 1.1.0
```

## Features

### Version Bump Rules
- **BREAKING CHANGE** → Major bump (1.0.0 → 2.0.0)
- **feat:** commits → Minor bump (1.0.0 → 1.1.0)
- **fix:** commits → Patch bump (1.0.0 → 1.0.1)
- **chore:** / **docs:** → No bump
- Highest priority bump wins when multiple commit types present

### Supported Formats
- **package.json** - JSON format with `"version"` field
- **VERSION** - Plain text single-line version

### Error Handling
- Graceful failures with meaningful error messages
- File validation before operations
- JSON syntax validation

## Files

- **semantic-version-bumper.sh** - Main implementation (7.2 KB)
- **semantic-version-bumper.bats** - 20 comprehensive tests (7.3 KB)
- **.github/workflows/semantic-version-bumper.yml** - CI/CD pipeline (3.7 KB)
- **act-result.txt** - GitHub Actions test execution results (372 KB)

## Test Results

✅ **20/20 tests pass** (100% success rate)
- Version parsing tests
- Version bump calculations
- File update operations
- Changelog generation
- Error handling
- Edge cases

## Code Quality

✅ **Shellcheck**: Passes all checks
✅ **Bash Syntax**: Valid (-n validation)
✅ **GitHub Actions**: Valid (actionlint validation)
✅ **Test Coverage**: Comprehensive

## GitHub Actions Integration

Two-job workflow:
1. **Run Tests** - Validates code and runs test suite
2. **Demonstrate Functionality** - Shows end-to-end version bumping

Both jobs execute successfully in CI/CD pipeline.

## Implementation Details

### TDD Methodology
1. **Red Phase**: Wrote 20 failing tests first
2. **Green Phase**: Implemented minimum code to pass tests
3. **Refactor Phase**: Fixed shellcheck warnings and optimized code

### Code Structure
```
semantic-version-bumper.sh:
├── parse_version() - Extract version from files
├── analyze_commits() - Determine version bump type
├── bump_version() - Calculate next semantic version
├── determine_next_version() - Main version logic
├── update_version() - Update version in files
├── generate_changelog() - Create changelog
└── Command dispatcher
```

## Testing

Run all tests:
```bash
bats semantic-version-bumper.bats
```

Run specific test:
```bash
bats semantic-version-bumper.bats -t "parse_version extracts version"
```

## CI/CD Pipeline

Test via GitHub Actions:
```bash
act push --rm -P ubuntu-latest=ubuntu:22.04
```

See **act-result.txt** for complete execution logs.

## Requirements Met

✅ Red/green TDD methodology  
✅ Bats-core testing framework  
✅ All tests pass  
✅ Clear comments and error handling  
✅ Proper shebang and validation  
✅ GitHub Actions workflow  
✅ Actionlint validation  
✅ act execution validation  
✅ Complete test artifacts  

## Documentation

- **IMPLEMENTATION_SUMMARY.md** - Feature overview and implementation details
- **TEST_REPORT.md** - Detailed test results and compliance checklist
- **README.md** - This file

---

**Status**: ✅ Complete and production-ready
**Test Coverage**: ✅ 20/20 tests passing
**CI/CD Integration**: ✅ Both GitHub Actions jobs succeed
