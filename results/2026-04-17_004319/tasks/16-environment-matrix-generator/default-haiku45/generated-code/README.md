# Environment Matrix Generator

A Python-based tool for generating GitHub Actions build matrices with support for OS versions, language versions, feature flags, include/exclude rules, and matrix size validation.

## Features

- **Cartesian Product Generation**: Automatically generate all combinations of OS versions, language versions, and feature flags
- **Include/Exclude Rules**: Specify specific combinations to include or exclude from the matrix
- **Configuration Options**: Support for max-parallel limits and fail-fast configuration
- **Size Validation**: Validate that the matrix doesn't exceed a maximum size before generation
- **JSON Output**: Generate valid GitHub Actions `strategy.matrix` JSON

## Quick Start

### Generate a matrix from configuration:

```bash
python3 generate_matrix.py config.json
```

### Generate and save to a file:

```bash
python3 generate_matrix.py config.json --output matrix.json
```

## Configuration

Configuration is specified as a JSON file:

```json
{
  "os_versions": ["ubuntu-latest", "macos-latest", "windows-latest"],
  "language_versions": ["3.9", "3.10", "3.11"],
  "feature_flags": ["debug", "verbose"],
  "exclude": [
    {
      "os": "windows-latest",
      "language_version": "3.9"
    }
  ],
  "max_parallel": 6,
  "fail_fast": true,
  "max_size": 256
}
```

### Configuration Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `os_versions` | array | Yes | List of OS versions to include |
| `language_versions` | array | Yes | List of language versions to include |
| `feature_flags` | array | No | List of feature flags to multiply with combinations (default: []) |
| `include` | array | No | Specific combinations to include (overrides auto-generation) |
| `exclude` | array | No | Combinations to exclude from the generated matrix |
| `max_parallel` | integer | No | Maximum number of parallel jobs |
| `fail_fast` | boolean | No | Whether to fail fast on first failure (default: true) |
| `max_size` | integer | No | Maximum allowed matrix size (default: 256) |

## Output Format

The generator produces valid GitHub Actions `strategy.matrix` JSON:

```json
{
  "include": [
    {
      "os": "ubuntu-latest",
      "language_version": "3.9",
      "feature_flag": "debug"
    },
    ...
  ],
  "fail-fast": true,
  "max-parallel": 6,
  "exclude": [
    {
      "os": "windows-latest",
      "language_version": "3.9"
    }
  ]
}
```

## Testing

Run the complete test suite:

```bash
python3 -m pytest tests/test_matrix_generator.py -v
```

The test suite includes:
- Basic matrix generation from OS/language combinations
- Feature flag multiplication
- Include/exclude rule handling
- Configuration validation
- Matrix size validation
- JSON serialization
- Error handling for edge cases

### Test Categories

1. **TestBasicMatrixGeneration**: Cartesian product generation
2. **TestFeatureFlags**: Feature flag handling
3. **TestIncludeExcludeRules**: Include/exclude rule functionality
4. **TestMatrixConfiguration**: Configuration options (max-parallel, fail-fast)
5. **TestMatrixValidation**: Size validation and error handling
6. **TestJSONOutput**: JSON serialization
7. **TestEdgeCases**: Error handling and edge cases

## GitHub Actions Workflow

The included GitHub Actions workflow (`.github/workflows/environment-matrix-generator.yml`) demonstrates:

1. Running all unit tests
2. Generating a matrix from configuration
3. Validating the generated matrix structure
4. Testing exclude rules
5. Testing error handling

### Trigger Events

The workflow is triggered by:
- Push events to main/master branches
- Pull requests
- Manual workflow dispatch (with optional config file input)

## Examples

### Example 1: Simple Matrix

```json
{
  "os_versions": ["ubuntu-latest"],
  "language_versions": ["3.9", "3.10"]
}
```

Generates 2 combinations.

### Example 2: With Feature Flags

```json
{
  "os_versions": ["ubuntu-latest", "macos-latest"],
  "language_versions": ["3.9"],
  "feature_flags": ["debug", "verbose"]
}
```

Generates 4 combinations (2 OS × 1 language × 2 flags).

### Example 3: With Exclusions

```json
{
  "os_versions": ["ubuntu-latest", "macos-latest", "windows-latest"],
  "language_versions": ["3.9", "3.10"],
  "exclude": [
    {"os": "windows-latest", "language_version": "3.9"}
  ]
}
```

Generates 5 combinations (3 OS × 2 languages - 1 excluded).

## Architecture

### Core Components

- **`MatrixConfig`**: Dataclass representing the configuration
- **`MatrixGenerator`**: Main class that generates the matrix
- **`MatrixValidationError`**: Exception raised for validation failures

### Methods

- `generate()`: Generate and return the matrix dictionary
- `to_json()`: Return the matrix as a JSON string
- `_generate_combinations()`: Create cartesian product of inputs
- `_apply_excludes()`: Filter out excluded combinations
- `_validate_config()`: Validate configuration before generation

## Error Handling

The tool provides meaningful error messages for:

- Empty OS versions or language versions
- Matrix size exceeding the maximum
- Invalid configuration files
- JSON parsing errors
- Missing configuration fields

## Performance

The generator is optimized for:
- Fast cartesian product generation
- Early validation to catch oversized matrices
- Memory-efficient list operations
- JSON serialization with standard library

## Requirements

- Python 3.12+
- pytest (for running tests)

## License

Part of the Agent Scripting Language Comparison Benchmark
