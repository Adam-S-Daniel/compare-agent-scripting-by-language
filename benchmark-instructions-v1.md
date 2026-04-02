# Benchmark Instructions v1

**Version**: v1
**Date**: 2026-04-02
**Purpose**: Measure how well Claude Code agents perform scripting tasks across different language constraints.

## Methodology

### Overview

Each scripting task is executed by a Claude Code agent under 4 different language constraints ("modes") and with 2 different models, yielding **8 runs per task**. Agents receive only the prompt — no conversation context, no prior results.

### Models

| Model ID | Short Name | Input $/Mtok | Output $/Mtok | Cache Read $/Mtok | Cache Write $/Mtok |
|----------|------------|-------------|--------------|-------------------|-------------------|
| claude-opus-4-6 | opus | $15.00 | $75.00 | $1.50 | $18.75 |
| claude-sonnet-4-6 | sonnet | $3.00 | $15.00 | $0.30 | $3.75 |

### Language Modes

1. **default** — No language specified. The agent chooses whatever language it considers best.
2. **powershell** — The agent must use PowerShell.
3. **powershell-strict** — The agent must use PowerShell with strict mode enabled (`Set-StrictMode -Latest`, `$ErrorActionPreference = 'Stop'`), strongly-typed parameters (e.g., `[string]$Name`, `[int]$Count`), and typed function return values (e.g., `[OutputType([int])]`).
4. **csharp-script** — The agent must use C# via .NET 10 file-based apps (top-level statements in `.cs` files, executed with `dotnet run <file>.cs`).

### TDD Requirement

Every prompt instructs the agent to use **red/green TDD**:
1. Write a failing test first.
2. Write the minimum code to make it pass.
3. Refactor.
4. Repeat for each piece of functionality.
5. Create mocks and test fixtures as necessary.

### Tool Installation

Agents are responsible for installing any tools they need (PowerShell, .NET SDK, Pester, test frameworks, etc.). The runner does **not** pre-install anything. Time spent on tool installation is captured as part of the total run duration and is also extracted separately as `tool_install_duration_ms` by analyzing the CLI stream for install-related commands and their durations.

### Execution

- Tasks run **sequentially** (one at a time).
- Each agent runs in an **isolated workspace directory** containing only a copy of this instructions file.
- No conversation context or prior run data is passed to the agent.

---

## Tasks

### Task 01: CSV Report Generator
**Category**: Data Transformation

Read a CSV file of employee records (name, department, salary, hire_date, status), filter to active employees only, compute aggregates (average salary by department, headcount by department, overall statistics), and output a formatted summary report to a text file. Create sample CSV test data as part of the test fixtures.

### Task 02: Log File Analyzer
**Category**: Text Processing

Parse a log file containing mixed formats (syslog-style lines and JSON-structured lines), extract all error and warning entries, produce a frequency table of error types with their first and last occurrence timestamps, and output the analysis as both a human-readable table and a JSON file. Create sample log data as test fixtures.

### Task 03: Directory Tree Sync
**Category**: File Manipulation

Compare two directory trees, identify files that differ (by content hash — SHA-256), files that exist in only one tree, and generate a sync plan. Implement both a dry-run mode (report only) and an execute mode (perform the sync). All file operations should be testable with mock directory structures.

### Task 04: REST API Client
**Category**: API Interaction

Build a script that queries a REST API (use JSONPlaceholder — https://jsonplaceholder.typicode.com), fetches posts and their comments, handles pagination, implements retry with exponential backoff on failure, and caches results locally in JSON files. Mock the HTTP calls for testing.

### Task 05: Process Monitor
**Category**: System Administration

Create a script that reads process information (CPU%, memory, PID, name), filters by configurable resource usage thresholds, identifies the top N resource consumers, and generates an alert report. All process data must be mockable for testing — do not rely on live system state in tests.

### Task 06: Config File Migrator
**Category**: Data Transformation

Read a configuration file in INI format, validate it against a simple schema (required keys, value types), and output equivalent configurations in JSON and YAML formats. Handle sections, comments, multi-line values, and type coercion (strings to numbers/booleans where appropriate). Create test fixtures with various edge cases.

### Task 07: Batch File Renamer
**Category**: File Automation

Rename files in a directory using regex-based patterns. Support: preview mode (show what would change without doing it), undo capability (generate an undo script that reverses the renames), and conflict detection (two files would get the same name). Test with mock file system structures.

### Task 08: Database Seed Script
**Category**: Process Automation

Create a SQLite database with a schema (users, orders, products tables with foreign keys), generate realistic mock data using deterministic randomization (seeded RNG), insert the data respecting referential integrity, and run verification queries that confirm data consistency. Tests should verify schema, data integrity, and query results.

### Task 09: Error Retry Pipeline
**Category**: Error Handling

Build a pipeline that processes items from a queue (mocked), where processing can fail randomly. Implement: exponential backoff retry (configurable max retries), dead-letter queue for permanently failed items, progress reporting (items processed, failed, retrying), and a final summary. All queue and processing operations must be mockable.

### Task 10: Multi-file Search and Replace
**Category**: Text Processing

Recursively search files matching a glob pattern for a regex pattern, perform search-and-replace with: preview mode (show matches with context without modifying), backup creation (copy originals before modifying), and a summary report of all changes made (file, line number, old text, new text). Test with mock directory structures and files.

### Task 11: Semantic Version Bumper
**Category**: GitHub Actions / Release Automation

Parse a version file (or package.json) containing a semantic version string, determine the next version based on conventional commit messages (feat → minor, fix → patch, breaking → major), update the version file, generate a changelog entry from the commits, and output the new version. Create mock commit logs as test fixtures.

### Task 12: PR Label Assigner
**Category**: GitHub Actions / Triage

Given a list of changed file paths (simulating a PR's changed files), apply labels based on configurable path-to-label mapping rules (e.g., `docs/**` → "documentation", `src/api/**` → "api", `*.test.*` → "tests"). Support glob patterns, multiple labels per file, and priority ordering when rules conflict. Output the final label set. Mock the file list for testing.

### Task 13: Dependency License Checker
**Category**: GitHub Actions / Compliance

Parse a dependency manifest (package.json, requirements.txt, or similar), extract dependency names and versions, check each against an allow-list and deny-list of licenses (provided as config), and generate a compliance report listing each dependency's license status (approved, denied, unknown). Mock the license lookup for testing.

### Task 14: Docker Image Tag Generator
**Category**: GitHub Actions / CI/CD

Given git context (branch name, commit SHA, tags, PR number — all provided as mock inputs), generate appropriate Docker image tags following common conventions: `latest` for main, `pr-{number}` for PRs, `v{semver}` for tags, `{branch}-{short-sha}` for feature branches. Handle tag sanitization (lowercase, no special chars). Output the tag list.

### Task 15: Test Results Aggregator
**Category**: GitHub Actions / CI Reporting

Parse test result files in multiple formats (JUnit XML, and JSON), aggregate results across multiple files (simulating a matrix build), compute totals (passed, failed, skipped, duration), identify flaky tests (passed in some runs, failed in others), and generate a markdown summary suitable for a GitHub Actions job summary. Create sample test result files as fixtures.

### Task 16: Environment Matrix Generator
**Category**: GitHub Actions / CI Configuration

Given a configuration describing OS options, language versions, and feature flags, generate a build matrix (as JSON) suitable for GitHub Actions `strategy.matrix`. Support include/exclude rules, max-parallel limits, and fail-fast configuration. Validate that the matrix doesn't exceed a maximum size. Output the complete matrix JSON.

### Task 17: Artifact Cleanup Script
**Category**: GitHub Actions / Maintenance

Given a list of artifacts with metadata (name, size, creation date, workflow run ID — provided as mock data), apply retention policies (max age, max total size, keep-latest-N per workflow), determine which artifacts to delete, and generate a deletion plan with a summary (total space reclaimed, artifacts retained vs deleted). Support dry-run mode.

### Task 18: Secret Rotation Validator
**Category**: GitHub Actions / Security

Given a configuration of secrets with metadata (name, last-rotated date, rotation policy in days, required-by services — all mock data), identify secrets that are expired or expiring within a configurable warning window, generate a rotation report, and output notifications grouped by urgency (expired, warning, ok). Support multiple output formats (markdown table, JSON).

---

## Prompt Templates

### Default Mode
```
You are completing a scripting task. Choose whatever programming language you think is best for this task.

TASK: {task_description}

REQUIREMENTS:
1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.
2. Create mocks and test fixtures as necessary for testability.
3. All tests must be runnable and must pass at the end.
4. Include clear comments explaining your approach.
5. Handle errors gracefully with meaningful error messages.

Create your solution in the current working directory. Start by writing your first failing test.
```

### PowerShell Mode
```
You are completing a scripting task. You MUST use PowerShell as your implementation language.

TASK: {task_description}

REQUIREMENTS:
1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.
2. Create mocks and test fixtures as necessary for testability. Use Pester as the testing framework.
3. All tests must be runnable with `Invoke-Pester` and must pass at the end.
4. Include clear comments explaining your approach.
5. Handle errors gracefully with meaningful error messages.

Create your solution in the current working directory. Start by writing your first failing test.
```

### PowerShell Strict Mode
```
You are completing a scripting task. You MUST use PowerShell with strict mode as your implementation language.

TASK: {task_description}

REQUIREMENTS:
1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.
2. Create mocks and test fixtures as necessary for testability. Use Pester as the testing framework.
3. All tests must be runnable with `Invoke-Pester` and must pass at the end.
4. Include clear comments explaining your approach.
5. Handle errors gracefully with meaningful error messages.
6. STRICT MODE REQUIREMENTS — every script and module file must include:
   - `Set-StrictMode -Latest` at the top
   - `$ErrorActionPreference = 'Stop'`
   - All function parameters must be explicitly typed (e.g., `[string]$Name`, `[int]$Count`, `[hashtable]$Options`)
   - All functions must declare `[OutputType()]` attributes
   - No implicit type conversions — cast explicitly where needed
   - Use `[CmdletBinding()]` on all functions

Create your solution in the current working directory. Start by writing your first failing test.
```

### C# Script Mode (.NET 10 File-Based Apps)
```
You are completing a scripting task. You MUST use C# with .NET 10 file-based apps as your implementation language.

TASK: {task_description}

REQUIREMENTS:
1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.
2. Create mocks and test fixtures as necessary for testability.
3. Use .NET 10 file-based apps: write C# files with top-level statements that can be run directly with `dotnet run <file>.cs`. For tests, use a standard test project with `dotnet test`.
4. All tests must be runnable with `dotnet test` and must pass at the end.
5. Include clear comments explaining your approach.
6. Handle errors gracefully with meaningful error messages.

Create your solution in the current working directory. Start by writing your first failing test.
```

---

## Data Collection Schema

For each run, the runner captures:

| Metric | Source | Description |
|--------|--------|-------------|
| task_id | Runner | Task identifier (e.g., "01-csv-report-generator") |
| task_name | Runner | Human-readable task name |
| language_mode | Runner | One of: default, powershell, powershell-strict, csharp-script |
| language_chosen | Post-analysis | Actual language(s) used by the agent |
| language_breakdown | Post-analysis | Percentage breakdown of languages used (default mode) |
| interpreter_versions | Post-analysis | Versions of interpreters/runtimes used |
| powershell_version | Post-analysis | PowerShell version (for PS modes) |
| dotnet_version | Post-analysis | .NET SDK version (for C# and PS modes) |
| model | Runner | Model ID used |
| claude_code_version | CLI init event | Version of Claude Code CLI |
| instructions_version | Runner | Version string from this file |
| timestamp_start | Runner | ISO8601 start time |
| timestamp_end | Runner | ISO8601 end time |
| prompt_text | Runner | Full prompt sent to the agent |
| grand_total_duration_ms | CLI result | Wall-clock duration of entire run |
| total_api_duration_ms | CLI result | Time spent in API calls |
| total_execution_duration_ms | Computed | grand_total - api = time in tool execution |
| num_turns | CLI result | Number of agent turns |
| input_tokens | CLI result | Total input tokens |
| output_tokens | CLI result | Total output tokens |
| cache_read_tokens | CLI result | Tokens read from cache |
| cache_creation_tokens | CLI result | Tokens written to cache |
| total_context_consumed | Computed | Cumulative tokens across all turns |
| compaction_count | CLI stream | Number of context compaction events |
| total_cost_usd | CLI result | Actual cost reported by CLI |
| total_lines | Post-analysis | Total lines of code generated |
| total_tokens_estimate | Post-analysis | Estimated token count of generated code |
| file_count | Post-analysis | Number of files created |
| files | Post-analysis | List of files created |
| tests_pass | Post-analysis | Whether all tests pass |
| error_count | CLI stream | Number of errors during the run |
| error_details | CLI stream | Description of each error |
| tool_install_duration_ms | CLI stream | Time spent on tool/dependency installation |
| tools_installed | CLI stream | List of tools/packages installed by the agent |
| areas_of_difficulty | Post-analysis | Areas where the agent struggled |
| observations | Post-analysis | Other notable observations |

### Artifacts Captured Per Run

- `cli-output.json` — Full JSON stream from the CLI (complete transcript)
- `console-log.txt` — Human-readable transcript extracted from the JSON stream
- `metrics.json` — Structured metrics extracted per the schema above
- `workspace-before.txt` — File listing of workspace before the run
- `workspace-after.txt` — File listing of workspace after the run
- `generated-code/` — Copy of all scripts, tests, and other files produced by the agent
