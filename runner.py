#!/usr/bin/env python3
"""
Benchmark runner for comparing Claude Code agent scripting across languages.
Invokes Claude Code CLI subagents on scripting tasks under different language constraints.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import threading
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

INSTRUCTIONS_FILE = "benchmark-instructions-v3.md"
INSTRUCTIONS_VERSION = "v3"

MODELS = {
    "opus": "claude-opus-4-6",
    "sonnet": "claude-sonnet-4-6",
}

# ---------------------------------------------------------------------------
# Model Token Pricing — SINGLE SOURCE OF TRUTH
# ---------------------------------------------------------------------------
# All per-million-token costs in USD.  Every cost calculation in this file
# and in generate_results_md references this dict.
#
# TO UPDATE: check https://docs.anthropic.com/en/docs/about-claude/models
# and https://www.anthropic.com/pricing for current prices.  Update the
# values below and re-run the report generation.
# ---------------------------------------------------------------------------
COST_PER_MTOK = {
    "claude-opus-4-6":   {"input": 15.0, "output": 75.0, "cache_read": 1.5, "cache_write": 18.75},
    "claude-sonnet-4-6": {"input": 3.0,  "output": 15.0, "cache_read": 0.3, "cache_write": 3.75},
}

LANGUAGE_EXTENSIONS = {
    ".py": "python", ".js": "javascript", ".ts": "typescript", ".sh": "bash",
    ".ps1": "powershell", ".psm1": "powershell", ".psd1": "powershell",
    ".cs": "csharp", ".rb": "ruby", ".go": "go", ".rs": "rust",
    ".java": "java", ".pl": "perl", ".lua": "lua", ".r": "r",
    ".yml": "yaml", ".yaml": "yaml",
}

INSTALL_PATTERNS = [
    r"apt[\s-]get\s+install", r"apt\s+install", r"pip\s+install", r"pip3\s+install",
    r"npm\s+install", r"yarn\s+add", r"dotnet\s+tool\s+install", r"Install-Module",
    r"Install-Package", r"brew\s+install", r"snap\s+install", r"cargo\s+install",
    r"gem\s+install", r"go\s+install",
]

# ---------------------------------------------------------------------------
# Task Definitions
# ---------------------------------------------------------------------------

TASKS = [
    {
        "id": "01-csv-report-generator",
        "name": "CSV Report Generator",
        "category": "Data Transformation",
        "description": (
            "Read a CSV file of employee records (name, department, salary, hire_date, status), "
            "filter to active employees only, compute aggregates (average salary by department, "
            "headcount by department, overall statistics), and output a formatted summary report "
            "to a text file. Create sample CSV test data as part of the test fixtures."
        ),
    },
    {
        "id": "02-log-file-analyzer",
        "name": "Log File Analyzer",
        "category": "Text Processing",
        "description": (
            "Parse a log file containing mixed formats (syslog-style lines and JSON-structured lines), "
            "extract all error and warning entries, produce a frequency table of error types with their "
            "first and last occurrence timestamps, and output the analysis as both a human-readable table "
            "and a JSON file. Create sample log data as test fixtures."
        ),
    },
    {
        "id": "03-directory-tree-sync",
        "name": "Directory Tree Sync",
        "category": "File Manipulation",
        "description": (
            "Compare two directory trees, identify files that differ (by content hash — SHA-256), "
            "files that exist in only one tree, and generate a sync plan. Implement both a dry-run "
            "mode (report only) and an execute mode (perform the sync). All file operations should "
            "be testable with mock directory structures."
        ),
    },
    {
        "id": "04-rest-api-client",
        "name": "REST API Client",
        "category": "API Interaction",
        "description": (
            "Build a script that queries a REST API (use JSONPlaceholder — https://jsonplaceholder.typicode.com), "
            "fetches posts and their comments, handles pagination, implements retry with exponential backoff "
            "on failure, and caches results locally in JSON files. Mock the HTTP calls for testing."
        ),
    },
    {
        "id": "05-process-monitor",
        "name": "Process Monitor",
        "category": "System Administration",
        "description": (
            "Create a script that reads process information (CPU%, memory, PID, name), filters by "
            "configurable resource usage thresholds, identifies the top N resource consumers, and "
            "generates an alert report. All process data must be mockable for testing — do not rely "
            "on live system state in tests."
        ),
    },
    {
        "id": "06-config-file-migrator",
        "name": "Config File Migrator",
        "category": "Data Transformation",
        "description": (
            "Read a configuration file in INI format, validate it against a simple schema (required keys, "
            "value types), and output equivalent configurations in JSON and YAML formats. Handle sections, "
            "comments, multi-line values, and type coercion (strings to numbers/booleans where appropriate). "
            "Create test fixtures with various edge cases."
        ),
    },
    {
        "id": "07-batch-file-renamer",
        "name": "Batch File Renamer",
        "category": "File Automation",
        "description": (
            "Rename files in a directory using regex-based patterns. Support: preview mode (show what would "
            "change without doing it), undo capability (generate an undo script that reverses the renames), "
            "and conflict detection (two files would get the same name). Test with mock file system structures."
        ),
    },
    {
        "id": "08-database-seed-script",
        "name": "Database Seed Script",
        "category": "Process Automation",
        "description": (
            "Create a SQLite database with a schema (users, orders, products tables with foreign keys), "
            "generate realistic mock data using deterministic randomization (seeded RNG), insert the data "
            "respecting referential integrity, and run verification queries that confirm data consistency. "
            "Tests should verify schema, data integrity, and query results."
        ),
    },
    {
        "id": "09-error-retry-pipeline",
        "name": "Error Retry Pipeline",
        "category": "Error Handling",
        "description": (
            "Build a pipeline that processes items from a queue (mocked), where processing can fail randomly. "
            "Implement: exponential backoff retry (configurable max retries), dead-letter queue for permanently "
            "failed items, progress reporting (items processed, failed, retrying), and a final summary. All "
            "queue and processing operations must be mockable."
        ),
    },
    {
        "id": "10-multi-file-search-replace",
        "name": "Multi-file Search and Replace",
        "category": "Text Processing",
        "description": (
            "Recursively search files matching a glob pattern for a regex pattern, perform search-and-replace "
            "with: preview mode (show matches with context without modifying), backup creation (copy originals "
            "before modifying), and a summary report of all changes made (file, line number, old text, new text). "
            "Test with mock directory structures and files."
        ),
    },
    {
        "id": "11-semantic-version-bumper",
        "name": "Semantic Version Bumper",
        "category": "GitHub Actions / Release Automation",
        "description": (
            "Parse a version file (or package.json) containing a semantic version string, determine the next "
            "version based on conventional commit messages (feat -> minor, fix -> patch, breaking -> major), "
            "update the version file, generate a changelog entry from the commits, and output the new version. "
            "Create mock commit logs as test fixtures."
        ),
    },
    {
        "id": "12-pr-label-assigner",
        "name": "PR Label Assigner",
        "category": "GitHub Actions / Triage",
        "description": (
            "Given a list of changed file paths (simulating a PR's changed files), apply labels based on "
            "configurable path-to-label mapping rules (e.g., docs/** -> documentation, src/api/** -> api, "
            "*.test.* -> tests). Support glob patterns, multiple labels per file, and priority ordering "
            "when rules conflict. Output the final label set. Mock the file list for testing."
        ),
    },
    {
        "id": "13-dependency-license-checker",
        "name": "Dependency License Checker",
        "category": "GitHub Actions / Compliance",
        "description": (
            "Parse a dependency manifest (package.json, requirements.txt, or similar), extract dependency "
            "names and versions, check each against an allow-list and deny-list of licenses (provided as "
            "config), and generate a compliance report listing each dependency's license status (approved, "
            "denied, unknown). Mock the license lookup for testing."
        ),
    },
    {
        "id": "14-docker-image-tag-generator",
        "name": "Docker Image Tag Generator",
        "category": "GitHub Actions / CI/CD",
        "description": (
            "Given git context (branch name, commit SHA, tags, PR number — all provided as mock inputs), "
            "generate appropriate Docker image tags following common conventions: latest for main, pr-{number} "
            "for PRs, v{semver} for tags, {branch}-{short-sha} for feature branches. Handle tag sanitization "
            "(lowercase, no special chars). Output the tag list."
        ),
    },
    {
        "id": "15-test-results-aggregator",
        "name": "Test Results Aggregator",
        "category": "GitHub Actions / CI Reporting",
        "description": (
            "Parse test result files in multiple formats (JUnit XML, and JSON), aggregate results across "
            "multiple files (simulating a matrix build), compute totals (passed, failed, skipped, duration), "
            "identify flaky tests (passed in some runs, failed in others), and generate a markdown summary "
            "suitable for a GitHub Actions job summary. Create sample test result files as fixtures."
        ),
    },
    {
        "id": "16-environment-matrix-generator",
        "name": "Environment Matrix Generator",
        "category": "GitHub Actions / CI Configuration",
        "description": (
            "Given a configuration describing OS options, language versions, and feature flags, generate a "
            "build matrix (as JSON) suitable for GitHub Actions strategy.matrix. Support include/exclude "
            "rules, max-parallel limits, and fail-fast configuration. Validate that the matrix doesn't exceed "
            "a maximum size. Output the complete matrix JSON."
        ),
    },
    {
        "id": "17-artifact-cleanup-script",
        "name": "Artifact Cleanup Script",
        "category": "GitHub Actions / Maintenance",
        "description": (
            "Given a list of artifacts with metadata (name, size, creation date, workflow run ID — provided "
            "as mock data), apply retention policies (max age, max total size, keep-latest-N per workflow), "
            "determine which artifacts to delete, and generate a deletion plan with a summary (total space "
            "reclaimed, artifacts retained vs deleted). Support dry-run mode."
        ),
    },
    {
        "id": "18-secret-rotation-validator",
        "name": "Secret Rotation Validator",
        "category": "GitHub Actions / Security",
        "description": (
            "Given a configuration of secrets with metadata (name, last-rotated date, rotation policy in days, "
            "required-by services — all mock data), identify secrets that are expired or expiring within a "
            "configurable warning window, generate a rotation report, and output notifications grouped by "
            "urgency (expired, warning, ok). Support multiple output formats (markdown table, JSON)."
        ),
    },
]

# ---------------------------------------------------------------------------
# Prompt Templates
# ---------------------------------------------------------------------------

PROMPT_TEMPLATES = {
    "default": (
        "You are completing a scripting task. Choose whatever programming language you think is best for this task.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability.\n"
        "3. All tests must be runnable and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
    "powershell": (
        "You are completing a scripting task. You MUST use PowerShell as your implementation language.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability. Use Pester as the testing framework.\n"
        "3. All tests must be runnable with `Invoke-Pester` and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
    "bash": (
        "You are completing a scripting task. You MUST use Bash as your implementation language.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability. Use bats-core (bats) as the testing framework.\n"
        "3. All tests must be runnable with `bats` and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n"
        "6. Use `#!/usr/bin/env bash` shebang. Scripts must pass `shellcheck` and `bash -n` syntax validation.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
    "typescript-bun": (
        "You are completing a scripting task. You MUST use TypeScript with Bun as your implementation language and runtime.\n\n"
        "TASK: {task_description}\n\n"
        "REQUIREMENTS:\n"
        "1. Use red/green TDD methodology: write a failing test FIRST, then write the minimum code to make it pass, then refactor. Repeat for each piece of functionality.\n"
        "2. Create mocks and test fixtures as necessary for testability. Use Bun's built-in test runner (`bun test`).\n"
        "3. All tests must be runnable with `bun test` and must pass at the end.\n"
        "4. Include clear comments explaining your approach.\n"
        "5. Handle errors gracefully with meaningful error messages.\n"
        "6. Use TypeScript features: explicit types, interfaces, and type annotations. Run scripts with `bun run <file>.ts`.\n\n"
        "Create your solution in the current working directory. Start by writing your first failing test."
    ),
}

MODES = list(PROMPT_TEMPLATES.keys())

# GHA workflow requirement addendum — appended to prompts for tasks 11-18
GHA_TASK_IDS = {
    "11-semantic-version-bumper",
    "12-pr-label-assigner",
    "13-dependency-license-checker",
    "14-docker-image-tag-generator",
    "15-test-results-aggregator",
    "16-environment-matrix-generator",
    "17-artifact-cleanup-script",
    "18-secret-rotation-validator",
}

GHA_WORKFLOW_ADDENDUM = """
GITHUB ACTIONS REQUIREMENT:
Create a GitHub Actions workflow file at .github/workflows/{task_slug}.yml that uses
your script in a real CI/CD pipeline. The workflow must:
- Use appropriate trigger events (push, pull_request, schedule, workflow_dispatch, etc.)
- Reference your script correctly
- Pass actionlint validation (valid YAML, valid action references, correct syntax)
- Include appropriate permissions, environment variables, and job dependencies
- Actually run successfully when executed locally with `act` (nektos/act)

Design your workflow so its steps work in an isolated Docker container — use
`actions/checkout@v4`, install dependencies your script needs, and run it.
Avoid steps requiring external services or secrets without sensible defaults.

WORKFLOW VALIDATION:
Run `actionlint .github/workflows/{task_slug}.yml` and fix any errors. actionlint is
pre-installed. Iterate until it passes cleanly.

ALL TESTS MUST RUN THROUGH ACT:
Every single test case must execute through the GitHub Actions workflow via `act`.
Do NOT test your script directly — all testing goes through the pipeline.

Structure your workflow to accept test fixture data and produce verifiable output.
Your test harness must:
1. For each test case: set up a temp git repo with your project files + that case's
   fixture data, run `act push --rm`, capture the output
2. Save all act output to `act-result.txt` in the current working directory (append
   each test case's output, clearly delimited)
3. Assert that act exited with code 0 for each case
4. Parse the act output and assert on EXACT EXPECTED VALUES — not just that output
   appeared, but that it matches the known-good result for that test case's input.
   For example: if your workflow bumps version 1.1.0 with a feat commit, assert
   the output contains exactly "1.2.0", not just "a version number"
5. Assert every job shows "Job succeeded"

The `act-result.txt` file MUST exist when done. It is a required artifact.
`act` and Docker are pre-installed.

WORKFLOW STRUCTURE TESTS (also required):
- Parse the YAML and check expected structure (triggers, jobs, steps)
- Verify the workflow references your script files correctly (paths exist)
- Verify actionlint passes (assert exit code 0)
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

PUSH_INTERVAL = 60  # seconds between incremental git pushes
INCREMENTAL_PREFIX = "Incremental benchmark results:"

# Directories to skip in workspace walkers (noise that inflates metrics)
SKIP_DIRS = {"node_modules", "__pycache__", ".pytest_cache", ".mypy_cache", "obj", "bin"}


def log(msg: str) -> None:
    """Print progress to stderr."""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", file=sys.stderr, flush=True)


# Lock protects all git operations so the PeriodicPusher background thread
# and any foreground git work never overlap.
_git_lock = threading.Lock()


def git_push_results(
    repo_root: Path,
    branch: str,
    run_count: int,
    total_runs: int,
    *,
    final: bool = False,
) -> None:
    """Commit and push results (append-only, no history rewriting).

    Earlier versions squashed incremental commits via ``git reset --soft``,
    which corrupted the repo when concurrent git operations occurred (e.g.
    manual rebase while the background pusher was running).  Now we simply
    append commits — safe for concurrency, easy to squash later if desired.
    """
    with _git_lock:
        try:
            status = subprocess.run(
                ["git", "status", "--porcelain", "results/"],
                cwd=str(repo_root), capture_output=True, text=True, timeout=10,
            )
            if not status.stdout.strip():
                return  # nothing new to commit

            # Stage results
            subprocess.run(
                ["git", "add", "results/"],
                cwd=str(repo_root), capture_output=True, timeout=10,
            )

            if final:
                msg = f"Benchmark results: {run_count}/{total_runs} runs completed"
            else:
                msg = f"{INCREMENTAL_PREFIX} {run_count}/{total_runs} runs completed"

            subprocess.run(
                ["git", "commit", "-m", msg],
                cwd=str(repo_root), capture_output=True, timeout=30,
            )

            push_args = ["git", "push", "-u", "origin", branch]
            subprocess.run(push_args, capture_output=True, timeout=60, cwd=str(repo_root))

            log(f"  [push] Pushed results ({run_count}/{total_runs} done{', FINAL' if final else ''})")
        except Exception as e:
            log(f"  [push] Warning: push failed: {e}")


class PeriodicPusher:
    """Background thread that periodically pushes results to git."""

    def __init__(self, repo_root: Path, branch: str, total_runs: int, run_dir: Path):
        self.repo_root = repo_root
        self.branch = branch
        self.total_runs = total_runs
        self.run_dir = run_dir
        self.run_count = 0
        self.all_metrics: list[dict] = []
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self._thread.start()

    def update(self, count: int, all_metrics: list[dict]):
        self.run_count = count
        self.all_metrics = list(all_metrics)

    def stop(self):
        self._stop.set()
        self._thread.join(timeout=120)

    def _run(self):
        while not self._stop.wait(PUSH_INTERVAL):
            try:
                generate_results_md(self.run_dir, self.all_metrics, self.total_runs, self.run_count)
            except Exception as e:
                log(f"  [push] Warning: results.md generation failed: {e}")
            git_push_results(self.repo_root, self.branch, self.run_count, self.total_runs)


def capture_workspace_listing(workspace: Path) -> str:
    """Return a recursive file listing of the workspace directory."""
    lines = []
    for root, dirs, files in os.walk(workspace):
        # skip hidden dirs, but allow .github/
        dirs[:] = [d for d in dirs if (not d.startswith(".") or d == ".github") and d not in SKIP_DIRS]
        level = len(Path(root).relative_to(workspace).parts)
        indent = "  " * level
        lines.append(f"{indent}{Path(root).name}/")
        for f in sorted(files):
            if not f.startswith("."):
                fpath = Path(root) / f
                try:
                    size = fpath.stat().st_size
                except OSError:
                    size = 0
                lines.append(f"{indent}  {f} ({size} bytes)")
    return "\n".join(lines) if lines else "(empty)"


def copy_generated_files(workspace: Path, dest: Path) -> list[str]:
    """Copy non-instruction, non-hidden files from workspace to dest. Return list of relative paths."""
    dest.mkdir(parents=True, exist_ok=True)
    copied = []
    for root, dirs, files in os.walk(workspace):
        dirs[:] = [d for d in dirs if (not d.startswith(".") or d == ".github") and d not in SKIP_DIRS]
        for f in sorted(files):
            if f.startswith(".") or f == INSTRUCTIONS_FILE:
                continue
            src = Path(root) / f
            rel = src.relative_to(workspace)
            dst = dest / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            try:
                shutil.copy2(src, dst)
                copied.append(str(rel))
            except Exception as e:
                log(f"  Warning: could not copy {rel}: {e}")
    return copied


def count_lines(directory: Path) -> int:
    """Count total lines of code in a directory."""
    total = 0
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in SKIP_DIRS]
        for f in files:
            if f.startswith("."):
                continue
            try:
                total += len((Path(root) / f).read_text(errors="replace").splitlines())
            except Exception:
                pass
    return total


def estimate_tokens(text: str) -> int:
    """Rough token estimate: chars / 4."""
    return len(text) // 4


def _detect_traps(events: list[dict], console: str, metrics: dict) -> list[dict]:
    """Detect time-costly debugging traps from a run's event stream.

    Returns list of {"name": str, "time_s": float, "desc": str} dicts for
    traps that wasted ≥15 seconds.

    ADDING NEW TRAPS
    ================
    When you discover a new recurring pattern that costs agents ≥15 seconds,
    add a numbered block below following the existing pattern:

    1. Give the trap a kebab-case name (e.g. "yaml-indent-errors").
    2. Write detection logic that examines bash_cmds, all_text (agent's
       reasoning), console (tool output), and/or metrics (hook counts, etc.).
    3. Estimate time_s — use the number of wasted commands × a per-command
       cost.  For Bash commands, 15-25s is typical (API turn + execution).
       For act push, use 50s.  For pwsh Pester, use 25-35s.
    4. Call _add(name, time_s, description_string).
    5. If the trap only applies to a specific mode, guard with
       `if mode == "..."`.  Otherwise it is tested on all runs.
    6. If the trap applies to a specific mode, add it to the trap_mode dict
       inside generate_results_md (search for "trap_mode") so the
       "applicable runs" denominator is correct.  Default is "all".

    To find new trap candidates: look at the slowest or highest-error runs
    in results.md, read their console-log.txt for repeated patterns or long
    debugging sequences, then generalise into a detection rule.
    """
    mode = metrics.get("language_mode", "")
    bash_cmds: list[str] = []
    texts: list[str] = []
    for e in events:
        if e.get("type") == "assistant":
            for c in e.get("message", {}).get("content", []):
                if isinstance(c, dict):
                    if c.get("type") == "tool_use" and c.get("name") == "Bash":
                        bash_cmds.append(c.get("input", {}).get("command", ""))
                    elif c.get("type") == "text":
                        texts.append(c.get("text", ""))
    all_text = "\n".join(texts)
    traps: list[dict] = []

    def _add(name, t, desc):
        if t >= 15:
            traps.append({"name": name, "time_s": t, "desc": desc})

    # 1. Pester CmdletBinding parameter binding spiral
    if mode == "powershell":
        diag = [c for c in bash_cmds if re.search(r"/tmp/test_\w+\.(?:ps1|Tests\.ps1)", c)]
        if len(diag) >= 2:
            _add("pester-cmdletbinding-spiral", len(diag) * 25,
                 f"{len(diag)} /tmp/test_*.ps1 diagnostic scripts bisecting Pester parameter binding")

    # 2. Wrong Pester assertion names
    if mode == "powershell":
        wrong = [n for n, p in [("BeInRange", r"Should\s+-BeInRange"),
                                 ("BeGreaterOrEqualTo", r"Should\s+-BeGreaterOrEqualTo"),
                                 ("BeLessOrEqualTo", r"Should\s+-BeLessOrEqualTo")]
                 if re.search(p, "\n".join(bash_cmds) + all_text)]
        if wrong and re.search(r"fix|correct|wrong|not.*valid|doesn.t exist", all_text, re.I):
            _add("pester-wrong-assertions", 45, f"Used nonexistent assertions: {', '.join(wrong)}")

    # 3. Docker PowerShell install exploration
    if mode == "powershell":
        dp = [c for c in bash_cmds if re.search(r"docker\s+run.*(?:powershell|pwsh|microsoft-prod)", c, re.I)]
        if len(dp) >= 2:
            _add("docker-pwsh-install", len(dp) * 45, f"{len(dp)} Docker runs exploring pwsh install")

    # 4. Module restructure mid-run
    if mode == "powershell":
        if (re.search(r"restructur|separate.*into.*module|\.psm1.*fix", all_text, re.I)
                and any(".psm1" in c for c in bash_cmds)):
            _add("mid-run-module-restructure", 120, "Restructured to .psm1 module mid-run")

    # 5. act push debug loops (>2 invocations)
    act_pushes = [c for c in bash_cmds if re.search(r"\bact\s+push", c)]
    if len(act_pushes) > 2:
        extra = len(act_pushes) - 2
        act_times = [t["duration_ms"] for t in metrics.get("tool_use_timing", {}).get("slowest_tool_uses", [])
                     if re.search(r"\bact\s+push", t.get("command", ""))]
        t = extra * (sum(act_times) / len(act_times) / 1000 if act_times else 50)
        _add("act-push-debug-loops", t, f"{len(act_pushes)} act push invocations ({extra} extra)")

    # 6. TypeScript type error fix cycles
    if mode == "typescript-bun":
        he = metrics.get("hooks", {}).get("hook_errors_caught", 0)
        if he >= 2:
            _add("ts-type-error-fix-cycles", he * 12, f"{he} type errors caught by hooks")

    # 7. Docker package install exploration (non-pwsh)
    dpkg = [c for c in bash_cmds if re.search(r"docker\s+run.*(?:pip\s+install|apt-get\s+install)", c, re.I)
            and not re.search(r"powershell|pwsh", c, re.I)]
    if len(dpkg) >= 2:
        _add("docker-pkg-install", len(dpkg) * 30, f"{len(dpkg)} Docker runs exploring package install")

    # 8. bats-core setup confusion
    if mode == "bash":
        bs = [c for c in bash_cmds if re.search(r"which bats|npm.*bats|install.*bats|load.*test_helper", c, re.I)]
        be = len(re.findall(r"bats.*not found|load.*error|helper.*not|cannot.*load", console, re.I))
        if len(bs) >= 3 and be >= 1:
            _add("bats-setup-issues", len(bs) * 15, f"{len(bs)} commands debugging bats setup")

    # 9. Fixture rework
    fc = [c for c in bash_cmds if re.search(r"fixture|sample.*data|test.*data|mock.*data", c, re.I)]
    if len(fc) >= 4:
        _add("fixture-rework", (len(fc) - 2) * 15, f"{len(fc)} commands creating/fixing fixtures")

    # 10. Repeated identical test reruns
    cmd_cnt: dict[str, int] = {}
    for c in bash_cmds:
        if re.search(r"pytest|Invoke-Pester|bun\s+test|bats\s+", c):
            key = re.sub(r"\s+2>&1.*|\s+\|.*", "", c)[:80]
            cmd_cnt[key] = cmd_cnt.get(key, 0) + 1
    for cmd, count in cmd_cnt.items():
        if count >= 4:
            _add("repeated-test-reruns", (count - 2) * 20, f"Same test run {count} times")

    # 11. actionlint fix cycles
    ar = [c for c in bash_cmds if "actionlint" in c]
    af = len(re.findall(r"actionlint.*error", console, re.I))
    if len(ar) >= 3 and af >= 2:
        _add("actionlint-fix-cycles", af * 20, f"{len(ar)} actionlint runs, {af} failures")

    # 12. Permission/path errors in act container
    pe = len(re.findall(r"Permission denied|chmod\s+\+x|not found.*act|ENOENT", console, re.I))
    if pe >= 3:
        _add("act-permission-path-errors", pe * 15, f"{pe} permission/path errors in act container")

    # 13. act fixture path issues
    if (re.search(r"Config file not found|fixture.*not found|No such file.*fixture", console, re.I)
            and re.search(r"fixture.*path|copy.*fixture|missing.*fixture", all_text, re.I)):
        _add("act-fixture-paths", 60, "Fixtures not found inside act Docker container")

    return traps


def _categorize_tool_time(tool_uses: list[dict]) -> dict:
    """Categorize Bash tool use durations into install, test, and act buckets."""
    install_ms = 0
    test_ms = 0
    act_ms = 0
    install_patterns = [
        r"docker\s+run.*(?:install|apt-get|wget|dpkg|curl.*download)",
        r"apt-get\s+(?:update|install)",
        r"pip3?\s+install",
        r"npm\s+install",
        r"Install-Module",
        r"dotnet\s+tool\s+install",
    ]
    test_patterns = [
        r"Invoke-Pester",
        r"pytest|python3?\s+-m\s+pytest",
        r"\bbats\b",
        r"bun\s+test",
        r"pwsh\s+.*Tests?\.ps1",
        r"run[-_]tests",
    ]
    act_patterns = [
        r"\bact\s+(?:push|pull_request)",
    ]
    for t in tool_uses:
        if t.get("tool_name") != "Bash":
            continue
        cmd = t.get("command", "")
        dur = t["duration_ms"]
        if any(re.search(p, cmd, re.IGNORECASE) for p in act_patterns):
            act_ms += dur
        elif any(re.search(p, cmd, re.IGNORECASE) for p in test_patterns):
            test_ms += dur
        elif any(re.search(p, cmd, re.IGNORECASE) for p in install_patterns):
            install_ms += dur
    return {
        "install_duration_ms": install_ms,
        "test_duration_ms": test_ms,
        "act_duration_ms": act_ms,
    }


def compute_language_breakdown(directory: Path) -> dict:
    """Compute language breakdown by lines of code from file extensions."""
    lang_lines: dict[str, int] = {}
    total = 0
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in SKIP_DIRS]
        for f in files:
            if f.startswith("."):
                continue
            ext = Path(f).suffix.lower()
            lang = LANGUAGE_EXTENSIONS.get(ext)
            if lang:
                try:
                    lines = len((Path(root) / f).read_text(errors="replace").splitlines())
                    lang_lines[lang] = lang_lines.get(lang, 0) + lines
                    total += lines
                except Exception:
                    pass
    if total == 0:
        return {}
    return {lang: round(100 * count / total, 1) for lang, count in sorted(lang_lines.items(), key=lambda x: -x[1])}


def get_all_code_text(directory: Path) -> str:
    """Get all code text from files in directory for token counting."""
    texts = []
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in SKIP_DIRS]
        for f in files:
            if f.startswith(".") or f == INSTRUCTIONS_FILE:
                continue
            try:
                texts.append((Path(root) / f).read_text(errors="replace"))
            except Exception:
                pass
    return "\n".join(texts)


def _collapsible_table(summary: str, header: str, separator: str, rows: list[str]) -> list[str]:
    """Wrap a markdown table in a <details> block."""
    out = ["", "<details>", f"<summary>{summary}</summary>", ""]
    out.append(header)
    out.append(separator)
    out.extend(rows)
    out.append("")
    out.append("</details>")
    return out


def _emit_sorted_variants(header: str, separator: str, data_rows: list[dict],
                           sort_specs: list[tuple[str, str, bool]],
                           row_formatter) -> list[str]:
    """Emit multiple collapsed copies of a table, each sorted differently.

    sort_specs: list of (summary_label, sort_key, reverse).
    row_formatter: callable(row_dict) -> markdown row string.
    """
    out: list[str] = []
    for label, key, reverse in sort_specs:
        sorted_rows = sorted(data_rows, key=lambda r: (r.get(key, 0) if isinstance(r.get(key, 0), (int, float)) else str(r.get(key, ""))), reverse=reverse)
        row_strs = [row_formatter(r) for r in sorted_rows]
        out.extend(_collapsible_table(label, header, separator, row_strs))
    return out


def generate_results_md(run_dir: Path, all_metrics: list[dict], total_runs: int, run_count: int) -> None:
    """Generate/update a results.md file with tables, commentary, and status."""
    from zoneinfo import ZoneInfo

    et = ZoneInfo("America/New_York")
    now_et = datetime.now(et).strftime("%Y-%m-%d %I:%M:%S %p ET")

    completed = len(all_metrics)
    remaining = total_runs - run_count
    in_progress = run_count - completed

    total_cost = sum(m["cost"]["total_cost_usd"] for m in all_metrics)
    total_duration = sum(m["timing"]["grand_total_duration_ms"] for m in all_metrics) / 1000

    lines = []
    lines.append("# Benchmark Results: Language Mode Comparison")
    lines.append("")
    lines.append(f"**Last updated:** {now_et}")
    lines.append("")
    lines.append(f"**Status:** {completed}/{total_runs} runs completed, {remaining} remaining")
    lines.append(f"**Total cost so far:** ${total_cost:.4f}")
    lines.append(f"**Total agent time so far:** {total_duration:.0f}s ({total_duration/60:.1f} min)")
    lines.append("")

    if not all_metrics:
        lines.append("*No completed runs yet.*")
        (run_dir / "results.md").write_text("\n".join(lines))
        return

    # Separate successful and failed runs
    successful = [m for m in all_metrics if m.get("run_success", m["exit_code"] == 0 and m["timing"]["num_turns"] > 0)]
    failed = [m for m in all_metrics if m not in successful]
    modes_seen = sorted(set(m["language_mode"] for m in all_metrics))
    models_seen = sorted(set(m["model_short"] for m in all_metrics))

    # ── Failed runs (if any) ──
    if failed:
        lines.append("## Failed / Timed-Out Runs")
        lines.append("")
        lines.append("| Task | Mode | Model | Duration | Reason | Lines | actionlint | act-result.txt |")
        lines.append("|------|------|-------|----------|--------|-------|------------|----------------|")
        for m in failed:
            dur = m["timing"]["grand_total_duration_ms"] / 1000
            reason = m.get("failure_reason", "exit_code=" + str(m["exit_code"]))
            alint = "pass" if m["quality"]["actionlint_pass"] else ("fail" if m["quality"]["actionlint_pass"] is False else "n/a")
            act = "yes" if m["quality"]["act_result_txt_exists"] else "no"
            lines.append(
                f"| {m['task_name'][:30]} | {m['language_mode']} | {m['model_short']} "
                f"| {dur:.0f}s | {reason} | {m['code_metrics']['total_lines']} | {alint} | {act} |"
            )
        lines.append("")
        lines.append(f"*{len(failed)} run(s) excluded from averages below.*")
        lines.append("")

    # ── Comparison by Language/Model (replaces separate mode/model tables) ──
    if len(modes_seen) > 1 or len(models_seen) > 1:
        lines.append("## Comparison by Language/Model")
        if failed:
            lines.append("*(averages exclude failed/timed-out runs)*")
        lines.append("")
        cmp_hdr = "| Mode | Model | Runs | Avg Duration | Avg Lines | Avg Errors | Avg Turns | Avg Cost | Total Cost |"
        cmp_sep = "|------|-------|------|-------------|-----------|------------|-----------|----------|------------|"
        cmp_rows: list[dict] = []
        for mode in modes_seen:
            for model in models_seen:
                mm = [m for m in successful if m["language_mode"] == mode and m["model_short"] == model]
                n = len(mm)
                if n == 0:
                    continue
                cmp_rows.append({
                    "mode": mode, "model": model, "n": n,
                    "avg_dur": sum(m["timing"]["grand_total_duration_ms"] for m in mm) / n / 1000,
                    "avg_lines": sum(m["code_metrics"]["total_lines"] for m in mm) / n,
                    "avg_errors": sum(m["quality"]["error_count"] for m in mm) / n,
                    "avg_turns": sum(m["timing"]["num_turns"] for m in mm) / n,
                    "avg_cost": sum(m["cost"]["total_cost_usd"] for m in mm) / n,
                    "total_cost": sum(m["cost"]["total_cost_usd"] for m in mm),
                })
        def _fmt_cmp(r):
            return (f"| {r['mode']} | {r['model']} | {r['n']} | {r['avg_dur']:.0f}s | {r['avg_lines']:.0f} "
                    f"| {r['avg_errors']:.1f} | {r['avg_turns']:.0f} | ${r['avg_cost']:.4f} | ${r['total_cost']:.4f} |")
        lines.append(cmp_hdr)
        lines.append(cmp_sep)
        for r in cmp_rows:
            lines.append(_fmt_cmp(r))
        lines.append("")
        lines.extend(_emit_sorted_variants(cmp_hdr, cmp_sep, cmp_rows, [
            ("Sorted by avg duration (fastest first)", "avg_dur", False),
            ("Sorted by avg cost (cheapest first)", "avg_cost", False),
            ("Sorted by avg errors (most first)", "avg_errors", True),
            ("Sorted by total cost (most first)", "total_cost", True),
        ], _fmt_cmp))
        lines.append("")

    # ==================================================================
    # SAVINGS ANALYSIS (hooks, prompt cache, traps)
    # ==================================================================
    # Collect all data first, then emit tables

    # ── Collect trap & hook data ──
    # A hook-caught error avoids one test run that would otherwise have
    # surfaced the error.  But every hook fire (hit or miss) costs execution
    # time for the syntax/type checker itself.
    TEST_RUN_COST_S = {"default": 8, "powershell": 35, "bash": 12, "typescript-bun": 8}

    # Compute per-mode hook overhead dynamically from Write/Edit tool_use
    # durations.  Each Write/Edit that triggers a hook has its execution time
    # inflated by the hook's checker.  Without hooks a Write is ~0.05s.
    _write_durs_by_mode: dict[str, list[float]] = {}
    for m in all_metrics:
        md = m["language_mode"]
        for t in m.get("tool_use_timing", {}).get("slowest_tool_uses", []):
            if t["tool_name"] in ("Write", "Edit"):
                _write_durs_by_mode.setdefault(md, []).append(t["duration_ms"] / 1000)
    HOOK_OVERHEAD_S = {
        md: max(0, (sum(ds) / len(ds)) - 0.05) if ds else 0.5
        for md, ds in _write_durs_by_mode.items()
    }

    trap_instances: list[dict] = []
    hook_by_combo: dict[tuple, dict] = {}
    combo_run_counts: dict[tuple, int] = {}

    for m in all_metrics:
        mode, model = m["language_mode"], m["model_short"]
        combo = (mode, model)
        combo_run_counts[combo] = combo_run_counts.get(combo, 0) + 1

        cli_path = run_dir / "tasks" / m["task_id"] / f"{mode}-{model}" / "cli-output.json"
        console_path = run_dir / "tasks" / m["task_id"] / f"{mode}-{model}" / "console-log.txt"
        try:
            evts = json.loads(cli_path.read_text())
        except Exception:
            evts = []
        console_text = console_path.read_text() if console_path.exists() else ""

        for trap in _detect_traps(evts, console_text, m):
            trap_instances.append({
                "mode": mode, "model": model, "task_id": m["task_id"],
                "task_name": m["task_name"],
                "dur_s": m["timing"]["grand_total_duration_ms"] / 1000,
                "cost": m["cost"]["total_cost_usd"],
                **trap,
            })

        caught = m.get("hooks", {}).get("hook_errors_caught", 0)
        fires = m.get("hooks", {}).get("hook_fires", 0)
        gross_saved = caught * TEST_RUN_COST_S.get(mode, 10)
        overhead = fires * HOOK_OVERHEAD_S.get(mode, 0.5)
        test_time = m.get("tool_use_timing", {}).get("test_duration_ms", 0) / 1000
        if combo not in hook_by_combo:
            hook_by_combo[combo] = {"fires": 0, "caught": 0, "gross_saved": 0, "overhead": 0, "test_time": 0}
        hook_by_combo[combo]["fires"] += fires
        hook_by_combo[combo]["caught"] += caught
        hook_by_combo[combo]["gross_saved"] += gross_saved
        hook_by_combo[combo]["overhead"] += overhead
        hook_by_combo[combo]["test_time"] += test_time

    # ── Collect prompt cache data ──
    cache_data: list[dict] = []
    # Derive cache rates from the single source of truth (COST_PER_MTOK)
    cache_read_rates = {s: COST_PER_MTOK[mid]["cache_read"] for s, mid in MODELS.items() if mid in COST_PER_MTOK}
    cache_create_rates = {s: COST_PER_MTOK[mid]["cache_write"] for s, mid in MODELS.items() if mid in COST_PER_MTOK}
    for m in all_metrics:
        cli_path = run_dir / "tasks" / m["task_id"] / f"{m['language_mode']}-{m['model_short']}" / "cli-output.json"
        if not cli_path.exists():
            continue
        try:
            evts = json.loads(cli_path.read_text())
        except Exception:
            continue
        for e in evts:
            if e.get("type") == "assistant":
                usage = e.get("message", {}).get("usage", {})
                cr = usage.get("cache_read_input_tokens", 0)
                cc = usage.get("cache_creation_input_tokens", 0)
                ms = m["model_short"]
                saved = cr * (cache_create_rates.get(ms, 0) - cache_read_rates.get(ms, 0)) / 1_000_000 if cr else 0
                status = "full_hit" if cr > 0 and cc == 0 else "partial" if cr > 0 else "miss"
                cache_data.append({"mode": m["language_mode"], "model": ms, "saved": saved, "status": status})
                break

    # ── Emit Savings Analysis section ──
    lines.append("## Savings Analysis")
    lines.append("")

    # ── Hook Savings by Language/Model ──
    lines.append("### Hook Savings by Language/Model")
    lines.append("")
    lines.append("Each hook-caught error avoids one test run that would otherwise have been needed to discover it.")
    lines.append("Every hook fire (hit or miss) costs execution time for the syntax/type checker.")
    lines.append("")
    hook_hdr = ("| Mode | Model | Fires | Caught | Rate "
                "| Gross Saved | % of Time | Overhead | % of Time | Net Saved | % of Time "
                "| Test Run Time | % of Test Time |")
    hook_sep = ("|------|-------|-------|--------|------"
                "|------------|-----------|----------|-----------|-----------|-----------|"
                "---------------|----------------|")
    hook_rows: list[dict] = []
    for mode in modes_seen:
        for model in models_seen:
            hs = hook_by_combo.get((mode, model), {})
            f_count = hs.get("fires", 0)
            c_count = hs.get("caught", 0)
            if f_count == 0:
                continue
            gross = hs["gross_saved"]
            overhead = hs["overhead"]
            net = gross - overhead
            test_t = hs.get("test_time", 0)
            hook_rows.append({
                "mode": mode, "model": model, "fires": f_count, "caught": c_count,
                "rate": c_count / f_count * 100,
                "gross": gross,
                "gross_pct": gross / total_duration * 100 if total_duration else 0,
                "overhead": overhead,
                "overhead_pct": overhead / total_duration * 100 if total_duration else 0,
                "net": net,
                "net_pct": net / total_duration * 100 if total_duration else 0,
                "test_time": test_t,
                "test_time_pct": net / test_t * 100 if test_t else 0,
            })
    def _fmt_hook(r):
        return (f"| {r['mode']} | {r['model']} | {r['fires']} | {r['caught']} | {r['rate']:.1f}% "
                f"| {r['gross']/60:.1f}min | {r['gross_pct']:.1f}% "
                f"| {r['overhead']/60:.1f}min | {r['overhead_pct']:.1f}% "
                f"| {r['net']/60:.1f}min | {r['net_pct']:.1f}% "
                f"| {r['test_time']/60:.1f}min | {r['test_time_pct']:.1f}% |")
    lines.append(hook_hdr)
    lines.append(hook_sep)
    for r in hook_rows:
        lines.append(_fmt_hook(r))
    total_hook_fires = sum(r["fires"] for r in hook_rows)
    total_hook_caught = sum(r["caught"] for r in hook_rows)
    total_gross = sum(r["gross"] for r in hook_rows)
    total_overhead = sum(r["overhead"] for r in hook_rows)
    total_net = total_gross - total_overhead
    total_test_time = sum(r["test_time"] for r in hook_rows)
    if total_hook_fires:
        lines.append(
            f"| **Total** | | **{total_hook_fires}** | **{total_hook_caught}** "
            f"| **{total_hook_caught/total_hook_fires*100:.1f}%** "
            f"| **{total_gross/60:.1f}min** | **{total_gross/total_duration*100:.1f}%** "
            f"| **{total_overhead/60:.1f}min** | **{total_overhead/total_duration*100:.1f}%** "
            f"| **{total_net/60:.1f}min** | **{total_net/total_duration*100:.1f}%** "
            f"| **{total_test_time/60:.1f}min** "
            f"| **{total_net/total_test_time*100:.1f}%** |" if total_test_time else
            f"| **—** | **—** |"
        )
    lines.append("")
    lines.extend(_emit_sorted_variants(hook_hdr, hook_sep, hook_rows, [
        ("Sorted by net saved (most first)", "net", True),
        ("Sorted by catch rate (highest first)", "rate", True),
        ("Sorted by overhead (most first)", "overhead", True),
        ("Sorted by test run time (most first)", "test_time", True),
    ], _fmt_hook))
    lines.append("")

    # ── Prompt Cache Savings ──
    if cache_data:
        cache_total_saved = sum(d["saved"] for d in cache_data)
        full_hits = sum(1 for d in cache_data if d["status"] == "full_hit")
        partials = sum(1 for d in cache_data if d["status"] == "partial")
        misses = sum(1 for d in cache_data if d["status"] == "miss")
        cache_pct = cache_total_saved / total_cost * 100 if total_cost else 0

        lines.append("### Prompt Cache Savings")
        lines.append("")
        lines.append("| Status | Runs | $ Saved | % of $ |")
        lines.append("|--------|------|---------|--------|")
        for label, st in [("Full hit (100%)", "full_hit"), ("Partial", "partial"), ("Miss", "miss")]:
            sv = sum(d["saved"] for d in cache_data if d["status"] == st)
            pct = sv / total_cost * 100 if total_cost else 0
            cnt = sum(1 for d in cache_data if d["status"] == st)
            lines.append(f"| {label} | {cnt} | ${sv:.4f} | {pct:.2f}% |")
        lines.append(f"| **Total** | **{len(cache_data)}** | **${cache_total_saved:.4f}** | **{cache_pct:.2f}%** |")
        lines.append("")

    # ── Trap Analysis by Category ──
    if trap_instances:
        trap_applicable_mode = {
            "pester-cmdletbinding-spiral": "powershell",
            "pester-wrong-assertions": "powershell",
            "docker-pwsh-install": "powershell",
            "mid-run-module-restructure": "powershell",
            "ts-type-error-fix-cycles": "typescript-bun",
            "bats-setup-issues": "bash",
        }
        from collections import defaultdict as _dd
        trap_agg: dict[str, list[dict]] = _dd(list)
        for t in trap_instances:
            trap_agg[t["name"]].append(t)

        lines.append("### Trap Analysis by Category")
        lines.append("")
        tcat_hdr = "| Trap | Applicable | Fell In | Avoided | Rate | Time Lost | % of Time | $ Lost | % of $ |"
        tcat_sep = "|------|-----------|---------|---------|------|-----------|-----------|--------|--------|"
        mode_run_totals = {md: sum(1 for m in all_metrics if m["language_mode"] == md) for md in modes_seen}
        tcat_rows: list[dict] = []
        for trap_name in sorted(trap_agg, key=lambda k: -sum(t["time_s"] for t in trap_agg[k])):
            insts = trap_agg[trap_name]
            tmode = trap_applicable_mode.get(trap_name, "all")
            n_app = mode_run_totals.get(tmode, completed) if tmode != "all" else completed
            n_fell = len(insts)
            t_time = sum(t["time_s"] for t in insts)
            t_cost = sum(t["time_s"] / t["dur_s"] * t["cost"] for t in insts if t["dur_s"] > 0 and t["cost"] > 0)
            rate = n_fell / n_app * 100 if n_app else 0
            tcat_rows.append({
                "trap": trap_name, "applicable": n_app, "fell_in": n_fell,
                "avoided": n_app - n_fell, "rate": rate,
                "time_lost": t_time, "time_pct": t_time / total_duration * 100 if total_duration else 0,
                "cost_lost": t_cost, "cost_pct": t_cost / total_cost * 100 if total_cost else 0,
            })
        def _fmt_tcat(r):
            return (f"| {r['trap']} | {r['applicable']} | {r['fell_in']} | {r['avoided']} | {r['rate']:.0f}% "
                    f"| {r['time_lost']/60:.1f}min | {r['time_pct']:.1f}% | ${r['cost_lost']:.2f} | {r['cost_pct']:.2f}% |")
        lines.append(tcat_hdr)
        lines.append(tcat_sep)
        for r in tcat_rows:
            lines.append(_fmt_tcat(r))
        total_trap_time = sum(t["time_s"] for t in trap_instances)
        total_trap_cost = sum(t["time_s"] / t["dur_s"] * t["cost"] for t in trap_instances if t["dur_s"] > 0 and t["cost"] > 0)
        total_trapped = len(set((t["task_id"], t["mode"], t["model"]) for t in trap_instances))
        tt_pct = total_trap_time / total_duration * 100 if total_duration else 0
        tc_pct = total_trap_cost / total_cost * 100 if total_cost else 0
        lines.append(
            f"| **Total** | | **{total_trapped} runs** | | "
            f"**{total_trapped/completed*100:.0f}%** "
            f"| **{total_trap_time/60:.1f}min** | **{tt_pct:.1f}%** "
            f"| **${total_trap_cost:.2f}** | **{tc_pct:.2f}%** |"
        )
        lines.append("")
        lines.extend(_emit_sorted_variants(tcat_hdr, tcat_sep, tcat_rows, [
            ("Sorted by $ lost (most first)", "cost_lost", True),
            ("Sorted by rate (highest first)", "rate", True),
            ("Sorted by runs affected (most first)", "fell_in", True),
        ], _fmt_tcat))
        lines.append("")

    # ── Trap Summary by Language/Model ──
    if trap_instances:
        lines.append("### Traps by Language/Model")
        lines.append("")
        tlm_hdr = "| Mode | Model | Runs | Trapped | Trap Rate | Traps | Time Lost | % of Time | $ Lost | % of $ |"
        tlm_sep = "|------|-------|------|---------|-----------|-------|-----------|-----------|--------|--------|"
        trapped_runs_by_combo: dict[tuple, set] = {}
        trap_count_by_combo: dict[tuple, int] = {}
        trap_time_by_combo: dict[tuple, float] = {}
        trap_cost_by_combo: dict[tuple, float] = {}
        for t in trap_instances:
            combo = (t["mode"], t["model"])
            trapped_runs_by_combo.setdefault(combo, set()).add(t["task_id"])
            trap_count_by_combo[combo] = trap_count_by_combo.get(combo, 0) + 1
            trap_time_by_combo[combo] = trap_time_by_combo.get(combo, 0) + t["time_s"]
            if t["dur_s"] > 0 and t["cost"] > 0:
                trap_cost_by_combo[combo] = trap_cost_by_combo.get(combo, 0) + t["time_s"] / t["dur_s"] * t["cost"]

        tlm_rows: list[dict] = []
        for mode in modes_seen:
            for model in models_seen:
                combo = (mode, model)
                n = combo_run_counts.get(combo, 0)
                if n == 0:
                    continue
                n_trapped = len(trapped_runs_by_combo.get(combo, set()))
                rate = n_trapped / n * 100 if n else 0
                tc = trap_count_by_combo.get(combo, 0)
                tt = trap_time_by_combo.get(combo, 0)
                tcc = trap_cost_by_combo.get(combo, 0)
                tlm_rows.append({
                    "mode": mode, "model": model, "n": n, "trapped": n_trapped,
                    "rate": rate, "traps": tc,
                    "time_lost": tt, "time_pct": tt / total_duration * 100 if total_duration else 0,
                    "cost_lost": tcc, "cost_pct": tcc / total_cost * 100 if total_cost else 0,
                })
        def _fmt_tlm(r):
            return (f"| {r['mode']} | {r['model']} | {r['n']} | {r['trapped']} | {r['rate']:.0f}% "
                    f"| {r['traps']} | {r['time_lost']/60:.1f}min | {r['time_pct']:.1f}% "
                    f"| ${r['cost_lost']:.2f} | {r['cost_pct']:.2f}% |")
        lines.append(tlm_hdr)
        lines.append(tlm_sep)
        for r in tlm_rows:
            lines.append(_fmt_tlm(r))
        lines.append(
            f"| **Total** | | **{completed}** | **{total_trapped}** "
            f"| **{total_trapped/completed*100:.0f}%** "
            f"| **{len(trap_instances)}** | **{total_trap_time/60:.1f}min** | **{tt_pct:.1f}%** "
            f"| **${total_trap_cost:.2f}** | **{tc_pct:.2f}%** |"
        )
        lines.append("")
        lines.extend(_emit_sorted_variants(tlm_hdr, tlm_sep, tlm_rows, [
            ("Sorted by time lost (most first)", "time_lost", True),
            ("Sorted by $ lost (most first)", "cost_lost", True),
            ("Sorted by trap rate (highest first)", "rate", True),
        ], _fmt_tlm))
        lines.append("")

    # ==================================================================
    # DETAIL TABLES
    # ==================================================================

    # ── Per-run detail table ──
    lines.append("## Per-Run Results")
    lines.append("")
    lines.append("| Task | Mode | Model | Duration | Turns | Lines | Errors | Cost | Language | Status |")
    lines.append("|------|------|-------|----------|-------|-------|--------|------|----------|--------|")
    for m in all_metrics:
        dur = m["timing"]["grand_total_duration_ms"] / 1000
        status = "ok" if m in successful else m.get("failure_reason", "failed")
        lines.append(
            f"| {m['task_name'][:30]} | {m['language_mode']} | {m['model_short']} "
            f"| {dur:.0f}s | {m['timing']['num_turns']} | {m['code_metrics']['total_lines']} "
            f"| {m['quality']['error_count']} | ${m['cost']['total_cost_usd']:.4f} "
            f"| {m['language_chosen']} | {status} |"
        )
    lines.append("")

    # ── Head-to-head: same task + model, different modes (with cost delta) ──
    task_model_pairs = sorted(set((m["task_id"], m["model_short"]) for m in successful))
    h2h_rows = []
    for task_id, model_short in task_model_pairs:
        group = [m for m in successful if m["task_id"] == task_id and m["model_short"] == model_short]
        task_modes = {m["language_mode"]: m for m in group}
        if "default" in task_modes and any(k != "default" for k in task_modes):
            default = task_modes["default"]
            for mode, m in task_modes.items():
                if mode == "default":
                    continue
                d_dur = default["timing"]["grand_total_duration_ms"] / 1000
                m_dur = m["timing"]["grand_total_duration_ms"] / 1000
                dur_delta = ((m_dur - d_dur) / d_dur * 100) if d_dur > 0 else 0
                d_cost = default["cost"]["total_cost_usd"]
                m_cost = m["cost"]["total_cost_usd"]
                cost_delta = ((m_cost - d_cost) / d_cost * 100) if d_cost > 0 else 0
                d_err = default["quality"]["error_count"]
                m_err = m["quality"]["error_count"]
                err_delta = m_err - d_err
                h2h_rows.append({
                    "task": default["task_name"][:25], "model": model_short, "mode": mode,
                    "default_lang": default["language_chosen"],
                    "def_dur": d_dur, "mode_dur": m_dur, "dur_delta": dur_delta,
                    "def_cost": d_cost, "mode_cost": m_cost, "cost_delta": cost_delta,
                    "def_err": d_err, "mode_err": m_err, "err_delta": err_delta,
                    "def_lines": default["code_metrics"]["total_lines"],
                    "mode_lines": m["code_metrics"]["total_lines"],
                })

    if h2h_rows:
        lines.append("## Head-to-Head: Default vs Constrained Language")
        lines.append("")
        lines.append("| Task | Model | Mode | Default Lang | Def Dur | Mode Dur | Dur Δ | Def Cost | Mode Cost | Cost Δ | Err Δ |")
        lines.append("|------|-------|------|-------------|---------|----------|-------|----------|-----------|--------|-------|")
        for r in h2h_rows:
            ds = "+" if r["dur_delta"] >= 0 else ""
            cs = "+" if r["cost_delta"] >= 0 else ""
            es = "+" if r["err_delta"] >= 0 else ""
            lines.append(
                f"| {r['task']} | {r['model']} | {r['mode']} | {r['default_lang']} "
                f"| {r['def_dur']:.0f}s | {r['mode_dur']:.0f}s | {ds}{r['dur_delta']:.0f}% "
                f"| ${r['def_cost']:.4f} | ${r['mode_cost']:.4f} | {cs}{r['cost_delta']:.0f}% "
                f"| {es}{r['err_delta']} |"
            )
        lines.append("")

    # ── Observations ──
    lines.append("## Observations")
    lines.append("")

    if len(successful) >= 2:
        most_err = max(successful, key=lambda m: m["quality"]["error_count"])
        least_err = min(successful, key=lambda m: m["quality"]["error_count"])
        slowest = max(successful, key=lambda m: m["timing"]["grand_total_duration_ms"])
        fastest = min(successful, key=lambda m: m["timing"]["grand_total_duration_ms"])

        lines.append(f"- **Fastest run:** {fastest['task_name']} / {fastest['language_mode']} / {fastest['model_short']} — {fastest['timing']['grand_total_duration_ms']/1000:.0f}s")
        lines.append(f"- **Slowest run:** {slowest['task_name']} / {slowest['language_mode']} / {slowest['model_short']} — {slowest['timing']['grand_total_duration_ms']/1000:.0f}s")
        lines.append(f"- **Most errors:** {most_err['task_name']} / {most_err['language_mode']} / {most_err['model_short']} — {most_err['quality']['error_count']} errors")
        lines.append(f"- **Fewest errors:** {least_err['task_name']} / {least_err['language_mode']} / {least_err['model_short']} — {least_err['quality']['error_count']} errors")
        lines.append("")

        for model in models_seen:
            mm = [m for m in successful if m["model_short"] == model]
            if mm:
                avg_cost = sum(m["cost"]["total_cost_usd"] for m in mm) / len(mm)
                lines.append(f"- **Avg cost per run ({model}):** ${avg_cost:.4f}")
        lines.append("")

    if completed < total_runs:
        if total_duration > 0 and completed > 0:
            est_remaining_s = (total_duration / completed) * (total_runs - run_count)
            est_remaining_h = est_remaining_s / 3600
            lines.append(f"- **Estimated time remaining:** {est_remaining_h:.1f} hours (based on avg {total_duration/completed:.0f}s per run)")
            est_total_cost = (total_cost / completed) * total_runs
            lines.append(f"- **Estimated total cost:** ${est_total_cost:.2f}")

    lines.append("")
    lines.append("---")
    lines.append(f"*Generated by runner.py, instructions version {INSTRUCTIONS_VERSION}*")

    (run_dir / "results.md").write_text("\n".join(lines))

# ---------------------------------------------------------------------------
# Stream Parsing
# ---------------------------------------------------------------------------

def parse_stream_output(timestamped_lines: list[tuple[int, str]]) -> dict:
    """Parse timestamped JSON stream lines from claude CLI and extract metrics.

    Each entry is (timestamp_ms, json_line) where timestamp_ms is wall-clock
    milliseconds since epoch, captured in real-time as lines arrived from the
    CLI subprocess.
    """
    events = []  # (timestamp_ms, parsed_obj)
    console_lines = []
    claude_code_version = ""
    model_used = ""
    result_data = {}
    init_data = {}
    compaction_count = 0
    error_count = 0
    error_details = []
    install_commands = []
    tools_installed = []
    interpreter_versions = {}
    hook_events = []  # Collected from --include-hook-events

    # Track pending tool_use events by ID for duration calculation
    pending_tool_uses: dict[str, tuple[int, str, str]] = {}  # id -> (timestamp_ms, tool_name, command)
    tool_use_durations: list[dict] = []  # completed tool uses with duration
    install_duration_ms = 0

    for ts_ms, line in timestamped_lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
            events.append((ts_ms, obj))
        except json.JSONDecodeError:
            continue

        event_type = obj.get("type", "")
        msg = obj.get("message", {}) if isinstance(obj.get("message"), dict) else {}
        content = msg.get("content", []) if isinstance(msg.get("content"), list) else []

        # Init event — capture all metadata about the session
        if event_type == "system" and obj.get("subtype") == "init":
            claude_code_version = obj.get("claude_code_version", "")
            model_used = obj.get("model", "")
            init_data = {
                "session_id": obj.get("session_id", ""),
                "model": model_used,
                "claude_code_version": claude_code_version,
                "permission_mode": obj.get("permissionMode", ""),
                "output_style": obj.get("output_style", ""),
                "fast_mode_state": obj.get("fast_mode_state", ""),
                "tools_available": obj.get("tools", []),
                "mcp_servers": obj.get("mcp_servers", []),
                "agents_available": obj.get("agents", []),
                "skills_available": obj.get("skills", []),
                "plugins": obj.get("plugins", []),
                "cwd": obj.get("cwd", ""),
            }

        # Assistant text
        if event_type == "assistant":
            for c in content:
                if isinstance(c, dict) and c.get("type") == "text":
                    text = c.get("text", "")
                    console_lines.append(f"[Assistant] {text}")

        # Tool use and results
        if event_type == "assistant":
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    tool_name = c.get("name", "")
                    tool_id = c.get("id", "")
                    tool_input = c.get("input", {})
                    is_install = False
                    cmd = ""
                    if tool_name == "Bash":
                        cmd = tool_input.get("command", "")
                        console_lines.append(f"[Tool: {tool_name}] {cmd}")
                        # Check for install commands
                        for pattern in INSTALL_PATTERNS:
                            if re.search(pattern, cmd, re.IGNORECASE):
                                install_commands.append(cmd)
                                tools_installed.append(cmd.strip())
                                is_install = True
                                break
                    else:
                        detail = json.dumps(tool_input)[:200] if tool_input else ""
                        console_lines.append(f"[Tool: {tool_name}] {detail}")
                    # Track this tool_use for duration measurement
                    if tool_id:
                        pending_tool_uses[tool_id] = (ts_ms, tool_name, cmd if tool_name == "Bash" else "", is_install)

        # Tool results
        if event_type == "user":
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    tool_use_id = c.get("tool_use_id", "")
                    result_content = c.get("content", "")
                    is_error = c.get("is_error", False)

                    # Compute duration if we have the matching tool_use
                    if tool_use_id and tool_use_id in pending_tool_uses:
                        start_ms, t_name, t_cmd, t_is_install = pending_tool_uses.pop(tool_use_id)
                        dur = ts_ms - start_ms
                        tool_use_durations.append({
                            "tool_name": t_name,
                            "command": t_cmd[:200],
                            "duration_ms": dur,
                            "is_error": is_error,
                            "is_install": t_is_install,
                        })
                        if t_is_install:
                            install_duration_ms += dur

                    if isinstance(result_content, str):
                        console_lines.append(f"[Result{' ERROR' if is_error else ''}] {result_content[:1000]}")
                        if is_error:
                            error_count += 1
                            error_details.append(result_content[:200])
                        # Look for version strings
                        for vline in result_content.splitlines():
                            if "PSVersion" in vline:
                                parts = vline.split()
                                if len(parts) >= 2:
                                    interpreter_versions["powershell"] = parts[-1]
                            if re.match(r"^\d+\.\d+\.\d+", vline.strip()) and "dotnet" not in interpreter_versions:
                                pass
                    elif isinstance(result_content, list):
                        for rc in result_content:
                            if isinstance(rc, dict):
                                text = rc.get("text", str(rc))[:500]
                                console_lines.append(f"[Result] {text}")

        # Compaction events
        if "compact" in event_type.lower() or "compact" in str(obj.get("subtype", "")).lower():
            compaction_count += 1

        # Hook events (from --include-hook-events)
        subtype = obj.get("subtype", "")
        if subtype in ("hook_started", "hook_response"):
            hook_entry = {
                "subtype": subtype,
                "hook_id": obj.get("hook_id", ""),
                "hook_name": obj.get("hook_name", ""),
                "hook_event": obj.get("hook_event", ""),
            }
            if subtype == "hook_response":
                hook_entry["exit_code"] = obj.get("exit_code")
                hook_entry["outcome"] = obj.get("outcome", "")
                hook_entry["stdout"] = (obj.get("stdout", "") or "")[:500]
                hook_entry["stderr"] = (obj.get("stderr", "") or "")[:500]
            hook_events.append(hook_entry)

        # Result event — keep the first one (background task notifications
        # can emit a second init+result pair that would overwrite the real data)
        if event_type == "result" and not result_data:
            result_data = obj

    # Extract timing and usage from result
    duration_ms = result_data.get("duration_ms", 0)
    duration_api_ms = result_data.get("duration_api_ms", 0)
    num_turns = result_data.get("num_turns", 0)
    total_cost = result_data.get("total_cost_usd", 0.0)
    usage = result_data.get("usage", {})
    input_tokens = usage.get("input_tokens", 0)
    output_tokens = usage.get("output_tokens", 0)
    cache_read = usage.get("cache_read_input_tokens", usage.get("cache_read_tokens", 0))
    cache_creation = usage.get("cache_creation_input_tokens", usage.get("cache_creation_tokens", 0))

    # Estimate install duration from the stream: count bash tool uses that match install patterns
    # This is approximate — we track the commands but duration per command isn't in the stream
    # We'll use a heuristic: count install commands and note them
    # A more precise approach would require correlating tool_use IDs with their results

    # Extract detailed metadata from result event
    model_usage = result_data.get("modelUsage", {})
    result_meta = {
        "session_id": result_data.get("session_id", ""),
        "stop_reason": result_data.get("stop_reason", ""),
        "terminal_reason": result_data.get("terminal_reason", ""),
        "fast_mode_state": result_data.get("fast_mode_state", ""),
        "service_tier": usage.get("service_tier", ""),
        "speed": usage.get("speed", ""),
        "inference_geo": usage.get("inference_geo", ""),
        "model_usage": model_usage,
        "permission_denials": result_data.get("permission_denials", []),
        "context_window": None,
        "max_output_tokens": None,
    }
    # Extract context_window and max_output_tokens from modelUsage
    for model_key, model_info in model_usage.items():
        result_meta["context_window"] = model_info.get("contextWindow")
        result_meta["max_output_tokens"] = model_info.get("maxOutputTokens")
        break  # just take the first (should be only one)

    return {
        "events": [obj for _, obj in events],
        "timestamped_events": events,  # (ts_ms, obj) for analysis
        "console_log": "\n".join(console_lines),
        "claude_code_version": claude_code_version,
        "model_used": model_used,
        "init_data": init_data,
        "result_meta": result_meta,
        "hook_events": hook_events,
        "duration_ms": duration_ms,
        "duration_api_ms": duration_api_ms,
        "num_turns": num_turns,
        "total_cost_usd": total_cost,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_read_tokens": cache_read,
        "cache_creation_tokens": cache_creation,
        "total_context_consumed": input_tokens + cache_read + cache_creation,
        "compaction_count": compaction_count,
        "error_count": error_count,
        "error_details": error_details,
        "install_commands": install_commands,
        "install_duration_ms": install_duration_ms,
        "tools_installed": tools_installed,
        "interpreter_versions": interpreter_versions,
        "tool_use_durations": tool_use_durations,
        "result_data": result_data,
    }

# ---------------------------------------------------------------------------
# Main Run Logic
# ---------------------------------------------------------------------------

def run_single_task(
    task: dict,
    mode: str,
    model_id: str,
    model_short: str,
    run_dir: Path,
    repo_root: Path,
    effort: str | None = None,
    timeout_minutes: int = 30,
) -> dict:
    """Run a single task/mode/model combination and return metrics."""
    task_id = task["id"]
    task_name = task["name"]
    prompt = PROMPT_TEMPLATES[mode].format(task_description=task["description"])

    # Append GHA workflow requirement for tasks 11-18
    if task_id in GHA_TASK_IDS:
        task_slug = task_id.split("-", 1)[1] if "-" in task_id else task_id
        prompt += "\n" + GHA_WORKFLOW_ADDENDUM.format(task_slug=task_slug)

    # Create workspace
    workspace = repo_root / "workspaces" / run_dir.name / task_id / f"{mode}-{model_short}"
    workspace.mkdir(parents=True, exist_ok=True)

    # Initialize workspace as a git repo (act requires one)
    if not (workspace / ".git").exists():
        subprocess.run(["git", "init", "-q"], cwd=str(workspace), capture_output=True, timeout=10)
        subprocess.run(["git", "config", "user.email", "benchmark@test"], cwd=str(workspace), capture_output=True, timeout=5)
        subprocess.run(["git", "config", "user.name", "benchmark"], cwd=str(workspace), capture_output=True, timeout=5)

    # Copy instructions file
    shutil.copy2(repo_root / INSTRUCTIONS_FILE, workspace / INSTRUCTIONS_FILE)

    # Set up workspace hooks — syntax/lint checking on Write/Edit
    hook_script = (repo_root / "hooks" / "syntax-check.py").resolve()
    if hook_script.exists():
        claude_dir = workspace / ".claude"
        claude_dir.mkdir(parents=True, exist_ok=True)
        hook_config = {
            "hooks": {
                "PostToolUse": [
                    {
                        "matcher": "Write|Edit",
                        "hooks": [
                            {
                                "type": "command",
                                "command": f"python3 {hook_script}",
                                "timeout": 15,
                            }
                        ],
                    }
                ]
            }
        }
        (claude_dir / "settings.json").write_text(json.dumps(hook_config, indent=2))

    # Create results directory
    result_dir = run_dir / "tasks" / task_id / f"{mode}-{model_short}"
    result_dir.mkdir(parents=True, exist_ok=True)

    # Capture workspace before
    workspace_before = capture_workspace_listing(workspace)
    (result_dir / "workspace-before.txt").write_text(workspace_before)

    log(f"  Starting: {task_id} | {mode} | {model_short}")
    log(f"  Workspace: {workspace}")

    # Build command
    cmd = [
        "claude",
        "-p", prompt,
        "--model", model_id,
        "--output-format", "stream-json",
        "--dangerously-skip-permissions",
        "--include-hook-events",
        "--verbose",
        "--mcp-config", '{"mcpServers":{}}',
        "--strict-mcp-config",
    ]
    if effort:
        cmd.extend(["--effort", effort])

    # Record timing
    timestamp_start = datetime.now(timezone.utc).isoformat()
    wall_start = time.time()

    # Ensure tools are on PATH for the agent subprocess
    env = os.environ.copy()
    local_bin = Path.home() / ".local" / "bin"
    if local_bin.exists():
        env["PATH"] = f"{local_bin}:{env.get('PATH', '')}"
    dotnet_root = Path.home() / ".dotnet"
    if dotnet_root.exists():
        env["DOTNET_ROOT"] = str(dotnet_root)
        env["PATH"] = f"{dotnet_root}:{env.get('PATH', '')}"

    # Execute with real-time line timestamping
    timestamped_lines: list[tuple[int, str]] = []  # (epoch_ms, line)
    raw_stderr = ""
    exit_code = -1
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=str(workspace),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
        )
        # Read stdout line-by-line, stamping each with current time
        deadline = wall_start + timeout_minutes * 60 if timeout_minutes > 0 else float('inf')
        for line in proc.stdout:
            ts_ms = int(time.time() * 1000)
            timestamped_lines.append((ts_ms, line.rstrip("\n")))
            if time.time() > deadline:
                proc.kill()
                raw_stderr = f"TIMEOUT: Process exceeded {timeout_minutes} minute limit"
                log(f"  TIMEOUT: {task_id} | {mode} | {model_short}")
                break
        proc.wait(timeout=30)
        exit_code = proc.returncode
        raw_stderr = proc.stderr.read() if proc.stderr else ""
    except Exception as e:
        raw_stderr = f"ERROR: {str(e)}"
        exit_code = -2
        log(f"  ERROR: {task_id} | {mode} | {model_short}: {e}")
        try:
            proc.kill()
        except Exception:
            pass

    wall_end = time.time()
    timestamp_end = datetime.now(timezone.utc).isoformat()
    grand_total_duration_ms = int((wall_end - wall_start) * 1000)

    # Parse stream output (now with per-line timestamps)
    parsed = parse_stream_output(timestamped_lines)

    # Capture workspace after
    workspace_after = capture_workspace_listing(workspace)
    (result_dir / "workspace-after.txt").write_text(workspace_after)

    # Copy generated files
    gen_dir = result_dir / "generated-code"
    generated_files = copy_generated_files(workspace, gen_dir)

    # Post-run actionlint validation on any workflow files
    actionlint_results = []
    workflow_dir = workspace / ".github" / "workflows"
    if workflow_dir.exists():
        for wf in sorted(workflow_dir.glob("*.yml")) + sorted(workflow_dir.glob("*.yaml")):
            try:
                r = subprocess.run(
                    ["actionlint", str(wf)],
                    capture_output=True, text=True, timeout=15,
                )
                actionlint_results.append({
                    "file": str(wf.relative_to(workspace)),
                    "passed": r.returncode == 0,
                    "errors": (r.stdout.strip() or r.stderr.strip()) if r.returncode != 0 else "",
                })
            except FileNotFoundError:
                actionlint_results.append({
                    "file": str(wf.relative_to(workspace)),
                    "passed": None,
                    "errors": "actionlint not found",
                })
            except Exception as e:
                actionlint_results.append({
                    "file": str(wf.relative_to(workspace)),
                    "passed": None,
                    "errors": str(e),
                })

    actionlint_pass = all(r["passed"] for r in actionlint_results) if actionlint_results else None
    actionlint_error_count = sum(1 for r in actionlint_results if r["passed"] is False)

    # Check for agent-produced act-result.txt (proof the agent ran act in its tests)
    act_result_path = workspace / "act-result.txt"
    act_result_txt_exists = act_result_path.exists()
    act_result_txt_size = act_result_path.stat().st_size if act_result_txt_exists else 0

    # Code metrics
    total_lines = count_lines(gen_dir) if gen_dir.exists() else 0
    all_code = get_all_code_text(gen_dir) if gen_dir.exists() else ""
    total_tokens_est = estimate_tokens(all_code)
    language_breakdown = compute_language_breakdown(gen_dir) if gen_dir.exists() else {}

    # Determine language chosen (primary language by %)
    language_chosen = ""
    if language_breakdown:
        language_chosen = max(language_breakdown, key=language_breakdown.get)
    elif mode in ("powershell",):
        language_chosen = "powershell"
    elif mode == "bash":
        language_chosen = "bash"
    elif mode == "typescript-bun":
        language_chosen = "typescript"

    # Get runtime versions
    powershell_version = parsed["interpreter_versions"].get("powershell", "")
    dotnet_version = parsed["interpreter_versions"].get("dotnet", "")

    # Use parsed duration if available, fall back to wall clock
    duration_ms = parsed["duration_ms"] or grand_total_duration_ms
    api_duration_ms = parsed["duration_api_ms"] or 0
    exec_duration_ms = duration_ms - api_duration_ms if api_duration_ms else 0

    # Build metrics
    cost_rates = COST_PER_MTOK.get(model_id, {})
    metrics = {
        "task_id": task_id,
        "task_name": task_name,
        "task_category": task["category"],
        "language_mode": mode,
        "language_chosen": language_chosen,
        "language_breakdown": language_breakdown,
        "interpreter_versions": parsed["interpreter_versions"],
        "powershell_version": powershell_version,
        "dotnet_version": dotnet_version,
        "model": model_id,
        "model_short": model_short,
        "claude_code_version": parsed["claude_code_version"],
        "instructions_version": INSTRUCTIONS_VERSION,
        "timestamp_start": timestamp_start,
        "timestamp_end": timestamp_end,
        "prompt_text": prompt,
        "exit_code": exit_code,
        "run_success": exit_code == 0 and parsed["num_turns"] > 0,
        "failure_reason": (
            "timeout" if exit_code == -9 else
            "killed" if exit_code < 0 else
            "cli_error" if exit_code != 0 else
            "no_result" if parsed["num_turns"] == 0 else
            None
        ),
        # Session & environment metadata — everything the CLI exposes
        "session": {
            "session_id": parsed.get("result_meta", {}).get("session_id", ""),
            "stop_reason": parsed.get("result_meta", {}).get("stop_reason", ""),
            "terminal_reason": parsed.get("result_meta", {}).get("terminal_reason", ""),
            "fast_mode_state": parsed.get("result_meta", {}).get("fast_mode_state", ""),
            "service_tier": parsed.get("result_meta", {}).get("service_tier", ""),
            "speed": parsed.get("result_meta", {}).get("speed", ""),
            "inference_geo": parsed.get("result_meta", {}).get("inference_geo", ""),
            "context_window": parsed.get("result_meta", {}).get("context_window"),
            "max_output_tokens": parsed.get("result_meta", {}).get("max_output_tokens"),
            "permission_mode": parsed.get("init_data", {}).get("permission_mode", ""),
            "output_style": parsed.get("init_data", {}).get("output_style", ""),
            "tools_available_count": len(parsed.get("init_data", {}).get("tools_available", [])),
            "mcp_servers": parsed.get("init_data", {}).get("mcp_servers", []),
            "permission_denials": parsed.get("result_meta", {}).get("permission_denials", []),
        },
        "model_usage_detail": parsed.get("result_meta", {}).get("model_usage", {}),
        "effort_level": effort,
        "timing": {
            "grand_total_duration_ms": grand_total_duration_ms,
            "total_api_duration_ms": api_duration_ms,
            "total_execution_duration_ms": exec_duration_ms,
            "num_turns": parsed["num_turns"],
        },
        "tokens": {
            "input_tokens": parsed["input_tokens"],
            "output_tokens": parsed["output_tokens"],
            "cache_read_tokens": parsed["cache_read_tokens"],
            "cache_creation_tokens": parsed["cache_creation_tokens"],
            "total_context_consumed": parsed["total_context_consumed"],
            "compaction_count": parsed["compaction_count"],
        },
        "cost": {
            "total_cost_usd": parsed["total_cost_usd"],
            "assumed_input_cost_per_mtok": cost_rates.get("input", 0),
            "assumed_output_cost_per_mtok": cost_rates.get("output", 0),
            "assumed_cache_read_cost_per_mtok": cost_rates.get("cache_read", 0),
            "assumed_cache_write_cost_per_mtok": cost_rates.get("cache_write", 0),
        },
        "code_metrics": {
            "total_lines": total_lines,
            "total_tokens_estimate": total_tokens_est,
            "file_count": len(generated_files),
            "files": generated_files,
        },
        "quality": {
            "tests_pass": None,  # Would need to actually run tests to determine
            "error_count": parsed["error_count"],
            "error_details": parsed["error_details"][:20],  # Cap at 20
            "actionlint_pass": actionlint_pass,
            "actionlint_errors": actionlint_error_count,
            "actionlint_results": actionlint_results,
            "act_result_txt_exists": act_result_txt_exists,
            "act_result_txt_size": act_result_txt_size,
            "areas_of_difficulty": [],
            "observations": "",
        },
        "tool_install": {
            "tool_install_duration_ms": parsed["install_duration_ms"],
            "tools_installed": parsed["tools_installed"][:20],
            "install_commands_count": len(parsed["install_commands"]),
        },
        "tool_use_timing": {
            "total_tool_uses": len(parsed["tool_use_durations"]),
            "total_tool_duration_ms": sum(d["duration_ms"] for d in parsed["tool_use_durations"]),
            "bash_tool_uses": len([d for d in parsed["tool_use_durations"] if d["tool_name"] == "Bash"]),
            "bash_total_ms": sum(d["duration_ms"] for d in parsed["tool_use_durations"] if d["tool_name"] == "Bash"),
            "slowest_tool_uses": sorted(parsed["tool_use_durations"], key=lambda d: -d["duration_ms"])[:10],
            "all_tool_uses": parsed["tool_use_durations"],  # full list for post-analysis
            **_categorize_tool_time(parsed["tool_use_durations"]),
        },
        "hooks": {
            "hook_fires": len([h for h in parsed.get("hook_events", []) if h["subtype"] == "hook_response"]),
            "hook_errors_caught": len([
                h for h in parsed.get("hook_events", [])
                if h["subtype"] == "hook_response" and h.get("stdout", "").strip()
            ]),
            "hook_failures": len([
                h for h in parsed.get("hook_events", [])
                if h["subtype"] == "hook_response" and h.get("exit_code", 0) != 0
            ]),
            "hook_events": parsed.get("hook_events", []),
        },
    }

    # Save outputs
    (result_dir / "cli-output.json").write_text(json.dumps(parsed["events"], indent=2, default=str))
    (result_dir / "console-log.txt").write_text(parsed["console_log"])
    (result_dir / "metrics.json").write_text(json.dumps(metrics, indent=2, default=str))

    if raw_stderr:
        (result_dir / "stderr.txt").write_text(raw_stderr)

    log(f"  Finished: {task_id} | {mode} | {model_short} | {grand_total_duration_ms/1000:.1f}s | ${parsed['total_cost_usd']:.4f}")
    return metrics

# ---------------------------------------------------------------------------
# CLI & Main
# ---------------------------------------------------------------------------

def print_summary_table(all_metrics: list[dict]) -> None:
    """Print a summary table of all runs."""
    print("\n" + "=" * 130)
    print("BENCHMARK RESULTS SUMMARY")
    print("=" * 130)
    print(f"{'Task':<35} {'Mode':<18} {'Model':<8} {'Duration':>10} {'Turns':>6} {'Lines':>6} {'Errors':>7} {'Cost':>10} {'Lang':<12} {'Status':<8}")
    print("-" * 130)

    total_cost = 0
    total_duration = 0
    failed_count = 0

    for m in all_metrics:
        duration_s = m["timing"]["grand_total_duration_ms"] / 1000
        total_cost += m["cost"]["total_cost_usd"]
        total_duration += duration_s
        is_ok = m.get("run_success", m["exit_code"] == 0 and m["timing"]["num_turns"] > 0)
        status = "ok" if is_ok else m.get("failure_reason", "failed")
        if not is_ok:
            failed_count += 1

        print(
            f"{m['task_name'][:34]:<35} "
            f"{m['language_mode']:<18} "
            f"{m['model_short']:<8} "
            f"{duration_s:>9.1f}s "
            f"{m['timing']['num_turns']:>6} "
            f"{m['code_metrics']['total_lines']:>6} "
            f"{m['quality']['error_count']:>7} "
            f"${m['cost']['total_cost_usd']:>9.4f} "
            f"{m['language_chosen'][:11]:<12}"
            f"{status:<8}"
        )

    print("-" * 130)
    print(f"{'TOTALS':<63} {total_duration:>9.1f}s {'':>6} {'':>6} {'':>7} ${total_cost:>9.4f}")
    if failed_count:
        print(f"  ({failed_count} run(s) failed/timed-out — excluded from averages)")
    print("=" * 130)


def probe_model_metadata(model_id: str) -> dict:
    """Probe the Claude CLI to capture full model/environment metadata before the benchmark run.

    Runs a minimal `claude -p "say ok"` call and extracts every available field
    from the init and result events.  This lets us log the exact resolved model,
    service tier, context window, CLI version, etc. once at the start.
    """
    try:
        result = subprocess.run(
            ["claude", "-p", "say ok", "--model", model_id,
             "--output-format", "stream-json", "--dangerously-skip-permissions"],
            capture_output=True, text=True, timeout=60,
        )
        init_event = {}
        result_event = {}
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") == "system" and obj.get("subtype") == "init":
                init_event = obj
            elif obj.get("type") == "result":
                result_event = obj
        model_usage = result_event.get("modelUsage", {})
        model_info = model_usage.get(model_id, {})
        return {
            "model_id_requested": model_id,
            "model_id_init": init_event.get("model", ""),
            "claude_code_version": init_event.get("claude_code_version", ""),
            "service_tier": result_event.get("usage", {}).get("service_tier", ""),
            "speed": result_event.get("usage", {}).get("speed", ""),
            "inference_geo": result_event.get("usage", {}).get("inference_geo", ""),
            "context_window": model_info.get("contextWindow"),
            "max_output_tokens": model_info.get("maxOutputTokens"),
            "fast_mode_state": result_event.get("fast_mode_state", ""),
            "permission_mode": init_event.get("permissionMode", ""),
            "tools_count": len(init_event.get("tools", [])),
            "mcp_servers": init_event.get("mcp_servers", []),
            "agents": init_event.get("agents", []),
            "plugins": init_event.get("plugins", []),
        }
    except Exception as e:
        log(f"  Warning: model probe for {model_id} failed: {e}")
        return {"model_id_requested": model_id, "error": str(e)}


def get_system_info() -> dict:
    """Capture system environment info for reproducibility."""
    info = {
        "platform": sys.platform,
        "python_version": sys.version,
        "hostname": "",
        "uname": "",
    }
    try:
        import platform as plat
        info["hostname"] = plat.node()
        info["uname"] = str(plat.uname())
    except Exception:
        pass
    # Tool versions
    for tool, cmd in [
        ("claude", ["claude", "--version"]),
        ("python", ["python3", "--version"]),
        ("node", ["node", "--version"]),
        ("bun", ["bun", "--version"]),
        ("pwsh", ["pwsh", "--version"]),
        ("dotnet", ["dotnet", "--version"]),
        ("actionlint", ["actionlint", "--version"]),
        ("shellcheck", ["shellcheck", "--version"]),
        ("bash", ["bash", "--version"]),
        ("act", ["act", "--version"]),
        ("docker", ["docker", "--version"]),
    ]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            info[f"{tool}_version"] = r.stdout.strip().split("\n")[0]
        except Exception:
            info[f"{tool}_version"] = "not found"
    return info


def main():
    parser = argparse.ArgumentParser(description="Benchmark Claude Code agents on scripting tasks")
    parser.add_argument(
        "--tasks", default="all",
        help="Comma-separated task numbers (1-18) or 'all' (default: all)"
    )
    parser.add_argument(
        "--models", default="opus,sonnet",
        help="Comma-separated model short names: opus,sonnet (default: opus,sonnet)"
    )
    parser.add_argument(
        "--modes", default="default,powershell,bash,typescript-bun",
        help="Comma-separated language modes (default: default,powershell,bash,typescript-bun)"
    )
    parser.add_argument(
        "--resume", default=None,
        help="Resume a previous run by providing its timestamp directory name (e.g., 2026-04-02_181500). Skips runs that already have metrics.json."
    )
    parser.add_argument(
        "--effort", default=None, choices=["low", "medium", "high", "max"],
        help="Reasoning effort level passed to claude CLI (default: not set, uses CLI default)"
    )
    parser.add_argument(
        "--timeout", default=30, type=int,
        help="Per-run timeout in minutes (default: 30). Use 0 for unlimited."
    )
    args = parser.parse_args()

    # Parse tasks
    if args.tasks == "all":
        selected_tasks = TASKS
    else:
        task_nums = [int(t.strip()) for t in args.tasks.split(",")]
        selected_tasks = [TASKS[n - 1] for n in task_nums if 1 <= n <= len(TASKS)]

    # Parse models
    selected_models = [(short, MODELS[short]) for short in args.models.split(",") if short in MODELS]

    # Parse modes
    selected_modes = [m.strip() for m in args.modes.split(",") if m.strip() in PROMPT_TEMPLATES]

    if not selected_tasks or not selected_models or not selected_modes:
        print("Error: No valid tasks, models, or modes selected.", file=sys.stderr)
        sys.exit(1)

    # Create or resume run directory
    repo_root = Path(__file__).parent.resolve()
    if args.resume:
        run_timestamp = args.resume
        run_dir = repo_root / "results" / run_timestamp
        if not run_dir.exists():
            print(f"Error: Resume directory {run_dir} does not exist.", file=sys.stderr)
            sys.exit(1)
        log(f"Resuming run from {run_dir}")
    else:
        run_timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
        run_dir = repo_root / "results" / run_timestamp
    run_dir.mkdir(parents=True, exist_ok=True)

    total_runs = len(selected_tasks) * len(selected_models) * len(selected_modes)

    log(f"Benchmark starting: {len(selected_tasks)} tasks x {len(selected_models)} models x {len(selected_modes)} modes = {total_runs} runs")
    log(f"Tasks: {[t['id'] for t in selected_tasks]}")
    log(f"Models: {[m[0] for m in selected_models]}")
    log(f"Modes: {selected_modes}")
    log(f"Results: {run_dir}")
    log("")

    # Pre-flight: capture system info and probe each model
    log("Pre-flight: capturing system info...")
    system_info = get_system_info()
    log(f"  Claude CLI: {system_info.get('claude_version', 'unknown')}")
    log(f"  Python: {system_info.get('python_version', 'unknown')}")

    model_probes = {}
    for model_short, model_id in selected_models:
        log(f"Pre-flight: probing model {model_short} ({model_id})...")
        probe = probe_model_metadata(model_id)
        model_probes[model_short] = probe
        log(f"  Service tier: {probe.get('service_tier', '?')}, "
            f"Speed: {probe.get('speed', '?')}, "
            f"Context window: {probe.get('context_window', '?')}, "
            f"Max output: {probe.get('max_output_tokens', '?')}")

    # Run manifest
    manifest = {
        "run_id": run_timestamp,
        "instructions_version": INSTRUCTIONS_VERSION,
        "models_tested": [m[1] for m in selected_models],
        "modes_tested": selected_modes,
        "tasks_tested": [t["id"] for t in selected_tasks],
        "total_runs": total_runs,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": None,
        "cost_assumptions": COST_PER_MTOK,
        "total_cost_usd": 0,
        "system_info": system_info,
        "model_probes": model_probes,
        "effort_level": args.effort,
    }

    all_metrics = []
    run_count = 0

    # When resuming, load ALL existing metrics (not just ones matching current filters)
    # so that results.md reflects the full picture
    total_runs_for_report = total_runs
    if args.resume:
        for mf in sorted((run_dir / "tasks").rglob("metrics.json")):
            try:
                all_metrics.append(json.loads(mf.read_text()))
            except Exception:
                pass
        if all_metrics:
            log(f"Loaded {len(all_metrics)} previously completed run(s) from {run_dir}")
        # Derive total from the run manifest if available, otherwise from loaded metrics
        manifest_path = run_dir / "run-manifest.json"
        if manifest_path.exists():
            try:
                manifest = json.loads(manifest_path.read_text())
                total_runs_for_report = manifest.get("total_runs", total_runs)
            except Exception:
                pass
        if total_runs_for_report == total_runs:
            # Fallback: count distinct (task, mode, model) combos in loaded metrics
            combos = set((m["task_id"], m["language_mode"], m["model_short"]) for m in all_metrics)
            total_runs_for_report = max(len(combos), total_runs)

    # Detect git branch for periodic pushing
    try:
        branch_result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=str(repo_root), capture_output=True, text=True, timeout=5,
        )
        git_branch = branch_result.stdout.strip() or "main"
    except Exception:
        git_branch = "main"

    # Start periodic pusher — seed with already-loaded metrics
    pusher = PeriodicPusher(repo_root, git_branch, total_runs_for_report, run_dir)
    pusher.update(len(all_metrics), all_metrics)
    pusher.start()
    log(f"Periodic git push enabled every {PUSH_INTERVAL}s to branch {git_branch}")

    for task in selected_tasks:
        for model_short, model_id in selected_models:
            for mode in selected_modes:
                run_count += 1
                # Check if already completed (for --resume)
                existing_metrics = run_dir / "tasks" / task["id"] / f"{mode}-{model_short}" / "metrics.json"
                if existing_metrics.exists():
                    log(f"Run {run_count}/{total_runs} — SKIPPED (already completed): {task['id']} | {mode} | {model_short}")
                    pusher.update(run_count, all_metrics)
                    continue
                log(f"Run {run_count}/{total_runs}")
                try:
                    metrics = run_single_task(
                        task=task,
                        mode=mode,
                        model_id=model_id,
                        model_short=model_short,
                        run_dir=run_dir,
                        repo_root=repo_root,
                        effort=args.effort,
                        timeout_minutes=args.timeout,
                    )
                    all_metrics.append(metrics)
                except Exception as e:
                    log(f"  FATAL ERROR in {task['id']} | {mode} | {model_short}: {e}")
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                pusher.update(run_count, all_metrics)
                log("")

    # Finalize manifest
    manifest["completed_at"] = datetime.now(timezone.utc).isoformat()
    manifest["total_cost_usd"] = sum(m["cost"]["total_cost_usd"] for m in all_metrics)
    (run_dir / "run-manifest.json").write_text(json.dumps(manifest, indent=2, default=str))

    # Summary
    summary = {
        "run_id": run_timestamp,
        "total_runs": len(all_metrics),
        "total_cost_usd": manifest["total_cost_usd"],
        "total_duration_s": sum(m["timing"]["grand_total_duration_ms"] for m in all_metrics) / 1000,
        "by_mode": {},
        "by_model": {},
        "tasks": [{
            "task_id": m["task_id"],
            "mode": m["language_mode"],
            "model": m["model_short"],
            "duration_s": m["timing"]["grand_total_duration_ms"] / 1000,
            "cost_usd": m["cost"]["total_cost_usd"],
            "lines": m["code_metrics"]["total_lines"],
            "errors": m["quality"]["error_count"],
            "language": m["language_chosen"],
            "turns": m["timing"]["num_turns"],
        } for m in all_metrics],
    }

    # Aggregate by mode
    for mode in selected_modes:
        mode_metrics = [m for m in all_metrics if m["language_mode"] == mode]
        if mode_metrics:
            summary["by_mode"][mode] = {
                "avg_duration_s": sum(m["timing"]["grand_total_duration_ms"] for m in mode_metrics) / len(mode_metrics) / 1000,
                "avg_lines": sum(m["code_metrics"]["total_lines"] for m in mode_metrics) / len(mode_metrics),
                "avg_errors": sum(m["quality"]["error_count"] for m in mode_metrics) / len(mode_metrics),
                "total_cost_usd": sum(m["cost"]["total_cost_usd"] for m in mode_metrics),
            }

    # Aggregate by model
    for model_short, _ in selected_models:
        model_metrics = [m for m in all_metrics if m["model_short"] == model_short]
        if model_metrics:
            summary["by_model"][model_short] = {
                "avg_duration_s": sum(m["timing"]["grand_total_duration_ms"] for m in model_metrics) / len(model_metrics) / 1000,
                "avg_lines": sum(m["code_metrics"]["total_lines"] for m in model_metrics) / len(model_metrics),
                "avg_errors": sum(m["quality"]["error_count"] for m in model_metrics) / len(model_metrics),
                "total_cost_usd": sum(m["cost"]["total_cost_usd"] for m in model_metrics),
            }

    (run_dir / "summary.json").write_text(json.dumps(summary, indent=2, default=str))

    # Print summary
    print_summary_table(all_metrics)

    # Final results.md and push — squashes any remaining incremental commits
    pusher.stop()
    generate_results_md(run_dir, all_metrics, total_runs_for_report, run_count)
    git_push_results(repo_root, git_branch, run_count, total_runs_for_report, final=True)
    log(f"Final results pushed to {git_branch}")

    log(f"\nResults saved to: {run_dir}")
    log(f"Total cost: ${manifest['total_cost_usd']:.4f}")


if __name__ == "__main__":
    main()
