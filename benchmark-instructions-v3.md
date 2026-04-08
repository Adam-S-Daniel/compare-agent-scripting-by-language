# Benchmark Instructions v3 — GitHub Actions

**Version**: v3
**Date**: 2026-04-08
**Purpose**: Measure how well Claude Code agents perform GitHub Actions workflow authoring tasks across different language constraints.

**Changes from v2**:
- Focus narrowed to tasks 11-18 (GitHub Actions / CI/CD category only)
- Each task now requires a valid `.github/workflows/*.yml` workflow file alongside the script and tests
- Modes changed: removed `csharp-script` and `powershell-strict`, added `bash` and `typescript-bun`
- Syntax/lint hooks enabled on all runs via PostToolUse hooks (Python, Bash, TypeScript, PowerShell, actionlint for YAML)
- Post-run `actionlint` validation on all workflow files
- Pre-installed tools: actionlint, shellcheck, bats-core, Bun

## Methodology

### Overview

Each task is executed by a Claude Code agent under 4 different language constraints ("modes") and with 2 different models, yielding **8 runs per task**. Agents receive only the prompt -- no conversation context, no prior results. Each task requires the agent to produce:

1. **A script** implementing the task logic in the constrained language
2. **Tests** for the script logic using the appropriate framework
3. **A GitHub Actions workflow file** (`.github/workflows/<name>.yml`) that integrates the script into a CI/CD pipeline

### Models

| Model ID | Short Name | Input $/Mtok | Output $/Mtok | Cache Read $/Mtok | Cache Write $/Mtok |
|----------|------------|-------------|--------------|-------------------|-------------------|
| claude-opus-4-6 | opus | $15.00 | $75.00 | $1.50 | $18.75 |
| claude-sonnet-4-6 | sonnet | $3.00 | $15.00 | $0.30 | $3.75 |

### Language Modes

1. **default** -- No language specified. The agent chooses whatever language it considers best. Baseline.
2. **powershell** -- The agent must use PowerShell. Tests with non-default but well-known scripting language.
3. **bash** -- The agent must use Bash. Scripts run with `bash script.sh`, tests use `bats-core`. The "is this really just a shell script?" control case.
4. **typescript-bun** -- The agent must use TypeScript with Bun runtime. Scripts run with `bun run app.ts`, tests use `bun test` (built-in test runner). Zero-config like Python but typed.

### TDD Requirement

Every prompt instructs the agent to use **red/green TDD**:
1. Write a failing test first.
2. Write the minimum code to make it pass.
3. Refactor.
4. Repeat for each piece of functionality.
5. Create mocks and test fixtures as necessary.

### GitHub Actions Workflow Requirement

For every task, the agent must also create a GitHub Actions workflow file at `.github/workflows/<task-name>.yml`. The workflow must:
- Use appropriate trigger events (push, pull_request, schedule, workflow_dispatch, etc.)
- Reference the script correctly
- Pass `actionlint` validation (valid YAML, valid action references, correct syntax)
- Include appropriate permissions, environment variables, and job dependencies
- Actually run successfully when executed locally with `act` (nektos/act) in a Docker container

The workflow WILL be executed via `act push` after you finish. Design your workflow so its steps work in an isolated container environment -- use `actions/checkout@v4`, install any dependencies your script needs, and run the script. Avoid steps that require external services or secrets unless they have sensible defaults/fallbacks.

### Workflow Validation

You MUST validate your workflow file by running `actionlint .github/workflows/<task-name>.yml` and fixing any errors it reports. `actionlint` is pre-installed. Iterate until it passes cleanly.

### Workflow Execution Test (Mandatory)

Your workflow must actually run in Docker via `act`. You MUST include a test that:
1. Initializes a git repo in a temp directory and copies your project files into it
2. Runs: `git add -A && git commit -m "test" && act push --rm 2>&1`
3. Saves the full output to a file called `act-result.txt` in the current working directory
4. Asserts that the act command exited with code 0
5. Parses `act-result.txt` and asserts the workflow produced correct results:
   - Assert that each job shows "Job succeeded"
   - Assert that your script's outputs have the correct expected values -- not just that they appear, but that they match known-good values. For example, if the workflow runs your version bumper with fixture data, assert the exact version string (e.g. "1.2.0") appears in the output, not just "some version was printed"
   - If the workflow sets step outputs, assert their values match expectations
   - Use your test fixtures as the input data for the workflow run so you know exactly what the correct output should be

The `act-result.txt` file MUST exist when your tests finish. It is a required artifact. If `act` fails, debug the workflow until it passes. `act` and Docker are pre-installed.

### Workflow Structure Tests

Also write tests that verify your workflow file:
- Parse the YAML and check that it has the expected structure (triggers, jobs, steps)
- Verify the workflow references your script files correctly (paths exist)
- Verify actionlint passes (run it as a subprocess in your test and assert exit code 0)

All workflow tests must pass alongside your script logic tests.

### Pre-installed Tools

The following tools are pre-installed in the benchmark environment:
- **Python 3** with `pytest`
- **PowerShell** (`pwsh`) with **Pester** testing framework
- **Bun** (TypeScript runtime with built-in test runner)
- **Bash** with **bats-core** testing framework
- **actionlint** (GitHub Actions workflow linter)
- **shellcheck** (shell script static analysis)
- **act** (nektos/act — runs GitHub Actions workflows locally in Docker)
- **Docker** (container runtime, used by act)

Agents should NOT attempt to install these tools -- they are already available.

### Syntax/Lint Hooks

All runs have PostToolUse hooks enabled that automatically check files on Write/Edit:
- `.py` files: `python3 -m py_compile` for syntax errors
- `.sh` files: `bash -n` for syntax errors, `shellcheck` for lint
- `.ts` files: `bunx tsc --noEmit` for type errors
- `.ps1` files: `Invoke-ScriptAnalyzer` for PowerShell analysis
- `.yml` files in `.github/workflows/`: `actionlint` for workflow validation

Diagnostics appear as additional context before the agent's next turn, enabling faster error correction.

### Permissions

All tool permissions are bypassed (`--dangerously-skip-permissions`). Agents have full access to all tools without approval prompts.

### Execution

- Tasks run **sequentially** (one at a time).
- Each agent runs in an **isolated workspace directory** containing only a copy of this instructions file.
- No conversation context or prior run data is passed to the agent.

---

## Tasks

### Task 11: Semantic Version Bumper
**Category**: GitHub Actions / Release Automation

Parse a version file (or package.json) containing a semantic version string, determine the next version based on conventional commit messages (feat -> minor, fix -> patch, breaking -> major), update the version file, generate a changelog entry from the commits, and output the new version. Create mock commit logs as test fixtures.

### Task 12: PR Label Assigner
**Category**: GitHub Actions / Triage

Given a list of changed file paths (simulating a PR's changed files), apply labels based on configurable path-to-label mapping rules (e.g., docs/** -> documentation, src/api/** -> api, *.test.* -> tests). Support glob patterns, multiple labels per file, and priority ordering when rules conflict. Output the final label set. Mock the file list for testing.

### Task 13: Dependency License Checker
**Category**: GitHub Actions / Compliance

Parse a dependency manifest (package.json, requirements.txt, or similar), extract dependency names and versions, check each against an allow-list and deny-list of licenses (provided as config), and generate a compliance report listing each dependency's license status (approved, denied, unknown). Mock the license lookup for testing.

### Task 14: Docker Image Tag Generator
**Category**: GitHub Actions / CI/CD

Given git context (branch name, commit SHA, tags, PR number -- all provided as mock inputs), generate appropriate Docker image tags following common conventions: latest for main, pr-{number} for PRs, v{semver} for tags, {branch}-{short-sha} for feature branches. Handle tag sanitization (lowercase, no special chars). Output the tag list.

### Task 15: Test Results Aggregator
**Category**: GitHub Actions / CI Reporting

Parse test result files in multiple formats (JUnit XML, and JSON), aggregate results across multiple files (simulating a matrix build), compute totals (passed, failed, skipped, duration), identify flaky tests (passed in some runs, failed in others), and generate a markdown summary suitable for a GitHub Actions job summary. Create sample test result files as fixtures.

### Task 16: Environment Matrix Generator
**Category**: GitHub Actions / CI Configuration

Given a configuration describing OS options, language versions, and feature flags, generate a build matrix (as JSON) suitable for GitHub Actions strategy.matrix. Support include/exclude rules, max-parallel limits, and fail-fast configuration. Validate that the matrix doesn't exceed a maximum size. Output the complete matrix JSON.

### Task 17: Artifact Cleanup Script
**Category**: GitHub Actions / Maintenance

Given a list of artifacts with metadata (name, size, creation date, workflow run ID -- provided as mock data), apply retention policies (max age, max total size, keep-latest-N per workflow), determine which artifacts to delete, and generate a deletion plan with a summary (total space reclaimed, artifacts retained vs deleted). Support dry-run mode.

### Task 18: Secret Rotation Validator
**Category**: GitHub Actions / Security

Given a configuration of secrets with metadata (name, last-rotated date, rotation policy in days, required-by services -- all mock data), identify secrets that are expired or expiring within a configurable warning window, generate a rotation report, and output notifications grouped by urgency (expired, warning, ok). Support multiple output formats (markdown table, JSON).

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

### Bash Mode
```
You are completing a scripting task. You MUST use Bash as your implementation language.

TASK: {task_description}

REQUIREMENTS:
1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.
2. Create mocks and test fixtures as necessary for testability. Use bats-core (bats) as the testing framework.
3. All tests must be runnable with `bats` and must pass at the end.
4. Include clear comments explaining your approach.
5. Handle errors gracefully with meaningful error messages.
6. Use `#!/usr/bin/env bash` shebang. Scripts must pass `shellcheck` and `bash -n` syntax validation.

Create your solution in the current working directory. Start by writing your first failing test.
```

### TypeScript-Bun Mode
```
You are completing a scripting task. You MUST use TypeScript with Bun as your implementation language and runtime.

TASK: {task_description}

REQUIREMENTS:
1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.
2. Create mocks and test fixtures as necessary for testability. Use Bun's built-in test runner (`bun test`).
3. All tests must be runnable with `bun test` and must pass at the end.
4. Include clear comments explaining your approach.
5. Handle errors gracefully with meaningful error messages.
6. Use TypeScript features: explicit types, interfaces, and type annotations. Run scripts with `bun run <file>.ts`.

Create your solution in the current working directory. Start by writing your first failing test.
```

### GHA Workflow Addendum (appended to all prompts for tasks 11-18)
```
GITHUB ACTIONS REQUIREMENT:
In addition to the script and tests, create a GitHub Actions workflow file at
.github/workflows/<task-name>.yml that would use your script in a real CI/CD pipeline.
The workflow must:
- Use appropriate trigger events (push, pull_request, schedule, workflow_dispatch, etc.)
- Reference your script correctly
- Pass actionlint validation (valid YAML, valid action references, correct syntax)
- Include appropriate permissions, environment variables, and job dependencies

The workflow WILL be executed in a Docker container via `act push` after you finish.
It must complete without errors. Design your workflow so that its steps work in an
isolated container environment — use `actions/checkout@v4`, install any dependencies
your script needs, and run the script. Avoid steps that require external services or
secrets unless they have sensible defaults/fallbacks.

WORKFLOW VALIDATION:
You MUST validate your workflow file by running `actionlint .github/workflows/<task-name>.yml`
and fix any errors it reports. actionlint is pre-installed. Iterate until it passes cleanly.

WORKFLOW EXECUTION TEST (MANDATORY):
Your workflow must actually run in Docker via `act`. You MUST include a test that:
1. Initializes a git repo in a temp directory and copies your project files into it
2. Runs: git add -A && git commit -m "test" && act push --rm 2>&1
3. Saves the full output to a file called `act-result.txt` in the current working directory
4. Asserts that the act command exited with code 0

The `act-result.txt` file MUST exist when your tests finish. It is a required artifact.
If act fails, debug the workflow until it passes — check the output for errors.
`act` and Docker are pre-installed.

WORKFLOW STRUCTURE TESTS:
Also write tests that verify your workflow file:
- Parse the YAML and check that it has the expected structure (triggers, jobs, steps)
- Verify the workflow references your script files correctly (paths exist)
- Verify actionlint passes (run it as a subprocess in your test and assert exit code 0)
These tests should be part of your main test suite and must pass at the end.
```

---

## Data Collection Schema

For each run, the runner captures:

| Metric | Source | Description |
|--------|--------|-------------|
| task_id | Runner | Task identifier (e.g., "11-semantic-version-bumper") |
| task_name | Runner | Human-readable task name |
| language_mode | Runner | One of: default, powershell, bash, typescript-bun |
| language_chosen | Post-analysis | Actual language(s) used by the agent |
| language_breakdown | Post-analysis | Percentage breakdown of languages used |
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
| file_count | Post-analysis | Number of files created |
| files | Post-analysis | List of files created |
| tests_pass | Post-analysis | Whether all tests pass |
| actionlint_pass | Post-run | Whether all workflow files pass actionlint |
| actionlint_errors | Post-run | Number of workflow files failing actionlint |
| actionlint_results | Post-run | Per-file actionlint pass/fail with error details |
| act_ran | Post-run | Whether act was available and attempted |
| act_pass | Post-run | Whether the workflow ran successfully via act |
| act_duration_ms | Post-run | Wall-clock time for workflow execution in Docker |
| error_count | CLI stream | Number of errors during the run |
| hook_fires | CLI stream | Number of hook responses (syntax check activations) |
| hook_errors_caught | CLI stream | Number of hooks that returned diagnostics |

### Artifacts Captured Per Run

- `cli-output.json` -- Full JSON stream from the CLI (complete transcript)
- `console-log.txt` -- Human-readable transcript extracted from the JSON stream
- `metrics.json` -- Structured metrics extracted per the schema above
- `workspace-before.txt` -- File listing of workspace before the run
- `workspace-after.txt` -- File listing of workspace after the run
- `generated-code/` -- Copy of all scripts, tests, and other files produced by the agent

### Quality Dimensions

Each run is evaluated on three independent quality dimensions:
1. **Tests pass** -- Did the agent's own tests pass? (agent-reported)
2. **actionlint pass** -- Did the workflow YAML pass static analysis? (runner-validated)
3. **act pass** -- Did the workflow actually run successfully in a Docker container? (runner-executed)

This gives a 2x2x2 quality cube per run. The `act_duration_ms` metric records how long the workflow took to execute, enabling comparison of workflow efficiency across modes.
