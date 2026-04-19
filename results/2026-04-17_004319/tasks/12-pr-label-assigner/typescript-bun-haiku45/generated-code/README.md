# PR Label Assigner

A TypeScript-based tool that automatically assigns labels to pull requests based on changed files using configurable glob pattern rules.

## Features

- **Glob Pattern Matching**: Support for standard glob patterns (e.g., `docs/**`, `src/api/**`, `*.test.*`)
- **Multiple Labels per File**: Files can match multiple rules and receive multiple labels
- **Priority Ordering**: Rules support priority field for conflict resolution
- **Deduplication**: Automatic removal of duplicate labels via Set data structure
- **GitHub Actions Integration**: Workflow file for CI/CD automation
- **Comprehensive Testing**: Full test suite with 10 test cases using Bun's test runner

## Architecture

### Core Components

1. **pr-label-assigner.ts** - Core logic
   - `LabelRule` interface: Pattern, labels array, priority
   - `globToRegex()`: Converts glob patterns to regex
   - `matchesPattern()`: Tests if file matches a pattern
   - `assignLabels()`: Main function returning deduplicated label set
   - `assignLabelsDetailed()`: Returns per-file label assignments

2. **cli.ts** - Command-line interface
   - Accepts files via CLI arguments or `CHANGED_FILES` environment variable
   - Loads custom rules from JSON file
   - Outputs labels as JSON

3. **pr-label-assigner.test.ts** - Test suite
   - 10 comprehensive test cases using Bun's test runner
   - Tests: basic matching, multiple labels, deduplication, mixed files, priority ordering

4. **.github/workflows/pr-label-assigner.yml** - GitHub Actions workflow
   - Triggered on: push, pull_request, workflow_dispatch
   - Installs dependencies, runs tests, assigns labels
   - Test mode for validation with mock data

## Usage

### Run Tests Locally

```bash
bun test
```

Expected output: 10 tests pass in ~17ms

### Run CLI

```bash
# With environment variable
CHANGED_FILES="docs/README.md,src/api/routes.ts" bun cli.ts

# With CLI argument
bun cli.ts --files "docs/README.md,src/api/routes.ts"

# Detailed output (per-file breakdown)
bun cli.ts --detailed --files "docs/README.md,src/api/routes.ts"
```

### Load Custom Rules

Create `rules.json`:
```json
[
  { "pattern": "docs/**", "labels": ["documentation"], "priority": 1 },
  { "pattern": "src/api/**", "labels": ["api"], "priority": 2 }
]
```

Run with custom rules:
```bash
bun cli.ts --rules-file rules.json --files "src/api/routes.ts"
```

## Default Label Rules

| Pattern | Labels | Priority |
|---------|--------|----------|
| `docs/**` | documentation | 1 |
| `src/api/**` | api | 2 |
| `src/**` | code | 3 |
| `*.test.*` | tests | 1 |
| `*.test.ts` | tests | 1 |
| `*.spec.*` | tests | 1 |
| `tests/**` | tests | 1 |
| `*.json` | configuration | 2 |
| `.github/**` | ci | 2 |
| `*.md` | documentation | 2 |
| `*.yml` | configuration | 2 |
| `*.yaml` | configuration | 2 |

## GitHub Actions Integration

The workflow runs automatically on:
- Push events to main/master
- Pull request events against main/master
- Manual workflow_dispatch trigger

### Workflow Steps

1. Checkout code
2. Setup Bun runtime
3. Install dependencies
4. Run tests (bun test)
5. Get changed files (for PR)
6. Assign labels using CLI
7. Create GitHub summary
8. Validate script files

## Development

### TDD Approach

All features implemented using red/green TDD:
1. Write failing test first
2. Implement minimum code to pass
3. Refactor for clarity

Example test from test suite:
```typescript
it("should assign multiple labels when file matches multiple patterns", () => {
  const files = ["src/api/routes.test.ts"];
  const result = assignLabels(files, labelRules);
  expect(result).toContain("api");
  expect(result).toContain("tests");
});
```

### Pattern Matching Algorithm

```typescript
function globToRegex(glob: string): RegExp {
  let pattern = glob
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")  // Escape special chars
    .replace(/\*/g, ".*")                    // * matches any chars
    .replace(/\?/g, ".");                    // ? matches single char
  return new RegExp(`^${pattern}$`);
}
```

## Testing with Act

Run the full GitHub Actions workflow locally:

```bash
# Single test run
act push --rm

# All tests (see act-result.txt for output)
bun run test-workflow.ts
```

Results are captured in `act-result.txt` with full Docker output.

## Type Safety

Strict TypeScript with explicit interfaces:
- `LabelRule`: Configuration structure
- `AssignedLabels`: Detailed output format

All functions have full type annotations and return types.

## Error Handling

- Missing files handled gracefully
- Empty file lists return empty label array
- Invalid JSON in rules file shows meaningful error
- Missing environment variable error message directs user to --files flag

## Performance

- Regex compilation happens on first use
- Set-based deduplication ensures O(1) duplicate removal
- Glob-to-regex conversion is O(pattern length)
- File matching is O(files × rules)

## Files

```
.
├── pr-label-assigner.ts          # Core logic (2.0 KB)
├── pr-label-assigner.test.ts     # Test suite (3.9 KB)
├── cli.ts                        # CLI interface (2.9 KB)
├── test-workflow.ts              # Act test harness
├── package.json                  # Project metadata
├── .actrc                        # Act configuration
├── .github/workflows/
│   └── pr-label-assigner.yml    # GitHub Actions workflow
└── README.md                     # This file
```

## Validation

✅ All 10 unit tests pass  
✅ Workflow passes actionlint validation  
✅ All 6 integration tests pass with act  
✅ act-result.txt generated with full output  
✅ All jobs report "Job succeeded"
