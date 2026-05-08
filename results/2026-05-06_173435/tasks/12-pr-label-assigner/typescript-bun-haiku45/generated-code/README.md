# PR Label Assigner

A TypeScript/Bun-based tool that automatically assigns GitHub PR labels based on changed file paths using configurable glob pattern matching rules.

## Features

- **Glob Pattern Matching**: Support for complex glob patterns (e.g., `docs/**`, `*.test.ts`, `src/api/**`)
- **Multiple Labels per File**: A single file can match multiple rules and receive multiple labels
- **Label Deduplication**: Automatically deduplicates labels across all matched rules
- **Priority Ordering**: Support for rule priorities to handle conflicts (lower priority number = higher priority)
- **Configuration-Driven**: Load rules from a JSON configuration file
- **CLI Interface**: Command-line tool for integration with CI/CD pipelines
- **Comprehensive Testing**: Unit tests using Bun's test runner with TDD methodology

## Installation

```bash
bun install
```

## Usage

### Unit Tests

Run all tests:

```bash
bun test
```

### CLI Usage

```bash
# Provide files as command arguments
bun run cli.ts docs/README.md src/api/users.ts src/ui/Button.tsx

# Or use environment variable with JSON array
CHANGED_FILES='["docs/API.md","src/api/auth.ts",".github/workflows/ci.yml"]' bun run cli.ts
```

## Configuration

Create a `label-config.json` file in the project root:

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
      "labels": ["api"],
      "priority": 2
    },
    {
      "pattern": "src/ui/**",
      "labels": ["ui"],
      "priority": 2
    },
    {
      "pattern": "*.test.ts",
      "labels": ["tests"],
      "priority": 3
    }
  ]
}
```

### Configuration Schema

- **pattern**: Glob pattern to match file paths (uses minimatch)
- **labels**: Array of labels to assign when pattern matches
- **priority** (optional): Priority number for conflict resolution (lower = higher priority)

## GitHub Actions Integration

The included workflow file (`.github/workflows/pr-label-assigner.yml`) automatically:

1. Runs all unit tests
2. Executes CLI tests with mock data
3. Validates the label configuration
4. Works with `act` for local testing

### Running Locally with act

```bash
act push --container-architecture linux/amd64 -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

## Test Results

The solution includes comprehensive tests covering:

- ✅ Single label assignment (7 basic functionality tests)
- ✅ Multiple labels per file
- ✅ Multiple files with different rules
- ✅ Glob pattern matching with `*` and `**`
- ✅ Label deduplication
- ✅ Priority ordering
- ✅ Configuration loading from JSON
- ✅ Error handling for invalid configs
- ✅ Complete PR workflow integration
- ✅ CLI tests with mock data
- ✅ GitHub Actions workflow validation

**Total: 11 unit tests (all passing)**

## Architecture

### Core Modules

1. **label-assigner.ts**: Core logic for label assignment
   - `assignLabels()`: Main function to assign labels to files
   - `loadConfig()`: Load configuration from JSON file
   - `getLabelsForPR()`: PR workflow wrapper

2. **cli.ts**: Command-line interface
   - Reads configuration
   - Accepts files from arguments or environment variable
   - Outputs results in both human-readable and JSON format

3. **label-assigner.test.ts**: Comprehensive test suite
   - Unit tests for all functionality
   - Configuration loading tests
   - Integration tests

### Design Decisions

- **TDD Methodology**: Started with failing tests, implemented minimum code, then refactored
- **Type Safety**: Full TypeScript with explicit interfaces and type annotations
- **Glob Library**: Uses `minimatch` for robust glob pattern matching
- **Configuration File**: JSON-based configuration for easy customization
- **Deduplication**: Uses `Set` for automatic label deduplication
- **Error Handling**: Graceful error messages with meaningful context

## Files

- `label-assigner.ts` - Core label assignment logic (62 lines)
- `cli.ts` - Command-line interface (48 lines)
- `label-assigner.test.ts` - Test suite (91 lines)
- `label-config.json` - Configuration file with rule examples
- `.github/workflows/pr-label-assigner.yml` - GitHub Actions workflow
- `package.json` - Project configuration with dependencies

## Example Output

```
Changed files: 4
Assigned labels: [ "api", "code", "documentation", "tests", "ui" ]
Labels (JSON): ["api","code","documentation","tests","ui"]
```

## Dependencies

- **minimatch**: ^9.0.5 - Glob pattern matching library
- **bun**: Built-in test runner

## License

MIT
