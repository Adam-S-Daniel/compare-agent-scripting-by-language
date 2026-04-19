# Environment Matrix Generator

A TypeScript/Bun implementation of a GitHub Actions build matrix generator supporting OS options, language versions, feature flags, include/exclude rules, and configuration validation.

## Project Structure

- **matrix-generator.ts** — Core matrix generation logic with support for:
  - Cartesian product generation of environment combinations
  - Include/exclude rule application
  - Max-parallel and fail-fast configuration
  - Matrix size validation

- **index.ts** — CLI entry point that reads JSON config files and outputs matrices

- **Tests**:
  - `matrix-generator.test.ts` — 9 unit tests covering all functionality
  - `integration.test.ts` — 5 integration tests verifying file I/O and JSON parsing
  - `workflow-runner.test.ts` — Workflow execution tests via act

- **GitHub Actions Workflow** — `.github/workflows/environment-matrix-generator.yml`
  - Installs Bun, runs tests, generates matrix examples
  - Validates with actionlint
  - Executes successfully via act

- **Test Fixtures**:
  - `fixtures/simple-config.json` — Basic 2×2 matrix
  - `fixtures/with-excludes.json` — Matrix with exclusions
  - `fixtures/with-features.json` — Matrix with features and options

## Usage

### Generate matrix from config file
```bash
bun run index.ts fixtures/simple-config.json
```

### Run tests
```bash
bun test
```

### Run specific test files
```bash
bun test matrix-generator.test.ts integration.test.ts
```

## Configuration Format

```json
{
  "os": ["ubuntu-22.04", "macos-14"],
  "nodeVersion": ["18", "20"],
  "features": ["default", "experimental"],
  "include": [
    { "os": "windows-2022", "nodeVersion": "18" }
  ],
  "exclude": [
    { "os": "macos-14", "nodeVersion": "18" }
  ],
  "maxParallel": 4,
  "failFast": true,
  "maxSize": 50
}
```

## Output Format

Generates valid GitHub Actions strategy.matrix JSON:
```json
{
  "include": [
    { "os": "ubuntu-22.04", "nodeVersion": "18" },
    { "os": "ubuntu-22.04", "nodeVersion": "20" }
  ],
  "exclude": [
    { "os": "macos-14", "nodeVersion": "18" }
  ],
  "maxParallel": 4,
  "failFast": true
}
```

## Test Results

**Unit Tests**: 9 pass
**Integration Tests**: 5 pass  
**Total**: 14 pass, 0 fail

**Workflow Execution**: All steps passed ✅
- Set up job
- Checkout code
- Install Bun
- Install dependencies
- Run tests (14 pass)
- Generate matrices from all fixtures
- Display results

**Validation**: actionlint passes ✅

## Implementation Notes

- Red/Green TDD: Tests written first, implementation follows
- Type-safe: Full TypeScript interfaces for configuration and output
- Error handling: Graceful failures with meaningful error messages
- Matrix validation: Enforces max size limits
- Cartesian product: Generates all combinations automatically
- Include/exclude: Flexible rule-based filtering

## Execution via Act

The workflow can be tested locally using act:
```bash
act push --rm
```

Complete execution output is captured in `act-result.txt` (116KB) demonstrating all workflow steps completing successfully.
