# Secret Rotation Validator

A TypeScript/Bun-based tool that validates secret rotation status, identifies expired or expiring secrets, and generates rotation reports in multiple formats.

## Features

- **Secret Expiration Detection**: Identifies secrets that have exceeded their rotation policy window
- **Warning Window**: Configurable warning period for upcoming expirations (default: 7 days)
- **Multiple Output Formats**: Supports Markdown tables and JSON reports
- **Urgent Categorization**: Groups secrets by status (expired, warning, ok)
- **CLI Interface**: Command-line tool for reading JSON configurations and generating reports
- **GitHub Actions Integration**: Automated workflow for periodic secret validation
- **Comprehensive Testing**: 38 test cases covering all functionality

## Project Structure

```
├── validator.ts                      # Core validation logic
├── cli.ts                            # CLI interface
├── validator.test.ts                 # Core functionality tests (12 tests)
├── fixtures.test.ts                  # CLI integration tests (4 tests)
├── workflow.test.ts                  # Workflow validation tests (22 tests)
├── secrets-config.json               # Sample configuration file
├── package.json                      # Project dependencies
└── .github/
    └── workflows/
        └── secret-rotation-validator.yml  # GitHub Actions workflow
```

## Installation

```bash
bun install
```

## Usage

### Running Tests

```bash
bun test
```

All 38 tests will run and pass.

### Using the CLI

```bash
bun run cli.ts <config-file> [format]
```

**Arguments:**
- `<config-file>`: Path to JSON configuration file (default: `secrets-config.json`)
- `[format]`: Output format - `markdown`, `json`, or `both` (default: `markdown`)

**Example:**
```bash
bun run cli.ts secrets-config.json markdown
bun run cli.ts secrets-config.json json
```

### Configuration File Format

```json
{
  "secrets": [
    {
      "name": "database-password",
      "lastRotated": "2026-03-22",
      "rotationPolicyDays": 30,
      "requiredBy": ["api-service", "web-app"]
    }
  ],
  "warningWindowDays": 7,
  "referenceDate": "2026-05-06"
}
```

**Configuration Fields:**
- `secrets[]`: Array of secret objects
  - `name`: Secret identifier
  - `lastRotated`: ISO date string of last rotation
  - `rotationPolicyDays`: Number of days between rotations
  - `requiredBy`: Array of services using this secret
- `warningWindowDays`: Days before expiry to show warning (optional, default: 7)
- `referenceDate`: Reference date for calculations (optional, uses current date)

## Output Examples

### Markdown Format

```markdown
## 🔴 Expired Secrets

| Name | Days Old | Days Until Expiry | Policy (days) | Required By |
|---|---|---|---|---|
| database-password | 45 | -15 | 30 | api-service, web-app |

## 🟡 Warning

| Name | Days Old | Days Until Expiry | Policy (days) | Required By |
|---|---|---|---|---|
| jwt-signing-key | 25 | 5 | 30 | auth-service |

## 🟢 OK

| Name | Days Old | Days Until Expiry | Policy (days) | Required By |
|---|---|---|---|---|
| oauth-client-secret | 11 | 79 | 90 | oauth-provider |
```

### JSON Format

```json
{
  "expired": [
    {
      "name": "database-password",
      "status": "expired",
      "lastRotated": "2026-03-22T00:00:00.000Z",
      "daysOld": 45,
      "rotationPolicyDays": 30,
      "daysUntilExpiry": -15,
      "requiredBy": ["api-service", "web-app"]
    }
  ],
  "warning": [],
  "ok": [],
  "generatedAt": "2026-05-06T00:00:00.000Z"
}
```

## Exit Codes

- **0**: All secrets are within rotation policy
- **1**: One or more secrets are expired or error occurred

## GitHub Actions Workflow

The workflow at `.github/workflows/secret-rotation-validator.yml` provides automated secret validation:

**Triggers:**
- Push to main/master branches
- Pull requests to main/master branches
- Daily schedule at 9 AM UTC
- Manual trigger via workflow_dispatch

**Steps:**
1. Checkout code
2. Setup Bun runtime
3. Run test suite
4. Validate secrets (markdown output)
5. Validate secrets (JSON output)
6. Generate summary report

**Workflow Validation:**
- ✅ Passes actionlint validation
- ✅ Valid YAML syntax
- ✅ Proper action references (pinned to v4)
- ✅ Executes successfully through `act`

## Test Coverage

### Unit Tests (validator.test.ts)
- Secret expiration detection (expired, warning, ok statuses)
- Multiple secret categorization
- Days calculation accuracy
- Metadata preservation
- Markdown report generation
- JSON serialization

### Integration Tests (fixtures.test.ts)
- JSON configuration file parsing
- CLI markdown output
- CLI JSON output
- Error code handling
- Missing file handling

### Workflow Tests (workflow.test.ts)
- YAML structure validation
- Required jobs and steps verification
- Trigger event configuration
- Action references and versioning
- File reference validation
- actionlint compliance

## Technology Stack

- **Language**: TypeScript
- **Runtime**: Bun v1.3.11+
- **Testing**: Bun's built-in test runner
- **CI/CD**: GitHub Actions
- **Dependencies**: yaml (for workflow parsing)

## Implementation Details

### TDD Approach

The project was built using red-green TDD methodology:
1. Write failing test → Red phase
2. Implement minimum code → Green phase
3. Refactor → Refactor phase

### Key Functions

- `detectExpiredSecrets()`: Analyzes secrets and categorizes by status
- `generateMarkdownReport()`: Creates formatted markdown tables
- `generateJsonReport()`: Serializes report to JSON
- `daysBetween()`: Calculates days between dates (UTC-aware)

### Error Handling

- Graceful CLI error messages
- Exit codes indicate success/failure
- Configuration validation before processing
- File existence checks

## Verification

### Run Tests
```bash
bun test
# Output: 38 pass, 0 fail
```

### Validate Workflow
```bash
actionlint .github/workflows/secret-rotation-validator.yml
# Output: Clean validation (no errors)
```

### Run Through Act
```bash
act push --rm
# Output: Job succeeded
```

### Check Results
```bash
cat act-result.txt
# Verification of all steps and outputs
```
