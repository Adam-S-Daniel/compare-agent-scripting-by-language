# Semantic Version Bumper

A Bash-based semantic version bumper that parses version files, analyzes conventional commit messages, and automatically bumps versions according to semantic versioning rules.

## Overview

This project implements a complete CI/CD pipeline for automatic semantic version management:

- **Parse** version from `package.json` or `VERSION` files
- **Analyze** conventional commits (feat → minor, fix → patch, breaking → major)
- **Bump** version numbers following semantic versioning
- **Generate** changelog entries from commits
- **Validate** with comprehensive test suite and GitHub Actions workflow

## Features

✓ **Semantic Versioning** - Automatically determines version bumps:
- `feat:` commits → minor version increment
- `fix:` commits → patch version increment
- `feat!:` or `BREAKING CHANGE:` → major version increment

✓ **Multi-Format Support** - Works with:
- `package.json` files (JSON format)
- Plain `VERSION` files (text format)

✓ **Changelog Generation** - Creates structured changelog entries with:
- Breaking changes section (if applicable)
- Features section
- Bug fixes section

✓ **TDD Methodology** - Built with red/green/refactor:
- 12 comprehensive test cases
- 100% test pass rate
- Fixtures for common scenarios

✓ **GitHub Actions Integration** - Full CI/CD workflow:
- Runs bats tests in container
- Validates script syntax and shellcheck
- Demonstrates version bumping with live examples
- All jobs pass successfully via `act`

## File Structure

```
.
├── semver-bumper.sh              # Main script (~170 lines)
├── tests/
│   ├── test_semver.bats          # 12 bats test cases
│   └── fixtures.sh               # Test fixture helpers
├── .github/workflows/
│   └── semantic-version-bumper.yml # GitHub Actions workflow
├── act-result.txt                # Act execution results
└── README.md                     # This file
```

## Usage

### Local Usage

```bash
# Source the script
source semver-bumper.sh

# Parse current version
current=$(parse_version "package.json")
echo "Current version: $current"

# Determine bump type from git commits
bump_type=$(get_bump_type "HEAD~5" "HEAD")
echo "Bump type: $bump_type"

# Calculate new version
new=$(bump_version "$current" "$bump_type")
echo "New version: $new"

# Update version file
update_version "package.json" "$new"

# Generate changelog
changelog=$(generate_changelog_entry "HEAD~5" "HEAD" "$new")
echo "$changelog" > CHANGELOG.md
```

### Full Workflow

```bash
# Run the complete version bumping flow
new_version=$(main_flow "package.json" "HEAD~1" "HEAD")
echo "Bumped to: $new_version"
cat CHANGELOG_ENTRY.md
```

## Running Tests

### Local Tests with Bats

```bash
# Run all tests
bats tests/test_semver.bats

# Run specific test
bats tests/test_semver.bats --filter "parse_version"
```

### GitHub Actions Workflow

```bash
# Test locally with act
act push --rm

# The workflow will:
# 1. Install dependencies (bats)
# 2. Run 12 test cases
# 3. Validate script syntax
# 4. Demonstrate version bumping
# 5. Verify changelog generation
```

## Test Results

All tests passing (12/12):

```
✓ parse_version extracts version from package.json
✓ parse_version extracts version from VERSION file
✓ bump_version increments patch for fix commits
✓ bump_version increments minor for feat commits
✓ bump_version increments major for breaking changes
✓ get_bump_type returns major for BREAKING CHANGE
✓ get_bump_type returns minor for feat commit
✓ get_bump_type returns patch for fix commit
✓ update_version modifies package.json correctly
✓ update_version modifies VERSION file correctly
✓ generate_changelog_entry creates proper entry
✓ main flow: parse, bump, update, changelog
```

### Act Execution Results

All jobs succeeded:
- ✓ Validate Script (shellcheck, bash -n)
- ✓ Run Tests (all 12 bats tests passed)
- ✓ Demo Version Bumping (1.0.0 → 1.1.0)

See `act-result.txt` for full execution log.

## Implementation Details

### Version Parsing

Supports multiple JSON formats with flexible whitespace handling:
```bash
# Compact JSON
{"version":"1.0.0"}

# Formatted JSON with spaces
{
  "version": "1.0.0"
}

# Plain text VERSION files
1.0.0
```

### Semantic Version Bumping

```bash
# Patch bump: increment last number
1.0.0 → 1.0.1

# Minor bump: increment middle number, reset patch
1.0.0 → 1.1.0

# Major bump: increment first number, reset minor and patch
1.0.0 → 2.0.0
```

### Conventional Commit Parsing

Analyzes git log between two commits:
- `feat:` or `feat(scope):` → minor version
- `feat!:` or commits with `BREAKING CHANGE` → major version
- `fix:` or `fix(scope):` → patch version

### Error Handling

- Validates file existence before reading
- Checks for valid semantic version format
- Handles git operations gracefully
- Provides meaningful error messages

## Code Quality

- ✓ Passes `shellcheck` validation (no warnings)
- ✓ Passes `bash -n` syntax check
- ✓ Uses `#!/usr/bin/env bash` shebang
- ✓ Proper error handling with `set -euo pipefail`
- ✓ Clear comments explaining approach
- ✓ Follows bash best practices

## GitHub Actions Workflow

The workflow (`.github/workflows/semantic-version-bumper.yml`) includes:

**Triggers:**
- On push to main, master, develop
- On pull requests
- Manual workflow_dispatch

**Jobs:**
1. **Test Job** - Runs 12 bats test cases
2. **Demo Job** - Demonstrates version bumping with live example
3. **Validate Job** - Validates script syntax and shellcheck

**Steps:**
- Checkout code
- Install dependencies (bats via apt-get)
- Run tests and validations
- Execute semantic version bumper
- Verify results

## Validation Results

✓ **actionlint** - Workflow YAML validation: PASSED
✓ **shellcheck** - Script linting: PASSED
✓ **bash -n** - Syntax validation: PASSED
✓ **bats** - Unit tests: 12/12 PASSED
✓ **act** - CI/CD simulation: All 3 jobs PASSED

## Dependencies

- Bash 4.0+
- Git
- Standard Unix utilities (grep, sed, head, cut, etc.)
- bats-core (for testing, optional for runtime)

## License

This is a demonstration project for semantic version management.

## Notes

- This implementation follows TDD methodology - tests were written first
- All 12 test cases pass both locally and through GitHub Actions
- The workflow successfully executes in act containers
- Version files are properly updated and changelog entries are generated
