# Environment Matrix Generator

A TypeScript/Bun tool for generating GitHub Actions build matrices from configuration files. Supports OS options, language versions, feature flags, include/exclude rules, and validation.

## Installation

```bash
bun install
```

## Running Tests

All tests are written in TDD style and use Bun's built-in test runner:

```bash
bun test
```

**Output:** 10 tests covering all functionality (all passing)

## Usage

### From File

```bash
bun run cli.ts config.json
```

### From stdin

```bash
cat config.json | bun run cli.ts
```

## Configuration Format

```json
{
  "os": ["ubuntu-latest", "macos-latest"],
  "language": ["node@18", "node@20"],
  "features": ["esm", "cjs"],
  "maxParallel": 6,
  "failFast": false,
  "maxSize": 256,
  "exclude": [
    {"os": "windows-latest", "language": "node@18"}
  ],
  "include": [
    {"os": "custom-runner", "language": "node@21", "experimental": "true"}
  ]
}
```

### Configuration Options

- **os** (required): Array of operating systems
- **language** (required): Array of language versions
- **features** (optional): Array of feature flags - adds as additional dimension
- **maxParallel** (required): Max parallel jobs (set in strategy.matrix)
- **failFast** (required): Cancel other jobs on first failure
- **maxSize** (optional): Maximum matrix size before error (default: 256)
- **exclude** (optional): Array of combinations to exclude
- **include** (optional): Array of custom combinations to add

## Output

The tool outputs a GitHub Actions `strategy.matrix` compatible JSON:

```json
{
  "include": [
    {"os": "ubuntu-latest", "language": "node@18"},
    {"os": "ubuntu-latest", "language": "node@20"},
    ...
  ],
  "maxParallel": 6,
  "failFast": false
}
```

## GitHub Actions Integration

The workflow file `.github/workflows/environment-matrix-generator.yml` demonstrates:
- Checkout code with actions/checkout@v4
- Setup Bun with oven-sh/setup-bun@v1
- Run all tests
- Validate matrix generation
- Test exclusion/inclusion rules
- Validate JSON output format

Run locally with:

```bash
act push -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

## Implementation Details

### Core Components

1. **matrix-generator.ts**: Core implementation with types
   - `generateMatrix()`: Main generation function
   - `createCartesianProduct()`: Creates OS × language combinations
   - `expandWithFeatures()`: Adds feature dimension
   - `applyExcludes()`: Filters out excluded combinations

2. **cli.ts**: CLI interface
   - Reads JSON from file or stdin
   - Outputs matrix JSON to stdout
   - Error handling with exit codes

3. **matrix-generator.test.ts**: 10 comprehensive tests covering:
   - Basic matrix generation
   - Cartesian product expansion
   - Feature flag handling
   - Exclude rules
   - Include rules
   - Matrix size validation
   - Configuration options
   - JSON output validity

## Architecture

The tool uses a functional approach with pure functions:

1. **Input Validation**: Ensures required arrays are present
2. **Cartesian Product**: Creates all combinations of OS × language
3. **Feature Expansion**: For each feature, creates a copy of all combinations
4. **Exclude Rules**: Filters out unwanted combinations
5. **Size Validation**: Checks against maxSize limit
6. **Include Rules**: Appends additional custom combinations
7. **Output**: Wraps in GitHub Actions matrix format

## Error Handling

The tool provides clear error messages:

```
Error: Matrix size 9 exceeds maximum matrix size of 5
Error: OS array is required and cannot be empty
Error: Language array is required and cannot be empty
```

All errors exit with code 1, while success exits with code 0.

## Testing

### Local Testing
```bash
bun test
```

### GitHub Actions Testing
```bash
# Validate workflow syntax
actionlint .github/workflows/environment-matrix-generator.yml

# Run workflow locally
act push -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

## Type Safety

Full TypeScript type coverage:

```typescript
interface MatrixEntry { [key: string]: string }
interface GitHubMatrix { 
  include: MatrixEntry[]
  exclude?: MatrixEntry[]
  maxParallel?: number
  failFast?: boolean
}
interface MatrixConfig {
  os: string[]
  language: string[]
  features?: string[]
  exclude?: MatrixEntry[]
  include?: MatrixEntry[]
  maxSize?: number
  maxParallel: number
  failFast: boolean
}
interface MatrixResult {
  matrix: GitHubMatrix
  error?: string
}
```

## License

MIT
