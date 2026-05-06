# PR Label Assigner

A PowerShell-based tool that automatically assigns labels to GitHub pull requests based on changed file paths. Uses glob pattern matching with configurable rules and priority handling.

## Features

- **Glob Pattern Matching**: Supports `*` (any characters in segment), `**` (any directories), and `?` (single character)
- **Configurable Rules**: Define label rules in JSON configuration with pattern-to-label mappings
- **Priority Handling**: When multiple rules match the same file, rules with higher priority take precedence
- **Multiple Labels Per Rule**: Assign multiple labels from a single rule
- **Case-Sensitive Matching**: Patterns are matched case-sensitively
- **Comprehensive Testing**: 13 Pester tests covering all functionality

## Project Structure

```
├── PrLabelAssigner.ps1              # Core label assignment logic
│   ├── Get-PrLabels()               # Main function
│   └── Test-GlobMatch()             # Glob pattern matching
├── AssignPrLabels.ps1               # CLI entry point
├── label-config.json                # Default label rules configuration
├── Tests/
│   └── PrLabelAssigner.Tests.ps1    # Pester test suite (13 tests)
├── .github/workflows/
│   └── pr-label-assigner.yml        # GitHub Actions workflow
├── test-harness.ps1                 # Test harness for validation
└── act-result.txt                   # Test results artifact
```

## Quick Start

### Run Tests Locally

```powershell
# Run all Pester tests
Invoke-Pester Tests/PrLabelAssigner.Tests.ps1 -PassThru

# Run with verbose output
Invoke-Pester Tests/PrLabelAssigner.Tests.ps1 -PassThru -Verbose
```

### Use the Label Assigner Script

```powershell
# Assign labels using default config
./AssignPrLabels.ps1 -Files 'docs/README.md', 'src/api/endpoints.ps1', 'Tests/unit.test.ps1'

# Use custom config file
./AssignPrLabels.ps1 -ConfigFile custom-config.json -Files 'file1.ps1', 'file2.ps1'

# List all configured rules
./AssignPrLabels.ps1 -ListRules
```

### Run Test Harness

```powershell
# Run all validation tests
./test-harness.ps1

# Run with verbose output
./test-harness.ps1 -Verbose
```

## Configuration File Format

The `label-config.json` file defines all label rules:

```json
{
  "rules": [
    {
      "pattern": "docs/**",
      "labels": ["documentation"],
      "priority": 1
    },
    {
      "pattern": "src/api/**",
      "labels": ["api", "source"],
      "priority": 2
    },
    {
      "pattern": "*.test.ps1",
      "labels": ["tests", "unit-test"],
      "priority": 1
    }
  ]
}
```

### Pattern Syntax

- `**` - Matches any number of directories (e.g., `src/**/*.ps1` matches any `.ps1` file in `src` or subdirectories)
- `*` - Matches any characters in a single path segment (e.g., `*.md` matches markdown files in the current level)
- `?` - Matches a single character (e.g., `file?.txt` matches `file1.txt`, `file2.txt` but not `file10.txt`)

### Priority

- Higher priority rules override lower priority rules when patterns conflict
- When multiple rules have different patterns, all matching labels are applied
- When multiple rules with the **same pattern** match, only the highest priority rules' labels are used

## Test Coverage

The test suite includes 13 comprehensive tests:

1. **Single file with single matching rule** - Basic label assignment
2. **Single file with multiple matching rules** - Multiple labels from different patterns
3. **Multiple files** - Handling multiple files with label deduplication
4. **Priority handling** - Highest priority rules override lower priority
5. **No matching rules** - Empty result for files with no matches
6. **Single wildcard patterns** - `*.md` style patterns
7. **Double wildcard patterns** - `src/**/*.ps1` style patterns
8. **Multiple labels per rule** - Multiple labels from one rule
9. **Empty files list** - Handling empty input
10. **Empty rules list** - Handling empty rules
11. **Case sensitivity** - Patterns match case-sensitively
12. **Nested directory patterns** - Complex path patterns
13. **Question mark wildcards** - `?` character matching

Run tests with: `Invoke-Pester Tests/PrLabelAssigner.Tests.ps1 -PassThru`

## GitHub Actions Workflow

The workflow is defined in `.github/workflows/pr-label-assigner.yml` and includes three jobs:

### 1. Test Job
- Checks out code
- Installs PowerShell and dependencies
- Runs full Pester test suite
- **Validates**: All unit tests pass

### 2. Lint Job
- Validates workflow YAML with actionlint
- **Validates**: Workflow structure and action references

### 3. Integration Test Job
- Tests label assignment with sample files
- Tests list-rules option
- Tests with custom configuration
- **Validates**: Script works correctly in CI/CD pipeline

## Implementation Notes

### TDD Approach
The solution was built using red-green-TDD:
1. Write failing tests first
2. Implement minimum code to make tests pass
3. Refactor for clarity and robustness
4. Repeat for each feature

### Glob Pattern Implementation
Uses regex conversion with placeholders to avoid conflicts:
1. Escape dots first: `.` → `\.`
2. Use placeholders to avoid conflicts: `**` → `__DOUBLESTAR__`, `?` → `__QUESTION__`
3. Replace remaining wildcards: `*` → `[^/]*`
4. Replace placeholders: `__DOUBLESTAR__` → `.*`, `__QUESTION__` → `.`

### Case-Sensitive Matching
Uses `[regex]::IsMatch()` for case-sensitive matching instead of PowerShell's case-insensitive `-match` operator.

### Priority Logic
Groups matching rules by pattern, then filters to highest priority within each pattern group:
- Rules with identical patterns: only highest priority applies
- Rules with different patterns: all apply (not conflicting)

## Error Handling

The script includes graceful error handling for:
- Missing configuration files
- Invalid JSON in config
- Missing 'rules' array in config
- Missing required files or parameters

## Performance

- Test suite completes in ~2 seconds
- Label assignment is instant (< 100ms for typical PR files)
- Minimal memory footprint

## Requirements

- PowerShell 5.0 or later (tested with 7.6.1)
- Pester 5.0+ for running tests
- Standard library functionality only (no external dependencies)

## CI/CD Integration

The workflow validates on every push/PR and can be triggered manually. It ensures:
- All unit tests pass
- Workflow YAML is valid
- Script works correctly in GitHub Actions environment
- Configuration is properly formatted

## Troubleshooting

### Tests Fail
- Ensure you're running PowerShell 5.0 or later: `$PSVersionTable.PSVersion`
- Install/update Pester: `Install-Module -Name Pester -Force -MinimumVersion 5.0`

### Config Not Found
- Verify config file path is correct
- Use absolute path if relative path doesn't work
- Check file exists: `Test-Path label-config.json`

### Labels Not Applied
- Check pattern syntax with `-ListRules` option
- Verify file paths match pattern (case-sensitive!)
- Ensure config JSON is valid: `Get-Content label-config.json -Raw | ConvertFrom-Json`

## License

This project is provided as-is for use in GitHub Actions workflows and CI/CD pipelines.
